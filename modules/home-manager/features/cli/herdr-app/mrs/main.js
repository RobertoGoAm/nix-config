import { View, div } from "gpui-kit";
import { v_flex, h_flex, TextareaState, Textarea, Scrollbar, v_virtual_list, VirtualListScrollHandle } from "gpui-base";
import { run, exec, theme, settings, props, checking, nextCommand, window } from "herdr";

const POLL_MS = 120000;
const STALE_MS = 30000;
const CONFIRM_MS = 5000;

const rowHeight = (size) => Math.ceil(size * 1.7);
const charWidth = (size) => size * 0.62;

const untab = (text) => text.replace(/[^\t]*\t/g, (s) => s.slice(0, -1).padEnd((s.length - 1) - (s.length - 1) % 4 + 4));

const age = (when) => {
  const t = Date.parse(when ?? "");
  if (!Number.isFinite(t)) return "";
  const m = Math.floor((Date.now() - t) / 60000);
  if (m < 1) return "now";
  if (m < 60) return `${m}m`;
  if (m < 1440) return `${Math.floor(m / 60)}h`;
  if (m < 60 * 24 * 60) return `${Math.floor(m / 1440)}d`;
  return `${Math.floor(m / 43200)}mo`;
};

async function helper(args, timeout = 90000) {
  const r = await exec("mr-review", args, { timeout });
  let answer = null;
  try { answer = JSON.parse(r.stdout || "null"); } catch { answer = null; }
  if (r.code !== 0 || !answer || answer.error) {
    throw new Error(answer?.error || r.stderr.trim().split("\n").pop() || `mr-review ${args[0]} failed`);
  }
  return answer;
}

// One file's unified diff as rows. oc and nc are the old and new line counters
// at the row, which GitLab's line codes are made of even on a one-sided line.
function parseDiff(text) {
  const rows = [];
  let o = 0, n = 0;
  for (const line of text.split("\n")) {
    const m = /^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@(.*)$/.exec(line);
    if (m) {
      o = +m[1]; n = +m[2];
      rows.push({ kind: "hunk", text: line });
      continue;
    }
    const sign = line[0];
    const text = untab(line.slice(1)) || " ";
    if (sign === "+") { rows.push({ kind: "line", sign, old: null, new: n, oc: o, nc: n, text }); n++; }
    else if (sign === "-") { rows.push({ kind: "line", sign, old: o, new: null, oc: o, nc: n, text }); o++; }
    else if (sign === " ") { rows.push({ kind: "line", sign, old: o, new: n, oc: o, nc: n, text }); o++; n++; }
  }
  return rows;
}

function wrap(text, cols) {
  const out = [];
  for (const para of String(text ?? "").replace(/\r/g, "").split("\n")) {
    let rest = untab(para);
    if (!rest) { out.push(""); continue; }
    while (rest.length > cols) {
      let cut = rest.lastIndexOf(" ", cols);
      if (cut < cols / 2) cut = cols;
      out.push(rest.slice(0, cut));
      rest = rest.slice(cut).replace(/^ /, "");
    }
    out.push(rest);
  }
  while (out.length > 1 && out[out.length - 1] === "") out.pop();
  return out;
}

const pipelineMark = (t, status) => {
  const s = String(status ?? "none").toLowerCase();
  if (s === "success") return { text: "✓", color: t.done, label: "pipeline passed" };
  if (s === "failed") return { text: "✗", color: t.blocked, label: "pipeline failed" };
  if (/running|pending|created|preparing|waiting|scheduled/.test(s)) return { text: "●", color: t.working, label: `pipeline ${s}` };
  if (s === "manual") return { text: "▸", color: t.dim, label: "pipeline waits for a manual job" };
  if (s === "canceled" || s === "skipped") return { text: "–", color: t.dim, label: `pipeline ${s}` };
  return null;
};

const GROUPS = [
  { id: "review", label: "To review", test: (m) => m.review && !m.mine },
  { id: "mine", label: "Mine", test: (m) => m.mine },
  { id: "others", label: "Others", test: (m) => !m.mine && !m.review },
];

const HINTS = "n e move · ]f [f file · ]c [c change · ]t [t thread · v select · c comment · C general · r reply · x resolve · D drop draft · a approve · S submit · o browser · t tuicr · R refresh";

