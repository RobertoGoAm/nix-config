// Agents in grouped or priority views; parents take their most urgent sub-agent's place.

import { View, div, image, svg } from "gpui-kit";
import { v_flex, h_flex, InputState, Input } from "gpui-base";
import { agents, terminals, panes, focused, spaces, run, theme, shared, setShared, setAgentOrder, openOverlay, closeOverlay, props, window, layout, exec, hc, checking, nextCommand, setBadge } from "herdr";

const SELF = "agents-plus";
const APP = "/opt/homebrew/bin/herdr-app";
const FILTERS = [
  { id: "all", label: "All" },
  { id: "active", label: "Active" },
  { id: "attention", label: "Needs you" },
  { id: "review", label: "Review" },
];
const RECENT_MS = 60 * 60000;
const BRANCH_MS = 5 * 60000;
const BRANCH_PR = `cd "$1" 2>/dev/null || exit 3
b=$(git branch --show-current 2>/dev/null); [ -n "$b" ] || exit 3
case "$b" in main|master) exit 3 ;; esac
u=$(git remote get-url origin 2>/dev/null) || exit 3
case "$u" in
  *github.com*) gh pr view --json url --jq .url 2>/dev/null ;;
  *) glab mr view -F json 2>/dev/null | jq -r '.web_url // empty' ;;
esac`;
const CI_POLL_MS = 60000;
const filterOf = () => FILTERS.find((f) => f.id === shared("agents-plus.filter")) ?? FILTERS[1];

function fuzzy(token, text) {
  if (text.includes(token)) return true;
  let i = 0;
  for (const ch of text) if (ch === token[i] && ++i === token.length) return true;
  return false;
}

function ghCi(checks) {
  if (!checks?.length) return "none";
  const word = (c) => (c.conclusion || c.state || c.status || "").toUpperCase();
  if (checks.some((c) => ["FAILURE", "ERROR", "CANCELLED", "TIMED_OUT", "ACTION_REQUIRED", "STARTUP_FAILURE"].includes(word(c)))) return "fail";
  if (checks.some((c) => (c.status && c.status.toUpperCase() !== "COMPLETED") || ["PENDING", "EXPECTED", "QUEUED", "IN_PROGRESS"].includes(word(c)))) return "running";
  return "pass";
}

function glabCi(status) {
  if (!status) return "none";
  if (["failed", "canceled"].includes(status)) return "fail";
  if (status === "success") return "pass";
  if (status === "skipped" || status === "manual") return "none";
  return "running";
}

function ciQuery(url) {
  if (/\/pull\/\d+/.test(url)) return { cmd: "gh", args: ["pr", "view", url, "--json", "state,statusCheckRollup,reviewDecision"], parse: (j) => ({ state: (j.state ?? "").toLowerCase(), ci: ghCi(j.statusCheckRollup), approved: j.reviewDecision === "APPROVED" }) };
  const m = url.match(/^(https?:\/\/.+?)\/-\/merge_requests\/(\d+)/);
  if (m) return { cmd: "glab", args: ["mr", "view", m[2], "-R", m[1], "-F", "json"], parse: (j) => ({ state: j.state === "opened" ? "open" : (j.state ?? ""), ci: glabCi(j.head_pipeline?.status ?? j.pipeline?.status), approved: j.approved === true || j.detailed_merge_status === "mergeable" && j.approvals_left === 0 }) };
  return null;
}

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

// The sidebar's rail goes by its width, not a flag: dragging its edge narrows it too.
const narrow = () => (find(layout(), "sidebar")?.size?.px ?? Infinity) < 160;

// To the rail (on macOS wide enough for the traffic lights), or back to the width it had.
function toggleSidebar() {
  const width = find(layout(), "sidebar")?.size?.px;
  if (!narrow()) setShared("sidebar.width", width);
  // Mods edited before the rail went by width still read the flag.
  setShared("sidebar.collapsed", !narrow());
  run("layout.resize", { id: "sidebar", px: narrow() ? (shared("sidebar.width") ?? 268) : window()?.platform === "macos" ? 76 : 44 });
}

// Drops what an agent puts before its title: a status glyph or spinner and the separator
// after it ("✦  Working", "⠋ - Thinking"), and Codex's blinking "[ ! ] " / "[ . ] " mark.
// Stops at an opening bracket or quote, so a title that starts with one ("[web] login") keeps it.
const clean = (s) => (s ?? "").replace(/^[^\p{L}\p{N}\p{Ps}\p{Pi}]+/u, "").replace(/^\[ [!.] \] /, "").trim();

function leadPanes(all) {
  const leads = new Map();
  for (const p of all) {
    if (!p.terminal) continue;
    const current = leads.get(p.tab);
    // First agent, else first focused terminal, else first terminal in the tab.
    if (!current || (!current.program?.agent && (p.program?.agent || (!current.focused && p.focused)))) leads.set(p.tab, p);
  }
  return leads;
}

