import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { spaces, panes, run, exec, theme, shared, setShared, checking, props, openOverlay, closeOverlay } from "herdr";

const SELF = "jira";
const POLL_MS = 120000;
const VIEWS = [
  { id: "board", label: "Board" },
  { id: "backlog", label: "Backlog" },
];

const daysLeft = (end) => {
  if (!end) return null;
  const d = Math.ceil((new Date(end).getTime() - Date.now()) / 86400000);
  return d < 0 ? "ended" : d === 0 ? "ends today" : `${d}d left`;
};

const typeMark = (type) => {
  const s = String(type ?? "").toLowerCase();
  if (s.includes("bug") || s.includes("error")) return "●";
  if (s.includes("epic")) return "◆";
  if (s.includes("story") || s.includes("historia")) return "▲";
  if (s.includes("sub")) return "↳";
  return "■";
};

const prioMark = (p) => {
  const s = String(p ?? "").toLowerCase();
  if (/highest|blocker|critical|urgente|crítica/.test(s)) return "⇈";
  if (/high|alta/.test(s)) return "↑";
  if (/lowest|minor/.test(s)) return "⇊";
  if (/low|baja/.test(s)) return "↓";
  return "";
};

export default class Jira extends View {
  init(_props, cx) {
    this.data = null;
    this.error = null;
    this.loading = false;
    this.seen = shared("jira.changed") ?? 0;
    this.moves = null;
    this.busy = null;
    let saved = {};
    try { saved = JSON.parse(localStorage.getItem("view") ?? "{}"); } catch { saved = {}; }
    this.view = VIEWS.some((v) => v.id === saved.view) ? saved.view : "board";
    this.mineOnly = saved.mineOnly === true;
    if (checking()) return;
    if (props()?.menu) {
      cx.timer.after(10, (cx) => this.loadMoves(cx));
      return;
    }
    cx.timer.after(300, (cx) => this.poll(cx));
    cx.timer.every(POLL_MS, (cx) => this.poll(cx));
    cx.timer.every(1500, (cx) => {
      const changed = shared("jira.changed") ?? 0;
      if (changed === this.seen) return;
      this.seen = changed;
      this.poll(cx);
    });
  }

  save() {
    try { localStorage.setItem("view", JSON.stringify({ view: this.view, mineOnly: this.mineOnly })); } catch {}
  }

  place() {
    const p = props() ?? {};
    const pane = p.pane ? panes().find((x) => x.pane === p.pane) : null;
    const space = (pane && spaces().find((s) => s.tabs.some((t) => t.id === pane.tab))) || (p.space && spaces().find((s) => s.id === p.space)) || null;
    return { space, folder: p.folder ?? space?.folder ?? "", branch: space?.branch ?? "" };
  }

  poll(cx) {
    if (this.loading) return;
    const { folder, branch } = this.place();
    if (!folder) {
      this.error = "This tab is not in a space with a folder.";
      return cx.notify();
    }
    this.loading = true;
    cx.notify();
    cx.spawn(async (cx) => {
      try {
        const r = await exec("jira-board", ["view", folder, branch], { timeout: 60000 });
        const out = JSON.parse(r.stdout || "{}");
        if (out.error || r.code !== 0) this.error = out.error || (r.stderr || `exit ${r.code}`).trim().split("\n").pop();
        else {
          this.data = out;
          this.error = null;
        }
      } catch (e) {
        this.error = String(e?.message ?? e);
      }
      this.loading = false;
      cx.notify();
    });
  }

  loadMoves(cx) {
    const issue = props()?.menu;
    if (!issue) return;
    cx.spawn(async (cx) => {
      try {
        const r = await exec("jira-board", ["transitions", issue.key], { timeout: 30000 });
        this.moves = r.code === 0 ? JSON.parse(r.stdout || "[]") : [];
      } catch {
        this.moves = [];
      }
      cx.notify();
    });
  }

  act(cx, label, args) {
    this.busy = label;
    cx.notify();
    cx.spawn(async (cx) => {
      try { await exec("jira-board", args, { timeout: 30000 }); } catch {}
      setShared("jira.changed", Date.now());
      closeOverlay(props().overlay);
    });
  }

  startClaude(issue) {
    const p = props() ?? {};
    const prompt = `Work on Jira ticket ${issue.key}: ${issue.summary} (${issue.url}). Read the ticket and its context before changing anything.`;
    run("tab.new", { ...(p.space ? { space: p.space } : {}), name: issue.key, folder: p.folder || undefined, argv: ["claude"], task: prompt });
    closeOverlay(p.overlay);
  }

  openMenu(issue) {
    const { space, folder } = this.place();
    openOverlay({ mod: SELF, kind: "popup", width: 280, height: 360, props: { menu: issue, space: space?.id ?? null, folder } });
  }