export default class Mrs extends View {
  init(_props, cx) {
    const p = props() ?? {};
    this.folder = p.folder ?? null;
    this.space = p.space ?? "";
    this.handle = cx.focus_handle();
    this.scroll = VirtualListScrollHandle.new();
    this.list = null;
    this.listError = null;
    this.listAt = 0;
    this.detail = null;
    this.detailError = null;
    this.detailAt = 0;
    this.loadingList = false;
    this.loadingDetail = false;
    this.token = 0;
    this.rows = [];
    this.cur = 0;
    this.visual = null;
    this.side = "diff";
    this.pick = 0;
    this.prefix = null;
    this.confirm = null;
    this.busy = null;
    this.flash = null;
    this.editing = null;
    this.cols = 100;
    this.width = 0;
    this.longest = 0;
    this.activeBefore = true;
    this.editor = TextareaState.new({ placeholder: "Comment (markdown)", rows: 3 });
    this.editor.set_auto_grow(3, 10);
    this.editor.on("submit", (_e, cx) => this.save(cx));
    if (checking()) return;
    let saved = null;
    try { saved = JSON.parse(localStorage.getItem(`sel:${this.space}`) ?? "null"); } catch { saved = null; }
    this.iid = Number.isInteger(saved) ? saved : null;
    this.loadList(cx);
    cx.timer.every(POLL_MS, (cx) => this.poll(cx));
    cx.timer.every(3000, (cx) => {
      const active = window()?.active !== false;
      if (active && !this.activeBefore) this.freshen(cx);
      this.activeBefore = active;
    });
    cx.spawn(async (cx) => {
      for (;;) {
        const c = await nextCommand();
        if (c === "focus") {
          if (this.editing) this.editor.focus();
          else this.handle.focus();
          this.freshen(cx);
        }
        cx.notify();
      }
    });
  }

  poll(cx) {
    if (window()?.active === false) return;
    this.loadList(cx, true);
  }

  freshen(cx) {
    if (Date.now() - this.listAt > STALE_MS) this.loadList(cx, true);
  }

  loadList(cx, quiet = false) {
    if (!this.folder || this.fetching) return;
    this.fetching = true;
    this.loadingList = !quiet || !this.list;
    cx.spawn(async (cx) => {
      try {
        const list = await helper(["list", this.folder]);
        this.list = list;
        this.listError = null;
        this.listAt = Date.now();
        const mrs = this.ordered();
        const shown = mrs.find((m) => m.iid === this.iid);
        if (!shown && mrs.length && !this.editing) {
          this.iid = (mrs.find((m) => m.review && !m.mine) ?? mrs[0]).iid;
          this.loadDetail(cx);
        } else if (shown && (!this.detail || this.detail.mr.iid !== shown.iid || this.changedSince(shown))) {
          if (!this.editing) this.loadDetail(cx, Boolean(this.detail));
        }
        this.pick = Math.max(0, mrs.findIndex((m) => m.iid === this.iid));
      } catch (e) {
        this.listError = String(e.message ?? e);
      } finally {
        this.fetching = false;
        this.loadingList = false;
        cx.notify();
      }
    });
    cx.notify();
  }

  changedSince(m) {
    if (!this.detail) return true;
    if (Date.now() - this.detailAt > POLL_MS) return true;
    const d = this.detail.mr;
    return Date.parse(m.updated) > this.detailAt || d.approved !== m.approved || (m.pipeline ?? "none") !== String(d.pipeline ?? "none").toLowerCase();
  }

  loadDetail(cx, quiet = false) {
    if (this.iid == null) return;
    const token = ++this.token;
    const iid = this.iid;
    if (!quiet || this.detail?.mr.iid !== iid) this.loadingDetail = true;
    cx.spawn(async (cx) => {
      try {
        const detail = await helper(["show", this.folder, String(iid)]);
        if (token !== this.token) return;
        const keep = this.detail?.mr.iid === iid ? this.anchor() : this.savedAnchor(iid);
        this.detail = detail;
        this.detailError = null;
        this.detailAt = Date.now();
        this.build();
        this.restore(keep);
      } catch (e) {
        if (token !== this.token) return;
        this.detailError = String(e.message ?? e);
      } finally {
        if (token === this.token) this.loadingDetail = false;
        cx.notify();
      }
    });
    cx.notify();
  }

  ordered() {
    const mrs = this.list?.mrs ?? [];
    return GROUPS.flatMap((g) => mrs.filter(g.test));
  }

  open(cx, iid) {
    if (iid === this.iid && this.detail?.mr.iid === iid) { this.side = "diff"; return; }
    this.saveAnchor();
    this.iid = iid;
    this.visual = null;
    this.confirm = null;
    this.detail = this.detail?.mr.iid === iid ? this.detail : null;
    this.rows = [];
    this.cur = 0;
    try { localStorage.setItem(`sel:${this.space}`, JSON.stringify(iid)); } catch {}
    this.loadDetail(cx);
  }