function title(tab, l) {
  const prog = l?.program?.name;
  const live = clean(l?.title);
  // clean() would strip a path's leading ~ or /: test the title with only its status glyph gone.
  const path = /^[~/]|^[A-Za-z]:\\/.test((l?.title ?? "").replace(/^[^\p{L}\p{N}~/]+/u, ""));
  const telling = live && live !== (l?.terminal ?? l?.address) && live !== prog && !path && !live.includes("@") && live.toLowerCase() !== l?.program?.key;
  return (tab.name === prog || !tab.named) && telling ? live : tab.name;
}
const RANK = { blocked: 4, done: 3, working: 2, idle: 1 };
// A sub-agent without a pane isn't in agents(): its raw word, error counting as
// blocked. It's never done: it reports to its parent, and the parent's done is the news.
const kidStatus = (k, listed) => {
  const s = listed.get(k.address) ?? k.status;
  return s === "error" ? "blocked" : s === "done" ? "idle" : s;
};
const SORTS = [
  { id: "priority", label: "Priority", icon: "clock" },
  { id: "grouped", label: "Grouped by space", icon: "layers" },
];
const sortOf = () => SORTS.find((s) => s.id === shared("agents.sort")) ?? SORTS[0];
const SECTION = { 4: "Needs you", 3: "Done", 2: "Working", 1: "Idle" };
const SECTION_STATUS = { 4: "blocked", 3: "done", 2: "working" };

function duration(ms) {
  const m = Math.floor(ms / 60000);
  if (m < 1) return "<1m";
  if (m < 60) return `${m}m`;
  const h = Math.floor(m / 60);
  return h < 24 ? `${h}h` : `${Math.floor(h / 24)}d`;
}

// The agent's icon from the app's program table: a one-color glyph or a picture.
function icon(p, size, color) {
  if (!p?.icon) return null;
  return p.tint ? svg(p.icon).size(size).flex_none().text_color(color) : image(p.icon).w(size).h(size).flex_none();
}

export default class Agents extends View {
  init(_props, cx) {
    if (props()?.sortMenu) return;
    this.folded = new Set();
    // Each agent's last state and when it changed (ms), kept across restarts.
    try { this.changed = JSON.parse(localStorage.getItem("changed") ?? "{}"); } catch { this.changed = {}; }
    if (!this.changed || typeof this.changed !== "object" || Array.isArray(this.changed)) this.changed = {};
    try { this.pendingPins = JSON.parse(localStorage.getItem("pins") ?? "[]"); } catch { this.pendingPins = []; }
    if (!Array.isArray(this.pendingPins)) this.pendingPins = [];
    if (!this.pendingPins.length) localStorage.removeItem("pins");
    this.migratingPins = new Set();
    this.ci = {};
    this.branchUrl = {};
    this.jumped = null;
    this.badge = null;
    this.query = "";
    this.input = InputState.new({ placeholder: "Search: title, space, PR #…" });
    this.input.on("change", (_e, cx) => {
      this.query = this.input.value().trim().toLowerCase();
      cx.notify();
    });
    this.input.on("submit", () => {
      if (this.first) run("pane.focus", { pane: this.first.pane });
    });
    cx.timer.every(30000, (cx) => cx.notify());
    if (checking()) return;
    cx.timer.every(CI_POLL_MS, (cx) => this.pollCi(cx));
    this.pollCi(cx);
    cx.spawn(async (cx) => {
      for (;;) {
        const c = await nextCommand();
        if (c === "attention") this.attention();
        else if (c === "filter") this.cycleFilter();
        else if (c === "review") this.review();
        else if (c === "search") this.input.focus();
        else if (c === "chat") this.toggleChat();
        cx.notify();
      }
    });
  }

  reviews() {
    const out = new Map();
    const agentSet = new Set(agents().map((a) => a.address));
    for (const t of terminals()) {
      const review = t.labels?.["review.terminal"];
      const url = t.labels?.["review.url"] || (agentSet.has(t.address) ? this.branchUrl[this.branchKey(t)]?.url : null) || null;
      if (t.state !== "live" || (!url && !review)) continue;
      const machine = t.address.includes("/") ? t.address.split("/")[0] + "/" : "";
      out.set(t.address, { url, terminal: review ? machine + review : null, cwd: t.cwd ?? null, title: t.labels?.["review.title"] ?? null, space: t.labels?.["herdr.space"] ? machine + t.labels["herdr.space"] : null });
    }
    return out;
  }

  branchKey(t) {
    const machine = t.address.includes("/") ? t.address.split("/")[0] : "";
    return `${machine}|${t.cwd ?? ""}`;
  }