  menuRow(t, id, label, act, opts = {}) {
    return h_flex().id(id).h(28).px(8).gap(8).rounded(6).items_center().cursor_pointer()
      .text_color(opts.dim ? t.muted : t.foreground)
      .hover((s) => s.bg(t.hover))
      .on_click((_e, cx) => act(cx))
      .when(Boolean(opts.mark), (el) => el.child(div().w(14).flex_none().text_color(opts.color ?? t.dim).child(opts.mark)))
      .child(div().flex_1().min_w(0).truncate().child(label));
  }

  menu(t) {
    const issue = props().menu;
    const rows = [
      this.menuRow(t, "m-open", "Open in the browser", () => {
        exec("/usr/bin/open", [issue.url]).catch(() => {});
        closeOverlay(props().overlay);
      }, { mark: "↗" }),
      this.menuRow(t, "m-claude", "Start Claude on it", () => this.startClaude(issue), { mark: "✦", color: t.accent }),
    ];
    if (!issue.mine) rows.push(this.menuRow(t, "m-assign", "Assign to me", (cx) => this.act(cx, "assign", ["assign", issue.key]), { mark: "@" }));
    const moves = this.moves;
    return v_flex().size_full().p(5).bg(t.popover).text_size(12.5)
      .child(div().px(8).pt(4).text_size(11).text_color(t.dim).child(issue.key))
      .child(div().px(8).pb(6).text_size(12).text_color(t.foreground).child(issue.summary))
      .children(rows)
      .child(div().mx(8).my(4).h(1).bg(t.border))
      .child(div().px(8).pb(2).text_size(11).text_color(t.dim).child(this.busy ? "Working…" : `Move from ${issue.status}`))
      .when(moves === null, (el) => el.child(div().px(8).text_size(12).text_color(t.dim).child("Loading…")))
      .when(Array.isArray(moves), (el) => el.child(v_flex().id("m-moves").flex_1().min_h(0).overflow_y_scrollbar()
        .children(moves.filter((m) => m.to !== issue.status).map((m) => this.menuRow(t, `m-mv-${m.id}`, m.name === m.to ? m.to : `${m.name} → ${m.to}`,
          (cx) => this.act(cx, "move", ["move", issue.key, m.id]),
          { mark: "→", color: m.category === "done" ? t.done : m.category === "indeterminate" ? t.working : t.dim })))));
  }

  card(t, issue) {
    const prio = prioMark(issue.priority);
    const catColor = issue.category === "done" ? t.done : issue.category === "indeterminate" ? t.working : t.dim;
    return v_flex().id(`card-${issue.key}`).flex_none().p(8).gap(4).rounded(7).border_1().border_color(issue.mine ? t.accent : t.border)
      .bg(t.background).cursor_pointer().hover((s) => s.bg(t.hover))
      .tooltip(`${issue.type}${issue.priority ? ` · ${issue.priority}` : ""}${issue.parent ? ` · in ${issue.parent}` : ""}. Click: open, move, assign or start Claude`)
      .on_click(() => this.openMenu(issue))
      .child(h_flex().gap(6).items_center().text_size(11)
        .child(div().flex_none().text_color(catColor).child(typeMark(issue.type)))
        .child(div().flex_none().text_color(issue.mine ? t.accent : t.muted).child(issue.key))
        .child(div().flex_1())
        .when(Boolean(prio), (el) => el.child(div().flex_none().text_color(prio.startsWith("⇈") || prio === "↑" ? t.blocked : t.dim).child(prio))))
      .child(div().text_size(12.5).text_color(issue.category === "done" ? t.muted : t.foreground).child(issue.summary))
      .when(Boolean(issue.assignee), (el) => el.child(div().text_size(10.5).text_color(t.dim).truncate().child(issue.assignee)));
  }

  shown(list) {
    return list.filter((i) => !i.subtask && (!this.mineOnly || i.mine));
  }

  boardView(t) {
    const d = this.data;
    const issues = this.shown(d.issues ?? []);
    const placed = new Set();
    const cols = (d.columns ?? []).map((c) => {
      const ids = new Set(c.statuses.map(String));
      const cards = issues.filter((i) => ids.has(String(i.statusId)));
      cards.forEach((i) => placed.add(i.key));
      return { name: c.name, cards };
    });
    const loose = issues.filter((i) => !placed.has(i.key));
    if (loose.length) cols.push({ name: "Not on the board", cards: loose });
    if (d.board?.type === "scrum" && !d.sprint) {
      return div().p(16).text_size(12.5).text_color(t.dim).child("No sprint is active. The backlog is one click away.");
    }
    return h_flex().id("jr-board").flex_1().min_h(0).gap(10).px(12).pb(10).items_start().overflow_x_scrollbar()
      .children(cols.map((c, i) => v_flex().id(`col-${i}`).w(250).flex_none().h_full().min_h(0).rounded(9).bg(t.chrome).border_1().border_color(t.border)
        .child(h_flex().px(10).h(32).flex_none().gap(6).items_center()
          .child(div().flex_1().min_w(0).truncate().text_size(11.5).font_medium().text_color(t.muted).child(c.name.toUpperCase()))
          .child(div().flex_none().text_size(11).text_color(t.dim).child(String(c.cards.length))))
        .child(v_flex().id(`col-list-${i}`).flex_1().min_h(0).gap(6).px(6).pb(6).overflow_y_scrollbar()
          .children(c.cards.map((issue) => this.card(t, issue))))));
  }