  build() {
    const d = this.detail;
    const rows = [];
    const cols = Math.max(40, this.cols);
    const push = (row) => rows.push(row);
    const threads = d.threads ?? [];
    const drafts = d.drafts ?? [];
    const placed = new Set();
    const placedDrafts = new Set();
    const onLine = (at, file, row) => at && (at.path === file.new_path || at.old_path === file.old_path)
      && (at.new_line != null ? row.new === at.new_line : at.old_line != null && row.old === at.old_line && row.new == null);
    const thread = (th, fi) => {
      placed.add(th.id);
      th.notes.forEach((note, k) => {
        const status = k === 0 && th.resolvable ? (th.resolved ? "resolved" : "open") : "";
        push({ kind: "note", head: true, file: fi, thread: th.id, author: note.author, when: note.created, status, reply: k > 0 });
        for (const text of wrap(note.body, cols - (k > 0 ? 4 : 2))) push({ kind: "note", file: fi, thread: th.id, text, reply: k > 0, resolved: th.resolved });
      });
      for (const dr of drafts.filter((x) => x.reply_to === th.id)) draft(dr, fi, true);
    };
    const draft = (dr, fi, reply = false) => {
      placedDrafts.add(dr.id);
      push({ kind: "draft", head: true, file: fi, draft: dr.id, reply });
      for (const text of wrap(dr.body, cols - 4)) push({ kind: "draft", file: fi, draft: dr.id, text, reply });
    };

    if (d.mr.description?.trim()) {
      push({ kind: "title", text: "Description" });
      for (const text of wrap(d.mr.description, cols)) push({ kind: "text", text });
      push({ kind: "gap" });
    }
    let longest = 0;
    d.files.forEach((f, fi) => {
      const parsed = f.too_large ? [] : parseDiff(f.diff ?? "");
      const add = parsed.filter((r) => r.sign === "+").length, del = parsed.filter((r) => r.sign === "-").length;
      push({ kind: "file", file: fi, status: f.status, path: f.new_path, from: f.status === "R" ? f.old_path : null, add, del });
      if (f.too_large) push({ kind: "text", file: fi, text: "Too large for GitLab to show: open it in the browser (o) or tuicr (t)." });
      else if (f.generated) push({ kind: "text", file: fi, text: "Generated file." });
      for (const r of parsed) {
        const row = { ...r, file: fi };
        longest = Math.max(longest, row.text.length);
        push(row);
        if (row.kind !== "line") continue;
        for (const th of threads) if (!placed.has(th.id) && onLine(th.at, f, row)) thread(th, fi);
        for (const dr of drafts) if (!dr.reply_to && !placedDrafts.has(dr.id) && onLine(dr.at, f, row)) draft(dr, fi);
      }
      const stray = threads.filter((th) => !placed.has(th.id) && th.at && (th.at.path === f.new_path || th.at.old_path === f.old_path));
      const strayDrafts = drafts.filter((dr) => !dr.reply_to && !placedDrafts.has(dr.id) && dr.at && (dr.at.path === f.new_path || dr.at.old_path === f.old_path));
      if (stray.length || strayDrafts.length) {
        push({ kind: "hunk", file: fi, text: "On lines no longer in the diff" });
        for (const th of stray) thread(th, fi);
        for (const dr of strayDrafts) draft(dr, fi);
      }
      push({ kind: "gap", file: fi });
    });
    const general = threads.filter((th) => !placed.has(th.id));
    const generalDrafts = drafts.filter((dr) => !placedDrafts.has(dr.id) && !dr.reply_to);
    if (general.length || generalDrafts.length) {
      push({ kind: "title", text: "Conversation" });
      for (const th of general) thread(th, null);
      for (const dr of generalDrafts) draft(dr, null);
    }
    for (const dr of drafts) if (!placedDrafts.has(dr.id)) draft(dr, null, true);
    this.rows = rows;
    this.longest = longest;
    this.cur = Math.min(this.cur, Math.max(0, rows.length - 1));
  }

  row(i = this.cur) { return this.rows[i] ?? null; }

  anchor(i = this.cur) {
    const r = this.row(i);
    if (!r) return null;
    const f = r.file != null ? this.detail?.files[r.file] : null;
    return { kind: r.kind, path: f?.new_path ?? null, old: r.old ?? null, new: r.new ?? null, thread: r.thread ?? null, draft: r.draft ?? null, index: i };
  }

  savedAnchor(iid) {
    try { return JSON.parse(localStorage.getItem(`pos:${this.space}:${iid}`) ?? "null"); } catch { return null; }
  }

  saveAnchor() {
    if (!this.detail) return;
    try { localStorage.setItem(`pos:${this.space}:${this.detail.mr.iid}`, JSON.stringify(this.anchor())); } catch {}
  }

  restore(a) {
    if (!a) { this.cur = this.firstLine(); this.scroll.scroll_to_item(this.cur, "center"); return; }
    const files = this.detail.files;
    let i = -1;
    if (a.thread) i = this.rows.findIndex((r) => r.thread === a.thread && r.head);
    if (i < 0 && a.draft) i = this.rows.findIndex((r) => r.draft === a.draft && r.head);
    if (i < 0 && a.path) {
      i = this.rows.findIndex((r) => r.kind === "line" && files[r.file]?.new_path === a.path && r.old === a.old && r.new === a.new);
      if (i < 0) i = this.rows.findIndex((r) => r.kind === "file" && r.path === a.path);
    }
    this.cur = i >= 0 ? i : Math.min(a.index ?? 0, this.rows.length - 1);
    this.cur = Math.max(0, this.cur);
    this.scroll.scroll_to_item(this.cur, "center");
  }