  // The pull or merge request of the branch each agent is on, for agents the
  // review hook has not labelled; looked up again every few minutes.
  async findBranchPrs() {
    const agentSet = new Set(agents().map((a) => a.address));
    const now = Date.now();
    for (const t of terminals()) {
      if (t.state !== "live" || !agentSet.has(t.address) || !t.cwd || t.labels?.["review.url"]) continue;
      const key = this.branchKey(t);
      if (now - (this.branchUrl[key]?.at ?? 0) < BRANCH_MS) continue;
      this.branchUrl[key] = { url: this.branchUrl[key]?.url ?? null, at: now };
      const on = t.address.includes("/") ? t.address.split("/")[0] : null;
      try {
        const r = await exec("sh", ["-c", BRANCH_PR, "branch-pr", t.cwd], { on, timeout: 20000 });
        const url = r.code === 0 ? r.stdout.trim() : "";
        this.branchUrl[key] = { url: /^https?:\/\//.test(url) ? url : null, at: now };
      } catch {}
    }
  }

  pollCi(cx) {
    cx.spawn(async (cx) => {
      await this.findBranchPrs();
      this.pollCiNow(cx);
    });
  }

  pollCiNow(cx) {
    const seen = new Map();
    for (const [address, r] of this.reviews()) if (r.url && !seen.has(r.url)) seen.set(r.url, address);
    cx.spawn(async (cx) => {
      for (const [url, address] of seen) {
        const q = ciQuery(url);
        if (!q) continue;
        const on = address.includes("/") ? address.split("/")[0] : null;
        try {
          const r = await exec(q.cmd, q.args, { on, timeout: 20000 });
          if (r.code === 0) this.ci[url] = { ...q.parse(JSON.parse(r.stdout)), at: Date.now() };
          if (this.ci[url]?.state === "merged" || this.ci[url]?.state === "closed") this.forget(url);
        } catch {}
      }
      cx.notify();
    });
  }

  chatRegistry() {
    const live = new Set(panes().map((p) => p.pane));
    const reg = Object.fromEntries(Object.entries(shared("chat.panes") ?? {}).filter(([p]) => live.has(p)));
    return reg;
  }

  showChat(pane) {
    run("pane.focus", { pane });
    if (panes().find((p) => p.pane === pane)?.zoomed) run("pane.zoom", { pane });
    run("pane.zoom", { pane });
  }

  prefer(address, view) {
    const live = new Set(terminals().filter((x) => x.state === "live").map((x) => x.address));
    const prefs = Object.fromEntries(Object.entries(shared("chat.prefer") ?? {}).filter(([a]) => live.has(a)));
    if (prefs[address] === view) return;
    setShared("chat.prefer", { ...prefs, [address]: view });
  }

  restoreChat() {
    const f = focused();
    const here = f?.pane && panes().find((p) => p.pane === f.pane);
    if (here?.mod === "chat" && !here.zoomed && this.chatRegistry()[here.pane]) run("pane.zoom", { pane: here.pane });
    const term = f?.pane ? f.terminal : null;
    if (term === this.lastFocusedTerm) return;
    this.lastFocusedTerm = term;
    if (!term) return;
    const open = Object.entries(this.chatRegistry()).find(([, t]) => t === term)?.[0];
    const view = (shared("chat.prefer") ?? {})[term] ?? (open ? "chat" : "terminal");
    if (view !== "chat") return;
    if (open) return this.showChat(open);
    this.toggleChat(term);
  }

  toggleChat(target) {
    const f = focused();
    const reg = this.chatRegistry();
    const here = f?.pane && panes().find((p) => p.pane === f.pane);
    if (!target && here?.mod === "chat") {
      const agent = agents().find((a) => a.address === reg[here.pane]);
      if (reg[here.pane]) { this.prefer(reg[here.pane], "terminal"); this.lastFocusedTerm = reg[here.pane]; }
      delete reg[here.pane];
      setShared("chat.panes", reg);
      if (agent) run("pane.focus", { pane: agent.pane });
      run("pane.close", { pane: here.pane });
      return;
    }
    const address = target ?? f?.agent ?? f?.terminal;
    const a = agents().find((x) => x.address === address);
    if (!a || a.app !== "claude-code") return;
    this.prefer(address, "chat");
    const existing = Object.entries(reg).find(([, t]) => t === address)?.[0];
    if (existing) return this.showChat(existing);
    const before = new Set(panes().map((p) => p.pane));
    run("pane.split", { pane: a.pane, direction: "right", mod: "chat", props: { terminal: address, tab: a.tab } });
    this.pendingChat = { address, before, at: Date.now() };
    this.claimChat();
  }

  claimChat() {
    const p = this.pendingChat;
    if (!p) return;
    const fresh = panes().find((x) => x.mod === "chat" && !p.before.has(x.pane));
    if (!fresh) {
      if (Date.now() - p.at > 5000) this.pendingChat = null;
      return;
    }
    this.pendingChat = null;
    setShared("chat.panes", { ...this.chatRegistry(), [fresh.pane]: p.address });
    this.showChat(fresh.pane);
  }

  forget(url) {
    for (const t of terminals()) {
      if (t.state !== "live" || t.labels?.["review.url"] !== url) continue;
      hc(["label", t.address, "review.url=", "review.terminal=", "review.title="]).catch(() => {});
    }
    for (const k of Object.keys(this.branchUrl)) if (this.branchUrl[k]?.url === url) this.branchUrl[k].url = null;
  }

  chatSeenAt(a) {
    return (shared("chat.seen") ?? {})[a.address] ?? 0;
  }

  read(a) {
    return a.status === "done" && this.chatSeenAt(a) >= this.since(a) ? { ...a, status: "idle" } : a;
  }

  attention() {
    const queue = agents().map((a) => this.read(a))
      .filter((a) => a.status === "blocked" || a.status === "done")
      .sort((x, y) => (RANK[y.status] - RANK[x.status]) || this.since(x) - this.since(y));
    if (!queue.length) return;
    const at = queue.findIndex((a) => a.address === this.jumped);
    const next = queue[(at + 1) % queue.length];
    this.jumped = next.address;
    run("agent.focus", { terminal: next.address });
  }

  cycleFilter() {
    const i = FILTERS.findIndex((f) => f.id === filterOf().id);
    setShared("agents-plus.filter", FILTERS[(i + 1) % FILTERS.length].id);
  }

  review() {
    const agent = focused()?.agent ?? focused()?.terminal;
    const all = this.reviews();
    const owner = [...all].find(([, x]) => x.terminal === agent)?.[0];
    if (owner) return run("pane.focus", { terminal: owner });
    const r = agent && all.get(agent);
    if (!r) return;
    const live = r.terminal && terminals().some((t) => t.address === r.terminal && t.state === "live");
    if (live) run("pane.focus", { terminal: r.terminal });
    else this.openReview(r);
  }

  openReview(r) {
    const n = r.url?.match(/\/(?:pull|merge_requests)\/(\d+)/)?.[1];
    const name = r.title || (n ? `${r.url.includes("/pull/") ? "#" : "!"}${n}` : "review");
    run("tab.new", { name, space: r.space ?? undefined, folder: r.cwd ?? undefined, argv: r.url ? ["tuicr", "pr", r.url] : ["tuicr", "-w"] });
  }

  notifyChanges(list) {
    const before = this.lastStatus;
    this.lastStatus = new Map(list.map((a) => [a.address, a.status]));
    if (!before || checking()) return;
    const looking = window()?.active;
    for (const a of list) {
      if (before.get(a.address) === a.status) continue;
      if (a.status !== "blocked" && a.status !== "done") continue;
      if (looking && a.focused) continue;
      if (Date.now() - this.chatSeenAt(a) < 10000) continue;
      const what = clean(a.title);
      exec("terminal-notifier", [
        "-title", a.space_name || a.program?.name || "Herdr",
        "-subtitle", a.status === "blocked" ? "Needs you" : "Finished",
        "-message", what && what !== a.program?.name ? what : a.program?.name ?? a.address,
        "-group", `herdr-${a.address}`,
        "-activate", "dev.herdr.app",
        "-execute", `${APP} do agent.focus --terminal ${a.address}`,
      ]).catch(() => {});
    }
  }

  haystack(a) {
    const r = this.reviewOf.get(a.address);
    const n = r?.url.match(/\/(?:pull|merge_requests)\/(\d+)/)?.[1];
    const c = r && this.ci[r.url];
    return [a.space_name, a.tab_name, clean(a.title), a.program?.name, a.address, r?.url, r?.title, n && `#${n} !${n} pr${n} mr${n}`, c && `ci:${c.ci} ${c.state}`]
      .filter(Boolean).join(" ").toLowerCase();
  }

  searched(a) {
    if (!this.query) return true;
    const text = this.haystack(a);
    return this.query.split(/\s+/).every((tok) => fuzzy(tok, text));
  }

  matches(a, filter, now) {
    if (filter === "all" || a.pinned) return true;
    if (filter === "attention") return a.status === "blocked" || a.status === "done";
    if (filter === "review") {
      const r = this.reviewOf.get(a.address);
      if (!r) return false;
      const c = r.url ? this.ci[r.url] : null;
      return !c || (c.state === "open" && !c.approved);
    }
    if (a.status !== "idle" || a.focused) return true;
    const ci = this.ci[this.reviewOf.get(a.address)?.url];
    if (ci && ci.state === "open" && (ci.ci === "running" || ci.ci === "fail")) return true;
    return now - this.since(a) < RECENT_MS;
  }

  prPill(t, a) {
    const r = this.reviewOf.get(a.address);
    if (!r?.url) return null;
    const c = this.ci[r.url];
    const n = r.url.match(/\/(?:pull|merge_requests)\/(\d+)/)?.[1];
    const ref = `${r.url.includes("/pull/") ? "#" : "!"}${n ?? ""}`;
    const state = c?.state === "merged" || c?.state === "closed" ? c.state : (c?.ci ?? "none");
    const color = { pass: t.done, fail: t.blocked, running: t.working, merged: t.accent, closed: t.dim, none: t.muted }[state] ?? t.muted;
    const ci = { pass: "CI ✓", fail: "CI ✗", running: "CI", merged: "merged", closed: "closed", none: c ? "no CI" : "…" }[state];
    return h_flex()
      .id(`pr-${a.address}`)
      .flex_none()
      .px(5)
      .h(18)
      .gap(4)
      .rounded(5)
      .items_center()
      .bg(color + "26")
      .text_size(10.5)
      .font_semibold()
      .cursor_pointer()
      .tooltip(`${r.url}\nCI: ${state}${c?.approved ? ", approved" : ""}. Click to review in tuicr.`)
      .on_click((_e, cx) => {
        cx.stop_propagation();
        run("pane.focus", { pane: a.pane });
        const live = r.terminal && terminals().some((x) => x.address === r.terminal && x.state === "live");
        if (live) run("pane.focus", { terminal: r.terminal });
        else this.openReview(r);
      })
      .child(div().text_color(t.muted).child(ref))
      .when(state === "running", (el) => el.child(svg("mods/workspace-chrome/spinner.svg").size(10).flex_none().text_color(color).spin(900)))
      .child(div().text_color(color).child(ci))
      .when(Boolean(c?.approved) && state !== "merged", (el) => el.child(div().text_color(t.done).child("approved")));
  }

  filterBar(t) {
    const on = filterOf().id;
    return h_flex()
      .px(14)
      .pb(6)
      .flex_wrap()
      .gap_x(4)
      .gap_y(4)
      .flex_none()
      .children(FILTERS.map((f) => div()
        .id(`flt-${f.id}`)
        .flex_none()
        .px(7)
        .h(20)
        .rounded(6)
        .flex()
        .items_center()
        .gap(4)
        .text_size(11)
        .cursor_pointer()
        .text_color(f.id === on ? t.foreground : t.dim)
        .when(f.id === on, (el) => el.bg(t.selected))
        .hover((s) => s.bg(t.hover).text_color(t.foreground))
        .on_click(() => setShared("agents-plus.filter", f.id))
        .child(f.label)
        .when(f.id !== "all", (el) => el.child(this.countBadge(t, f.id)))));
  }

  countBadge(t, id) {
    const n = this.counts?.[id] ?? 0;
    const color = n === 0 ? t.dim : { active: t.working, attention: t.blocked, review: t.accent }[id] ?? t.dim;
    return div()
      .min_w(15)
      .h(15)
      .px(4)
      .rounded(8)
      .flex()
      .items_center()
      .justify_center()
      .bg(color + (n === 0 ? "1a" : "2e"))
      .text_size(10)
      .font_semibold()
      .text_color(color)
      .child(String(n));
  }

  // Stamps agents whose state changed. Done and idle count as one: looking at a
  // finished agent turns done into idle, and looking isn't the agent doing anything.
  track(list, now) {
    let dirty = false;
    for (const a of list) {
      const s = a.status === "done" ? "idle" : a.status;
      if (this.changed[a.address]?.s === s) continue;
      this.changed[a.address] = { s, at: now };
      dirty = true;
    }
    if (!dirty) return;
    // Gone and old: the list alone is empty right after a start.
    const listed = new Set(list.map((a) => a.address));
    for (const [k, c] of Object.entries(this.changed)) if (!listed.has(k) && now - c.at > 30 * 86400000) delete this.changed[k];
    localStorage.setItem("changed", JSON.stringify(this.changed));
  }

  // Keep offline pins until their terminal returns, and keep each pending until
  // core echoes the label so a failed write doesn't erase the old pin.
  migratePins(all) {
    const listed = new Map(all.filter((t) => t.state === "live").map((t) => [t.address, t]));
    const pending = this.pendingPins.filter((address) => {
      const terminal = listed.get(address);
      if (!terminal) return true;
      if (terminal.labels?.["herdr.pinned"]) return false;
      if (!this.migratingPins.has(address)) {
        this.migratingPins.add(address);
        run("terminal.pin", { terminal: address, pinned: true });
      }
      return true;
    });
    if (pending.length === this.pendingPins.length) return;
    this.pendingPins = pending;
    if (pending.length) localStorage.setItem("pins", JSON.stringify(pending));
    else localStorage.removeItem("pins");
  }

  since(a) {
    return this.changed[a.address]?.at ?? 0;
  }

  rank(a) {
    return RANK[a.status] ?? 0;
  }

  sortMenu(t) {
    const on = sortOf().id;
    return v_flex()
      .w_full()
      .p(5)
      .bg(t.popover)
      .text_size(12.8)
      .child(div().px(8).pt(4).pb(6).text_size(11).text_color(t.dim).child("Sort agents"))
      .children(SORTS.map((s) => h_flex()
        .id(`sort-${s.id}`)
        .h(31)
        .px(8)
        .gap(9)
        .rounded(7)
        .items_center()
        .text_color(t.foreground)
        .hover((el) => el.bg(t.hover))
        .on_click(() => {
          setShared("agents.sort", s.id);
          closeOverlay(props().overlay);
        })
        .child(svg(`mods/workspace-chrome/${s.icon}.svg`).size(14).flex_none().text_color(t.muted))
        .child(div().flex_1().child(s.label))
        .when(s.id === on, (el) => el.child(svg("mods/workspace-chrome/check.svg").size(14).flex_none().text_color(t.foreground)))));
  }

  peek(addr) {
    run("terminal.peek", { terminal: addr });
  }

  // Live sub-agents of `addr`, depth first, each with the tree lines in front of it.
  tree(all, addr, lead = []) {
    const kids = all.filter((k) => k.parent === addr && k.state === "live");
    return kids.flatMap((k, i) => {
      const last = i === kids.length - 1;
      return [
        { t: k, lines: [...lead, last ? "└" : "├"] },
        ...this.tree(all, k.address, [...lead, last ? "" : "│"]),
      ];
    });
  }

  subRow(t, s, shown, compact) {
    const k = s.t;
    const st = kidStatus(k, this.listed);
    const pic = icon(k.program, 14, t.foreground);
    const on = k.address === shown;
    return h_flex()
      .id(`sub-${k.address}`)
      .pl(39)
      .pr(8)
      .rounded(8)
      .h(26)
      .flex_none()
      .gap(0)
      .items_center()
      .text_size(12.5)
      .when(on, (el) => el.bg(t.raised))
      .hover((s) => s.bg(t.hover))
      .on_click(() => (this.listed.has(k.address) ? run("pane.focus", { terminal: k.address }) : this.peek(k.address)))
      .children(s.lines.map(l => div().self_start().mt(-4).w(9).h(17).mr(4).flex_none()
        .when(Boolean(l), el => el.border_l(1.5).border_color(t.input))
        .when(l === "└" || l === "├", el => el.border_b(1.5).rounded_bl(6))))
      .when(Boolean(pic), el => el.child(div().mr(8).child(pic)))
      .child(div().flex_1().truncate().text_color(on ? t.foreground : t.muted).child(k.name || k.template || k.program?.name || k.address))
      .child(this.status(t, { status: st }, compact));
  }

  // compact: a ! for blocked where a header already says "Needs you".
  status(t, a, compact = false) {
    const color = t[a.status] ?? t.dim;
    if (a.status === "working") return svg("mods/workspace-chrome/spinner.svg").size(12).mx(1).flex_none().text_color(t.working).spin(900);
    if (a.status === "blocked" && compact) return div().size(14).flex_none().rounded(4).bg(t.blocked + "26").text_size(10.5).font_bold().text_color(t.blocked).flex().items_center().justify_center().child("!");
    if (a.status === "blocked") return div().flex_none().px(6).h(18).rounded(5).bg(t.blocked + "26").text_size(10.5).font_semibold().text_color(t.blocked).flex().items_center().child("Needs you");
    // Idle: a ring; done: a dot.
    if (a.status === "idle") return div().size(7).mx(3).flex_none().rounded(4).border(1.5).border_color(t.idle ?? t.dim);
    return div().size(7).mx(3).flex_none().rounded(4).bg(a.status === "done" ? color : t.dim + "00");
  }

  render(cx) {
    const t = theme();
    if (props()?.sortMenu) return this.sortMenu(t);
    const collapsed = narrow();
    const sort = sortOf();
    let list = agents();
    this.notifyChanges(list);
    if (this.pendingChat && !checking()) this.claimChat();
    else if (!checking()) this.restoreChat();
    this.listed = new Map(list.map((a) => [a.address, a.status]));
    const all = terminals();
    this.migratePins(all);
    const shown = focused()?.agent;
    const now = Date.now();
    this.track(list, now);
    list = list.map((a) => this.read(a));
    this.reviewOf = this.reviews();
    const waiting = list.filter((a) => a.status === "blocked").length;
    const badge = waiting ? String(waiting) : null;
    if (badge !== this.badge && !checking()) { this.badge = badge; setBadge(badge); }
    const found = collapsed ? list : list.filter((a) => this.searched(a));
    this.counts = Object.fromEntries(FILTERS.map((f) => [f.id, found.filter((a) => this.matches({ ...a, pinned: false }, f.id, now)).length]));
    const filter = collapsed ? "all" : filterOf().id;
    list = found.filter((a) => this.matches(a, filter, now));
    this.first = list[0] ?? null;
    // A kept sub-agent (one with a pane) is in agents() too: where a tree shows
    // it, it gets no row of its own, unless it's pinned.
    const nested = new Set(collapsed ? [] : list.flatMap((a) => this.tree(all, a.address).map((s) => s.t.address)));
    list = list.filter((a) => a.pinned || !nested.has(a.address));
    const tabCounts = new Map();
    for (const a of list) tabCounts.set(a.tab, (tabCounts.get(a.tab) ?? 0) + 1);
    const byPriority = sort.id === "priority";
    const urgency = new Map(list.map((a) => [a.address, Math.max(this.rank(a), ...this.tree(all, a.address).map((s) => RANK[kidStatus(s.t, this.listed)] ?? 0))]));
    const rankOf = (a) => urgency.get(a.address);
    if (byPriority) list = [...list].sort((x, y) => rankOf(y) - rankOf(x) || this.since(y) - this.since(x) || y.seq - x.seq);
    const pinned = list.filter((a) => a.pinned);
    const rest = list.filter((a) => !a.pinned);
    list = [...pinned, ...rest];
    setAgentOrder(list.map((a) => a.address));

    const withKids = (a, i) => {
      const subs = collapsed ? [] : this.tree(all, a.address);
      const r = row(a, i, subs);
      if (this.folded.has(a.address)) return [r];
      return [r, ...subs.map((s) => this.subRow(t, s, shown, byPriority))];
    };

    // The fold chevron; folded, the count too, colored by the most urgent one.
    const fold = (a, subs) => {
      const sts = subs.map((s) => kidStatus(s.t, this.listed));
      const top = sts.reduce((m, s) => ((RANK[s] ?? 0) > (RANK[m] ?? 0) ? s : m), null);
      const open = !this.folded.has(a.address);
      return div()
        .id(`fold-${a.address}`)
        .h(18)
        .px(3)
        .gap(3)
        .flex()
        .items_center()
        .rounded(4)
        .text_size(11)
        .text_color(open ? t.dim : (t[top] ?? t.dim))
        .cursor_pointer()
        .hover((s) => s.bg(t.hover).text_color(t.foreground))
        .on_click((_e, cx) => {
          cx.stop_propagation();
          open ? this.folded.add(a.address) : this.folded.delete(a.address);
          cx.notify();
        })
        .child(svg(`mods/workspace-chrome/chevron-${open ? "down" : "right"}.svg`).size(11).flex_none())
        .when(!open, (el) => el.child(String(subs.length)));
    };

    // A row reads "space \u00b7 detail": the detail is a tab someone named or the
    // agent's own title, never an automatic tab number unless two rows would
    // otherwise read the same.
    // Read the pane snapshot once: every host read copies the whole list into JS.
    const leads = leadPanes(panes());
    const tabs = new Map(spaces().flatMap(s => s.tabs).map(tab => [tab.id, tab]));
    const labels = new Map(list.map(a => {
      const tab = tabs.get(a.tab);
      const many = tabCounts.get(a.tab) > 1;
      return [a.address, tab ? title(many ? { ...tab, named: false } : tab, many ? a : leads.get(a.tab)) : (a.title || a.program?.name || "")];
    }));
    const label = (a) => labels.get(a.address);
    const detail = new Map(list.map(a => [a.address, /^\d+$/.test(label(a)) ? null : label(a)]));
    const seen = {};
    for (const a of list) { const k = `${a.space_name}\u0000${detail.get(a.address) ?? ""}`; seen[k] = (seen[k] ?? 0) + 1; }
    for (const a of list) {
      if (detail.get(a.address) == null && seen[`${a.space_name}\u0000`] > 1) detail.set(a.address, label(a));
    }

    const row = (a, i, subs = []) => {
      const pic = icon(a.program, 16, t.foreground);
      const more = detail.get(a.address);
      // An agent on another machine (`vps/t7`) says which.
      const machine = a.address.includes("/") ? a.address.split("/")[0] : null;
      if (collapsed) {
        return h_flex()
          .id(`ag-${a.address}`)
          .h(26)
          .px(8)
          .flex_none()
          .items_center()
          .gap(4)
          .hover((s) => s.bg(t.hover))
          .on_click(() => run("pane.focus", { pane: a.pane }))
          .child(div().flex_1().min_w(0).whitespace_nowrap().text_right().text_color(t.muted).child(String(i + 1)))
          .child(h_flex().w(14).flex_none().items_center().justify_center().child(this.status(t, a, true)));
      }
      const when = this.since(a);
      const idle = a.status === "idle" && !a.focused;
      const isPinned = a.pinned;
      const pin = div()
        .id(`pin-${a.address}`)
        .flex_none()
        .p(2)
        .rounded(4)
        .text_color(t.dim)
        .cursor_pointer()
        .hover((s) => s.bg(t.hover).text_color(t.foreground))
        .tooltip(isPinned ? "Unpin" : "Pin to the top")
        .on_click((_e, cx) => {
          cx.stop_propagation();
          run("terminal.pin", { terminal: a.address, pinned: !isPinned });
          // The row moves away from under the pointer, and no hover-out comes.
          this.hovered = null;
          cx.notify();
        })
        .child(svg(`mods/workspace-chrome/${isPinned ? "pin-off" : "pin"}.svg`).size(13));
      // Under a space header the space goes without saying; an automatic tab number says nothing.
      // Without a space header above (priority, pinned) the row names its space.
      const full = byPriority || isPinned;
      const name = full ? a.space_name || label(a) : more ?? (/^\d+$/.test(label(a)) ? a.program?.name || label(a) : label(a));
      return h_flex()
        .id(`ag-${a.address}`)
        .px(8)
        .h(30)
        .flex_none()
        .rounded(8)
        .items_center()
        .gap(9)
        .when(a.focused, (el) => el.bg(t.selected))
        .cursor_pointer()
        .hover((s) => s.bg(t.hover))
        .on_hover((on, cx) => {
          if (on) this.hovered = a.address;
          else if (this.hovered === a.address) this.hovered = null;
          cx.notify();
        })
        .on_click(() => run("pane.focus", { pane: a.pane }))
        .when(Boolean(shared("leader.jump")?.[a.address]), el => el.child(div().flex_none().px(4).h(18).rounded(4).bg(t.accent).text_size(11).font_bold().text_color(t.accent_foreground).flex().items_center().child(shared("leader.jump")[a.address])))
        .when(Boolean(pic), el => el.child(div().id(`agent-fold-${a.address}`)
          .when(subs.length > 0, el => el.on_click((_e, cx) => {
            cx.stop_propagation();
            this.folded.has(a.address) ? this.folded.delete(a.address) : this.folded.add(a.address);
            cx.notify();
          })).child(pic)))
        .child(h_flex().flex_1().min_w(0).gap(5).items_center()
          .child(div().min_w(0).max_w(full && more ? 120 : 200).truncate().text_color(idle ? t.muted : t.foreground).child(name))
          .when(full && Boolean(more), el => el.child(div().flex_1().min_w(0).truncate().text_color(t.dim).child(`\u00b7 ${more}`))))
        .when(Boolean(machine), el => el.child(div().text_size(10).text_color(t.dim).child(machine)))
        .when(subs.length > 0, el => el.child(fold(a, subs)))
        .when(Boolean(this.prPill(t, a)), el => el.child(this.prPill(t, a)))
        .when(this.hovered === a.address && a.app === "claude-code", el => el.child(div()
          .id(`chat-${a.address}`)
          .flex_none()
          .px(4)
          .h(18)
          .rounded(4)
          .flex()
          .items_center()
          .text_size(10.5)
          .text_color(t.dim)
          .cursor_pointer()
          .hover((s) => s.bg(t.hover).text_color(t.foreground))
          .tooltip("Chat with this agent (⌘⇧C)")
          .on_click((_e, cx) => {
            cx.stop_propagation();
            this.toggleChat(a.address);
            cx.notify();
          })
          .child("chat")))
        .when(this.hovered === a.address, el => el.child(pin))
        .when(this.hovered !== a.address && Boolean(when), el => el.child(div().flex_none().text_size(11).text_color(t.dim).child(duration(now - when))))
        .child(this.status(t, a, byPriority && !isPinned));
    };

    // Groups in list order: spaces (grouped) or priority sections. Agents of a
    // space are next to each other in agents(), so neighbours make a group.
    const groups = pinned.length ? [{ id: "pinned", label: "Pinned", status: null, members: pinned }] : [];
    for (const a of rest) {
      const r = rankOf(a) || RANK.idle;
      const id = byPriority ? `sec-${r}` : `sp-${a.space}`;
      if (groups.at(-1)?.id === id) groups.at(-1).members.push(a);
      else groups.push({ id, label: byPriority ? SECTION[r] : a.space_name || "", status: byPriority ? SECTION_STATUS[r] : null, members: [a] });
    }

    // A group's header; it folds the group. Folded, it says how many and the most urgent state.
    const header = (g) => {
      const open = !this.folded.has(g.id);
      const top = g.members.reduce((m, a) => ((RANK[a.status] ?? 0) > (RANK[m] ?? 0) ? a.status : m), null);
      return h_flex()
        .id(g.id)
        .px(8)
        .pt(8)
        .h(30)
        .flex_none()
        .gap(6)
        .items_center()
        .text_size(11)
        .font_medium()
        .cursor_pointer()
        .hover((s) => s.text_color(t.foreground))
        .on_click((_e, cx) => {
          open ? this.folded.add(g.id) : this.folded.delete(g.id);
          cx.notify();
        })
        .child(div().truncate().text_color(t[g.status] ?? t.dim).child(g.label))
        .when(byPriority || !open, (el) => el.child(div().text_color(t.dim).child(String(g.members.length))))
        .child(div().flex_1())
        .when(!open, (el) => el
          .when(!byPriority && top && top !== "idle", (el) => el.child(this.status(t, { status: top }, true)))
          .child(svg("mods/workspace-chrome/chevron-right.svg").size(11).flex_none().text_color(t.dim)));
    };
    const rows = collapsed
      ? list.flatMap(withKids)
      : groups.flatMap((g) => [header(g), ...(this.folded.has(g.id) ? [] : g.members.flatMap(withKids))]);

    return v_flex()
      .size_full()
      .min_h(0)
      .bg(t.chrome)
      .border_t(1)
      .border_color(t.border)
      .text_size(13)
      .when(!collapsed, (el) =>
        el.child(
          h_flex()
            .px(16)
            .h(41)
            .pt(14)
            .pb(5)
            .flex_none()
            .items_center()
            .justify_between()
            .child(div().text_size(11.5).font_medium().text_color(t.dim).child("Agents"))
            .child(
              div()
                .id("ag-sort")
                .text_size(11)
                .text_color(t.dim)
                .hover((s) => s.text_color(t.foreground))
                .on_click(() => openOverlay({ mod: SELF, kind: "popup", width: 200, height: 140, props: { sortMenu: true } }))
                .tooltip(`Sort agents: ${sort.label}`)
                .child(svg(`mods/workspace-chrome/${sort.icon}.svg`).size(14)),
            ),
        ),
      )
      .when(!collapsed, (el) => el.child(this.filterBar(t)))
      .when(!collapsed, (el) => el.child(
        h_flex().mx(14).mb(6).h(26).px(8).gap(6).flex_none().items_center().rounded(7).border_1().border_color(t.border).bg(t.background)
          .on_key_down((e, cx) => {
            if (e.key !== "escape") return;
            this.input.set_value("");
            this.query = "";
            cx.stop_propagation();
            cx.notify();
          })
          .child(svg("mods/workspace-chrome/search.svg").size(12).flex_none().text_color(t.dim))
          .child(Input.new(this.input).flex_1().h_full().text_size(12).text_color(t.foreground))))
      .when(list.length === 0 && !collapsed, (el) =>
        el.child(div().px(12).text_size(12).text_color(t.dim).child(filter === "all"
          ? "No agent status yet. Agents show up here when they report their status. Older versions and agents inside tmux may not."
          : `No agents match “${filterOf().label}”.`)),
      )
      .child(v_flex().id("ag-list").flex_1().min_h(0).px(collapsed ? 0 : 8).overflow_y_scrollbar().mode("always").children(rows))
      .when(collapsed, (el) =>
        el.child(
          h_flex()
            .h(28)
            .items_center()
            .justify_center()
            .child(
              div()
                .id("collapse")
                .text_size(13)
                .text_color(t.dim)
                .hover((s) => s.text_color(t.foreground))
                .on_click(toggleSidebar)
                .child("»"),
            ),
        ),
      );
  }
}