  backlogView(t) {
    const list = this.shown(this.data.backlog ?? []);
    if (!list.length) return div().p(16).text_size(12.5).text_color(t.dim).child(this.mineOnly ? "Nothing of yours in the backlog." : "The backlog is empty.");
    return v_flex().id("jr-backlog").flex_1().min_h(0).px(12).pb(10).gap(2).overflow_y_scrollbar()
      .children(list.map((issue) => {
        const prio = prioMark(issue.priority);
        return h_flex().id(`bl-${issue.key}`).h(30).px(8).gap(8).flex_none().items_center().rounded(6).cursor_pointer()
          .hover((s) => s.bg(t.hover)).on_click(() => this.openMenu(issue))
          .child(div().w(12).flex_none().text_size(11).text_color(t.dim).child(typeMark(issue.type)))
          .child(div().w(90).flex_none().text_size(11.5).text_color(issue.mine ? t.accent : t.muted).child(issue.key))
          .child(div().flex_1().min_w(0).truncate().text_size(12.5).text_color(t.foreground).child(issue.summary))
          .when(Boolean(prio), (el) => el.child(div().flex_none().text_size(11).text_color(t.dim).child(prio)))
          .child(div().w(110).flex_none().truncate().text_size(11).text_color(t.dim).child(issue.status))
          .child(div().w(130).flex_none().truncate().text_size(11).text_color(t.dim).child(issue.assignee ?? "unassigned"));
      }));
  }

  chip(t, id, label, on, act) {
    return div().id(id).px(9).h(22).flex().items_center().rounded(6).text_size(11.5).cursor_pointer()
      .when(on, (el) => el.bg(t.selected).text_color(t.foreground))
      .when(!on, (el) => el.text_color(t.dim).hover((s) => s.bg(t.hover).text_color(t.foreground)))
      .on_click((_e, cx) => { act(); this.save(); cx.notify(); })
      .child(label);
  }

  render() {
    const t = theme();
    if (props()?.menu) return this.menu(t);
    const d = this.data;
    const left = daysLeft(d?.sprint?.end);
    const header = h_flex().px(16).h(44).flex_none().gap(10).items_center()
      .child(div().text_size(13).font_semibold().text_color(t.foreground).child(d ? d.key : "Jira"))
      .when(Boolean(d?.board), (el) => el.child(div().id("jr-boardname").text_size(12).text_color(t.muted).cursor_pointer()
        .hover((s) => s.text_color(t.foreground)).tooltip("Open the board in the browser")
        .on_click(() => exec("/usr/bin/open", [d.board.url]).catch(() => {}))
        .child(d.board.name)))
      .when(Boolean(d?.sprint), (el) => el.child(div().text_size(12).text_color(t.dim)
        .child(`${d.sprint.name}${left ? ` · ${left}` : ""}`)))
      .child(div().flex_1())
      .children(VIEWS.map((v) => this.chip(t, `jr-v-${v.id}`, v.label, this.view === v.id, () => { this.view = v.id; })))
      .child(this.chip(t, "jr-mine", "Mine", this.mineOnly, () => { this.mineOnly = !this.mineOnly; }))
      .child(div().id("jr-refresh").text_size(13).text_color(t.dim).cursor_pointer().hover((s) => s.text_color(t.foreground))
        .tooltip("Look again now").on_click((_e, cx) => this.poll(cx)).child(this.loading ? "…" : "↻"));
    return v_flex().size_full().min_h(0).bg(t.background).text_size(13)
      .child(header)
      .when(Boolean(this.error), (el) => el.child(div().px(16).pb(8).text_size(12).text_color(t.blocked).child(this.error)))
      .when(!d && !this.error, (el) => el.child(div().px(16).text_size(12).text_color(t.dim).child("Looking up the board…")))
      .when(Boolean(d) && this.view === "board", (el) => el.child(this.boardView(t)))
      .when(Boolean(d) && this.view === "backlog", (el) => el.child(this.backlogView(t)));
  }
}