  firstLine() {
    const i = this.rows.findIndex((r) => r.kind === "line" && r.sign !== " ");
    return i >= 0 ? i : 0;
  }

  go(i) {
    if (!this.rows.length) return;
    this.cur = Math.max(0, Math.min(this.rows.length - 1, i));
    this.scroll.scroll_to_item(this.cur, "center");
    this.saveAnchor();
  }

  seek(dir, test) {
    for (let i = this.cur + dir; i >= 0 && i < this.rows.length; i += dir) {
      if (test(this.rows[i], i)) { this.go(i); return true; }
    }
    return false;
  }

  isChange(r, i) {
    if (r.kind !== "line" || r.sign === " ") return false;
    const before = this.rows[i - 1];
    return !(before?.kind === "line" && before.sign !== " ");
  }

  page() { return Math.max(4, Math.floor((this.height || 600) / rowHeight(settings().font_size) / 2)); }

  say(text, error = false) { this.flash = { text, error, at: Date.now() }; }

  act(cx, label, args, done) {
    if (this.busy) return;
    this.busy = label;
    cx.spawn(async (cx) => {
      try {
        await helper(args);
        if (done) this.say(done);
        this.loadDetail(cx, true);
        this.loadList(cx, true);
      } catch (e) {
        this.say(String(e.message ?? e), true);
      } finally {
        this.busy = null;
        cx.notify();
      }
    });
    cx.notify();
  }

  threadHere() {
    const r = this.row();
    if (!r) return null;
    if (r.thread) return this.detail.threads.find((t) => t.id === r.thread) ?? null;
    if (r.kind === "line") {
      for (let i = this.cur + 1; i < this.rows.length && (this.rows[i].kind === "note" || this.rows[i].kind === "draft"); i++) {
        if (this.rows[i].thread) return this.detail.threads.find((t) => t.id === this.rows[i].thread) ?? null;
      }
    }
    return null;
  }

  lineArgs(r) {
    const f = this.detail.files[r.file];
    return [f.new_path, f.old_path, r.sign === "+" ? "" : String(r.old), r.sign === "-" ? "" : String(r.new)];
  }

  startComment(cx, general = false) {
    if (!this.detail) return;
    if (general) {
      this.editing = { kind: "general", label: "General comment" };
    } else {
      let from = this.visual != null ? Math.min(this.visual, this.cur) : this.cur;
      let to = this.visual != null ? Math.max(this.visual, this.cur) : this.cur;
      const lines = this.rows.slice(from, to + 1).map((r, k) => ({ r, i: from + k })).filter((x) => x.r.kind === "line");
      if (!lines.length) { this.say("Move onto a line of code to comment on it, or press C for a general comment."); return; }
      if (new Set(lines.map((x) => x.r.file)).size > 1) { this.say("A selection can't span files.", true); return; }
      const first = lines[0].r, last = lines[lines.length - 1].r;
      const f = this.detail.files[last.file];
      const at = (r) => (r.sign === "-" ? `−${r.old}` : `${r.new}`);
      const range = lines.length > 1
        ? { start: { oc: first.oc, nc: first.nc, type: first.sign === "+" ? "new" : "old", old: first.sign === "+" ? null : first.old, new: first.sign === "-" ? null : first.new },
            end: { oc: last.oc, nc: last.nc, type: last.sign === "+" ? "new" : "old", old: last.sign === "+" ? null : last.old, new: last.sign === "-" ? null : last.new } }
        : null;
      this.editing = { kind: "line", args: this.lineArgs(last), range, label: `Comment on ${f.new_path.split("/").pop()}:${lines.length > 1 ? `${at(first)}–${at(last)}` : at(last)}` };
    }
    this.editor.set_value("");
    this.editor.focus();
    cx.notify();
  }

  startReply(cx) {
    const th = this.threadHere();
    if (!th) { this.say("Move onto a thread to reply to it."); return; }
    this.editing = { kind: "reply", thread: th.id, label: `Reply to ${th.notes[0]?.author ?? "thread"}` };
    this.editor.set_value("");
    this.editor.focus();
    cx.notify();
  }

  cancel(cx) {
    this.editing = null;
    this.handle.focus();
    cx.notify();
  }

  save(cx) {
    const e = this.editing;
    const body = this.editor.value().trim();
    if (!e) return;
    if (!body) { this.cancel(cx); return; }
    const iid = String(this.detail.mr.iid);
    const args = e.kind === "reply" ? ["reply", this.folder, iid, e.thread, body]
      : e.kind === "general" ? ["comment", this.folder, iid, body]
      : ["comment", this.folder, iid, body, ...e.args, ...(e.range ? [JSON.stringify(e.range)] : [])];
    this.editing = null;
    this.visual = null;
    this.handle.focus();
    this.act(cx, "Saving draft…", args, "Draft saved. S publishes your drafts.");
  }

  resolve(cx) {
    const th = this.threadHere();
    if (!th) { this.say("Move onto a thread to resolve it."); return; }
    if (!th.resolvable) { this.say("That thread can't be resolved.", true); return; }
    this.act(cx, th.resolved ? "Reopening…" : "Resolving…", ["resolve", this.folder, String(this.detail.mr.iid), th.id, th.resolved ? "false" : "true"], th.resolved ? "Thread reopened." : "Thread resolved.");
  }

  dropDraft(cx) {
    const r = this.row();
    if (!r?.draft) { this.say("Move onto one of your drafts to drop it."); return; }
    this.act(cx, "Dropping draft…", ["undraft", this.folder, String(this.detail.mr.iid), String(r.draft)], "Draft dropped.");
  }

  approve(cx) {
    const mr = this.detail?.mr;
    if (!mr) return;
    if (mr.approved_by_me) { this.act(cx, "Revoking…", ["unapprove", this.folder, String(mr.iid)], "Approval revoked."); return; }
    if (!mr.can_approve) { this.say(mr.author === this.detail.me ? "You can't approve your own merge request." : "GitLab doesn't let you approve this one.", true); return; }
    this.act(cx, "Approving…", ["approve", this.folder, String(mr.iid)], "Approved.");
  }

  submit(cx) {
    const n = this.detail?.drafts?.length ?? 0;
    if (!n) { this.say("No drafts to publish."); return; }
    if (this.confirm?.what !== "submit" || Date.now() - this.confirm.at > CONFIRM_MS) {
      this.confirm = { what: "submit", at: Date.now() };
      this.say(`Press S again to publish ${n} draft${n === 1 ? "" : "s"}. Everyone on the merge request will see ${n === 1 ? "it" : "them"}.`);
      return;
    }
    this.confirm = null;
    this.act(cx, "Publishing…", ["submit", this.folder, String(this.detail.mr.iid)], `Published ${n} comment${n === 1 ? "" : "s"}.`);
  }

  tuicr() {
    const mr = this.detail?.mr;
    if (!mr) return;
    run("tab.new", { name: `!${mr.iid} review`, space: this.space || undefined, folder: this.folder, argv: ["tuicr", "pr", mr.url] });
  }

  key(e, cx) {
    if (this.editing) {
      if (e.key === "escape") { this.cancel(cx); cx.stop_propagation(); }
      else if (e.key === "enter" && (e.modifiers.platform || e.modifiers.control)) { this.save(cx); cx.stop_propagation(); }
      return;
    }
    const m = e.modifiers;
    if (m.platform || m.alt) return;
    const named = e.key.length > 1 && e.key !== "space";
    const k = m.control ? `ctrl-${e.key}` : e.key === "tab" ? (m.shift ? "shift-tab" : "tab") : named ? e.key : (e.key_char ?? e.key);
    const prefix = this.prefix;
    this.prefix = null;
    let handled = true;
    const mrs = this.ordered();
    const step = (dir) => {
      if (!mrs.length) return;
      const at = mrs.findIndex((x) => x.iid === this.iid);
      const next = mrs[((at < 0 ? 0 : at + dir) + mrs.length) % mrs.length];
      this.pick = mrs.indexOf(next);
      this.open(cx, next.iid);
    };
    if (prefix === "]" || prefix === "[") {
      const dir = prefix === "]" ? 1 : -1;
      if (k === "f") this.seek(dir, (r) => r.kind === "file");
      else if (k === "c") this.seek(dir, (r, i) => this.isChange(r, i));
      else if (k === "t") this.seek(dir, (r) => (r.kind === "note" || r.kind === "draft") && r.head);
      else handled = false;
    } else if (prefix === "g" && k === "g") {
      if (this.side === "list") this.pick = 0; else this.go(0);
    } else if (k === "]" || k === "[" || k === "g") {
      this.prefix = k;
    } else if (k === "tab") step(1);
    else if (k === "shift-tab") step(-1);
    else if (k === "R") { this.loadList(cx); this.loadDetail(cx, true); this.say("Refreshing…"); }
    else if (k === "o") { const url = this.side === "list" ? mrs[this.pick]?.url : this.detail?.mr.url; if (url) exec("open", [url]).catch(() => {}); }
    else if (k === "t") this.tuicr();
    else if (k === "h") this.side = "list";
    else if (k === "escape") { this.visual = null; this.confirm = null; this.flash = null; }
    else if (this.side === "list") {
      if (k === "n" || k === "down") this.pick = Math.min(mrs.length - 1, this.pick + 1);
      else if (k === "e" || k === "up") this.pick = Math.max(0, this.pick - 1);
      else if (k === "G") this.pick = Math.max(0, mrs.length - 1);
      else if (k === "i" || k === "enter" || k === "right") { if (mrs[this.pick]) this.open(cx, mrs[this.pick].iid); this.side = "diff"; }
      else handled = false;
    } else if (k === "n" || k === "down") this.go(this.cur + 1);
    else if (k === "e" || k === "up") this.go(this.cur - 1);
    else if (k === "ctrl-d") this.go(this.cur + this.page());
    else if (k === "ctrl-u") this.go(this.cur - this.page());
    else if (k === "G") this.go(this.rows.length - 1);
    else if (k === "v" || k === "V") this.visual = this.visual == null ? this.cur : null;
    else if (k === "c") this.startComment(cx);
    else if (k === "C") this.startComment(cx, true);
    else if (k === "r") this.startReply(cx);
    else if (k === "x") this.resolve(cx);
    else if (k === "D") this.dropDraft(cx);
    else if (k === "a") this.approve(cx);
    else if (k === "S") this.submit(cx);
    else if (k === "y") {
      const a = this.anchor();
      if (a?.path) { cx.write_to_clipboard(`${a.path}:${a.new ?? a.old ?? 1}`); this.say(`Copied ${a.path}:${a.new ?? a.old ?? 1}`); }
    } else handled = false;
    if (handled || this.prefix) { cx.stop_propagation(); cx.notify(); }
  }

  mrRow(m, i, t) {
    const pipe = pipelineMark(t, m.pipeline);
    const current = m.iid === this.iid;
    const picked = this.side === "list" && i === this.pick;
    const approval = m.approved ? { text: "approved", color: t.done } : m.approvals_left ? { text: `${m.approvals_left} to approve`, color: t.dim } : null;
    return v_flex().id(`mr-${m.iid}`).px(10).py(6).gap(2).rounded(7).cursor_pointer().flex_none()
      .when(current, (el) => el.bg(t.selected))
      .when(picked, (el) => el.border_1().border_color(t.accent))
      .hover((s) => s.bg(t.hover))
      .on_click((_e, cx) => { this.pick = i; this.open(cx, m.iid); this.side = "diff"; this.handle.focus(); cx.notify(); })
      .child(h_flex().gap(6).items_center().min_w(0)
        .child(div().flex_none().text_size(11).text_color(t.dim).child(`!${m.iid}`))
        .when(m.draft, (el) => el.child(div().flex_none().px(4).rounded(3).border_1().border_color(t.border).text_size(10).text_color(t.dim).child("Draft")))
        .child(div().flex_1().min_w(0).truncate().text_size(12).child(m.title)))
      .child(h_flex().gap(8).items_center().text_size(11).text_color(t.dim).min_w(0)
        .child(div().truncate().min_w(0).child(m.author))
        .when(Boolean(pipe), (el) => el.child(div().flex_none().text_color(pipe.color).child(pipe.text)))
        .when(Boolean(approval), (el) => el.child(div().flex_none().text_color(approval.color).child(approval.text)))
        .when(m.unresolved > 0, (el) => el.child(div().flex_none().text_color(t.working).child(`${m.unresolved} open`)))
        .child(div().flex_none().text_color(t.ansi2).child(`+${m.add ?? 0}`))
        .child(div().flex_none().text_color(t.ansi1).child(`−${m.del ?? 0}`))
        .child(div().flex_1())
        .child(div().flex_none().child(age(m.updated))));
  }

  listPane(t) {
    const mrs = this.ordered();
    let i = 0;
    const blocks = GROUPS.map((g) => {
      const items = (this.list?.mrs ?? []).filter(g.test);
      if (!items.length) return null;
      return v_flex().gap(2).flex_none()
        .child(div().px(10).pt(10).pb(4).text_size(11).text_color(t.muted).child(`${g.label} · ${items.length}`))
        .children(items.map((m) => this.mrRow(m, i++, t)));
    }).filter(Boolean);
    const empty = this.listError ? this.listError
      : !this.list ? (this.folder ? "Loading merge requests…" : "No folder for this tab.")
      : this.list.unsupported ? "Only GitLab repositories for now."
      : !mrs.length ? "No open merge requests." : null;
    return v_flex().w(320).flex_none().h_full().min_h(0).border_r(1).border_color(t.border)
      .child(h_flex().h(36).flex_none().px(12).gap(8).items_center().border_b(1).border_color(t.border)
        .child(div().font_semibold().text_size(13).child("Merge requests"))
        .child(div().flex_1())
        .when(this.loadingList, (el) => el.child(div().text_size(11).text_color(t.dim).child("…")))
        .when(this.listAt > 0, (el) => el.child(div().text_size(11).text_color(t.dim).child(age(new Date(this.listAt).toISOString())))))
      .child(div().flex_1().min_h(0).relative()
        .child(v_flex().id("mrs-list").absolute().inset_0().overflow_y_scroll().px(6).pb(8).children(blocks)
          .when(Boolean(empty), (el) => el.child(div().p(12).text_size(12).text_color(this.listError ? t.blocked : t.dim).child(empty))))
        .child(Scrollbar.vertical("mrs-list").absolute().inset_0()));
  }

  header(t) {
    const d = this.detail;
    if (!d) return null;
    const mr = d.mr;
    const pipe = pipelineMark(t, mr.pipeline);
    const drafts = d.drafts?.length ?? 0;
    const open = (d.threads ?? []).filter((x) => x.resolvable && !x.resolved).length;
    const chip = (text, color) => div().flex_none().px(6).py(1).rounded(4).border_1().border_color(t.border).text_size(11).text_color(color ?? t.dim).child(text);
    return v_flex().flex_none().px(14).py(8).gap(4).border_b(1).border_color(t.border)
      .child(h_flex().gap(8).items_center().min_w(0)
        .child(div().flex_none().text_color(t.dim).child(`!${mr.iid}`))
        .child(div().flex_1().min_w(0).truncate().font_semibold().child(mr.title)))
      .child(h_flex().gap(6).items_center().min_w(0).text_size(11).text_color(t.dim)
        .child(div().flex_none().child(mr.author_name || mr.author))
        .child(div().min_w(0).truncate().child(`${mr.source} → ${mr.target}`))
        .child(div().flex_1())
        .when(Boolean(pipe), (el) => el.child(chip(`${pipe.text} ${pipe.label.replace(/^pipeline /, "")}`, pipe.color)))
        .child(mr.approved_by_me ? chip("you approved", t.done)
          : mr.approved ? chip(`approved${mr.approved_by.length ? ` by ${mr.approved_by.join(", ")}` : ""}`, t.done)
          : chip(mr.approvals_left ? `${mr.approvals_left} approval${mr.approvals_left === 1 ? "" : "s"} to go` : "not approved"))
        .when(open > 0, (el) => el.child(chip(`${open} open thread${open === 1 ? "" : "s"}`, t.working)))
        .when(drafts > 0, (el) => el.child(chip(`${drafts} draft${drafts === 1 ? "" : "s"} · S publishes`, t.accent))));
  }

  diffRow(r, i, t, size) {
    const h = rowHeight(size);
    const cw = charWidth(size);
    const numW = Math.ceil(5 * cw);
    const at = i === this.cur && this.side === "diff";
    const lo = this.visual != null ? Math.min(this.visual, this.cur) : -1, hi = this.visual != null ? Math.max(this.visual, this.cur) : -1;
    const selected = i >= lo && i <= hi;
    const base = h_flex().id(`d-${i}`).w_full().h(h).flex_none().items_center().border_l(2).border_color(at ? t.accent : "#00000000")
      .when(selected, (el) => el.bg(t.accent + "26"));
    if (r.kind === "file") {
      const color = r.status === "A" ? t.ansi2 : r.status === "D" ? t.ansi1 : t.working;
      return base.bg(selected ? t.accent + "26" : t.raised).px(10).gap(8)
        .child(div().w(12).flex_none().text_color(color).child(r.status))
        .child(div().min_w(0).truncate().font_semibold().child(r.from ? `${r.from} → ${r.path}` : r.path))
        .child(div().flex_none().text_color(t.ansi2).child(`+${r.add}`))
        .child(div().flex_none().text_color(t.ansi1).child(`−${r.del}`));
    }
    if (r.kind === "hunk") return base.px(10).text_color(t.dim).bg(t.raised + "80").child(div().truncate().child(r.text));
    if (r.kind === "title") return base.px(10).font_semibold().text_color(t.muted).child(r.text);
    if (r.kind === "text") return base.px(12).text_color(t.dim).child(div().truncate().child(r.text || " "));
    if (r.kind === "gap") return base;
    if (r.kind === "note" || r.kind === "draft") {
      const draft = r.kind === "draft";
      const indent = (r.reply ? 4 : 2) * cw + 2 * numW + 18;
      const tint = draft ? t.accent + "1f" : t.raised;
      const el = base.bg(selected ? t.accent + "26" : tint).pl(indent).pr(12).gap(8);
      if (r.head) {
        if (draft) return el.child(div().text_color(t.accent).font_semibold().child(r.reply ? "↳ your draft reply" : "your draft")).child(div().text_color(t.dim).child("· not published yet · D drops it"));
        return el.child(div().text_color(r.reply ? t.foreground : t.foreground).font_semibold().child(`${r.reply ? "↳ " : ""}${r.author}`))
          .child(div().text_color(t.dim).child(age(r.when)))
          .when(r.status === "open", (x) => x.child(div().text_color(t.working).child("open")))
          .when(r.status === "resolved", (x) => x.child(div().text_color(t.done).child("resolved")));
      }
      return el.child(div().truncate().text_color(r.resolved ? t.dim : t.foreground).child(r.text || " "));
    }
    const tint = r.sign === "+" ? t.ansi2 + "1c" : r.sign === "-" ? t.ansi1 + "1c" : null;
    return base.when(Boolean(tint) && !selected, (el) => el.bg(tint)).gap(0)
      .child(div().w(numW).flex_none().text_right().text_color(t.dim).child(r.old == null ? "" : String(r.old)))
      .child(div().w(numW).flex_none().text_right().text_color(t.dim).child(r.new == null ? "" : String(r.new)))
      .child(div().w(Math.ceil(2.5 * cw)).flex_none().text_right().text_color(r.sign === "+" ? t.ansi2 : r.sign === "-" ? t.ansi1 : t.dim).child(r.sign === " " ? "" : r.sign))
      .child(div().pl(8).flex_1().min_w(0).whitespace_nowrap().child(r.text));
  }

  diffPane(t) {
    const size = settings().font_size;
    const d = this.detail;
    const flash = this.busy ? { text: this.busy, error: false } : this.flash;
    const message = this.detailError ?? (!d ? (this.loadingDetail ? "Loading the merge request…" : this.iid == null ? "Pick a merge request." : "") : null);
    return v_flex().flex_1().min_w(0).h_full().min_h(0)
      .child(this.header(t) ?? div())
      .child(div().id("mrs-diff-box").flex_1().min_h(0).relative().font_family(settings().font_family ?? "JetBrains Mono").text_size(size)
        .on_size_change((s, cx) => {
          const zoom = settings().zoom || 1;
          const height = Math.floor(s.height / zoom);
          const cols = Math.floor((s.width / zoom - 2 * Math.ceil(5 * charWidth(size)) - 60) / charWidth(size));
          const grown = height !== this.height;
          this.height = height;
          if (Math.abs(cols - this.cols) >= 4) {
            const a = this.anchor();
            this.cols = cols;
            if (this.detail) { this.build(); this.restore(a); }
            cx.notify();
          } else if (grown) cx.notify();
        })
        .when(Boolean(message), (el) => el.child(div().p(14).text_size(12).text_color(this.detailError ? t.blocked : t.dim).child(message)))
        .when(Boolean(d), (el) => el
          .child(div().id("mrs-diff-x").w_full().h(this.height || 0).overflow_x_scrollbar()
            .child(div().w_full().min_w(Math.max(300, (this.longest + 4) * charWidth(size) + 2 * Math.ceil(5 * charWidth(size)) + 40)).h(this.height || 0)
              .child(v_virtual_list("mrs-diff", this.rows.length, rowHeight(size), (i) => String(i),
                (range) => this.rows.slice(range.start, range.end).map((r, k) => this.diffRow(r, range.start + k, t, size))).track_scroll(this.scroll).w_full().h(this.height || 0)
                .on_item_click((key, cx) => { this.side = "diff"; this.go(Number(key)); this.handle.focus(); cx.notify(); }))))
          .child(Scrollbar.vertical("mrs-diff").viewport_from_layout().absolute().inset_0())))
      .when(Boolean(this.editing), (el) => el.child(v_flex().flex_none().p(10).gap(6).border_t(1).border_color(t.border).bg(t.raised)
        .child(h_flex().gap(8).text_size(11)
          .child(div().text_color(t.foreground).font_semibold().child(this.editing?.label ?? ""))
          .child(div().flex_1())
          .child(div().text_color(t.dim).child("⌘↵ saves a draft · esc cancels")))
        .child(div().rounded(7).border_1().border_color(t.accent).bg(t.background).p(6)
          .child(Textarea.new(this.editor).w_full().text_size(12).text_color(t.foreground)))))
      .child(h_flex().flex_none().h(26).px(12).gap(10).items_center().border_t(1).border_color(t.border).text_size(11)
        .child(div().flex_1().min_w(0).truncate().text_color(flash?.error ? t.blocked : flash ? t.foreground : t.dim)
          .child(flash?.text ?? (this.visual != null ? "Selecting: c comments on the selection, v or esc stops" : this.prefix ? `${this.prefix}…  f file · c change · t thread` : HINTS))));
  }

  render(_cx) {
    const t = theme();
    return h_flex().id("mrs").size_full().min_h(0).overflow_hidden().bg(t.background).text_color(t.foreground).text_size(13)
      .track_focus(this.handle)
      .on_key_down((e, cx) => this.key(e, cx))
      .on_mouse_down("left", (_e, cx) => { if (!this.editing) this.handle.focus(); if (Date.now() - this.listAt > STALE_MS) this.loadList(cx, true); })
      .child(this.listPane(t))
      .child(this.diffPane(t));
  }
}
