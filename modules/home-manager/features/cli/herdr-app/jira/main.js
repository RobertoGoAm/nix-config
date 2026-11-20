import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex, InputState, Input } from "gpui-base";
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

const BLOCKED = /block|bloque|imped|on hold|en espera/i;
const isBlocked = (issue) => Boolean(issue.flagged) || BLOCKED.test(String(issue.status ?? ""));

const age = (created) => {
  const t = Date.parse(created ?? "");
  if (!Number.isFinite(t)) return null;
  const d = Math.floor((Date.now() - t) / 86400000);
  if (d < 1) return "today";
  if (d < 60) return `${d}d`;
  if (d < 730) return `${Math.floor(d / 30)}mo`;
  return `${Math.floor(d / 365)}y`;
};

const estimateText = (e) => {
  if (!e || (!e.original && !e.remaining)) return null;
  return `${e.remaining ?? "–"} / ${e.original ?? "–"}`;
};

const overrun = (e) => Boolean(e && e.originalS && e.spentS && e.spentS > e.originalS);

const prioColor = (t, p) => {
  const s = String(p ?? "").toLowerCase();
  if (/highest|blocker|critical|urgente|crítica/.test(s)) return t.blocked;
  if (/high|alta/.test(s)) return t.working;
  return t.dim;
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
    this.open = new Set();
    let saved = {};
    try { saved = JSON.parse(localStorage.getItem("view") ?? "{}"); } catch { saved = {}; }
    this.fixed = VIEWS.some((v) => v.id === props()?.view) ? props().view : null;
    this.view = this.fixed ?? (VIEWS.some((v) => v.id === saved.view) ? saved.view : "board");
    this.mineOnly = saved.mineOnly === true;
    this.lanesShut = new Set(Array.isArray(saved.lanesShut) ? saved.lanesShut : []);
    this.sx = 0;
    this.sy = 0;
    this.max = { x: 0, y: 0 };
    this.vp = null;
    this.laneH = {};
    this.query = "";
    if (!props()?.menu) {
      this.input = InputState.new({ placeholder: "Filter: key, title, person, status…" });
      this.input.on("change", (_e, cx) => {
        this.query = this.input.value().trim().toLowerCase();
        this.sy = 0;
        cx.notify();
      });
    }
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
      this.poll(cx, true);
    });
  }

  save() {
    try { localStorage.setItem("view", JSON.stringify({ view: this.fixed ? undefined : this.view, mineOnly: this.mineOnly, lanesShut: [...this.lanesShut] })); } catch {}
  }

  place() {
    const p = props() ?? {};
    const pane = p.pane ? panes().find((x) => x.pane === p.pane) : null;
    const space = (pane && spaces().find((s) => s.tabs.some((t) => t.id === pane.tab))) || (p.space && spaces().find((s) => s.id === p.space)) || null;
    const repo = space ? (shared("space.repos") ?? {})[space.id] : null;
    return { space, folder: p.folder ?? repo?.path ?? space?.folder ?? "", branch: space?.branch ?? "" };
  }

  poll(cx, fresh = false) {
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
        const r = await exec("jira-board", [...(fresh ? ["--fresh"] : []), "view", folder, branch], { timeout: 60000 });
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
        const r = await exec("jira-board", ["--site", props().site, "transitions", issue.key], { timeout: 30000 });
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
      try { await exec("jira-board", ["--site", props().site, ...args], { timeout: 30000 }); } catch {}
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
    openOverlay({ mod: SELF, kind: "popup", width: 280, height: 360, props: { menu: issue, site: this.data?.site, space: space?.id ?? null, folder } });
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
    const blocked = isBlocked(issue);
    const catColor = issue.category === "done" ? t.done : issue.category === "indeterminate" ? t.working : t.dim;
    const est = estimateText(issue.estimate);
    const old = age(issue.created);
    const subs = issue.subtasks ?? [];
    const subsDone = subs.filter((x) => x.category === "done").length;
    const unfolded = this.open.has(issue.key);
    return v_flex().id(`card-${issue.key}`).flex_none().p(8).gap(4).rounded(7).border_1()
      .border_color(blocked ? t.blocked : issue.mine ? t.accent : t.border)
      .when(blocked, (el) => el.border_l(3))
      .bg(t.background).cursor_pointer().hover((s) => s.bg(t.hover))
      .tooltip(`${issue.type}${issue.parent ? ` · in ${issue.parent}` : ""}${issue.created ? ` · created ${String(issue.created).slice(0, 10)}` : ""}${issue.estimate?.spent ? ` · ${issue.estimate.spent} logged` : ""}. Click: open, move, assign or start Claude`)
      .on_click(() => this.openMenu(issue))
      .child(h_flex().gap(6).items_center().text_size(11)
        .child(div().flex_none().text_color(catColor).child(typeMark(issue.type)))
        .child(div().flex_none().text_color(issue.mine ? t.accent : t.muted).child(issue.key))
        .child(div().flex_1())
        .when(Boolean(issue.priority), (el) => el.child(div().flex_none().text_color(prioColor(t, issue.priority))
          .child(`${prio ? `${prio} ` : ""}${issue.priority}`))))
      .when(blocked, (el) => el.child(div().text_size(10.5).font_medium().text_color(t.blocked)
        .child(issue.flagged ? "⚑ Blocked (flagged)" : `⚑ ${issue.status}`)))
      .child(div().text_size(12.5).text_color(issue.category === "done" ? t.muted : t.foreground).child(issue.summary))
      .child(h_flex().gap(8).items_center().text_size(10.5).text_color(t.dim)
        .child(div().flex_1().min_w(0).truncate().child(issue.assignee ?? "unassigned"))
        .child(div().flex_none().id(`est-${issue.key}`)
          .text_color(overrun(issue.estimate) ? t.blocked : est ? t.muted : t.dim)
          .tooltip(est ? `Remaining / original estimate${issue.estimate?.spent ? `; ${issue.estimate.spent} logged` : ""}` : "Not estimated")
          .child(`⏱ ${est ?? "–"}`))
        .when(Boolean(old), (el) => el.child(div().flex_none().id(`age-${issue.key}`).tooltip("Age, since it was created").child(old))))
      .when(subs.length > 0, (el) => el
        .child(h_flex().id(`subs-${issue.key}`).gap(5).items_center().text_size(10.5).text_color(t.muted).rounded(4)
          .hover((s) => s.text_color(t.foreground))
          .on_click((_e, cx) => {
            cx.stop_propagation();
            unfolded ? this.open.delete(issue.key) : this.open.add(issue.key);
            cx.notify();
          })
          .child(unfolded ? "▾" : "▸")
          .child(`${subs.length} subtask${subs.length === 1 ? "" : "s"} · ${subsDone} done`))
        .when(unfolded, (el) => el.child(v_flex().gap(1).pl(10).border_l(1).border_color(t.border)
          .children(subs.map((x) => h_flex().id(`sub-${x.key}`).gap(6).h(20).px(4).items_center().rounded(4).text_size(11)
            .hover((s) => s.bg(t.selected))
            .on_click((_e, cx) => {
              cx.stop_propagation();
              this.openMenu({ ...x, mine: false, parent: issue.key });
            })
            .child(div().size(6).flex_none().rounded_full().bg(x.category === "done" ? t.done : x.category === "indeterminate" ? t.working : t.dim))
            .child(div().flex_none().text_color(t.muted).child(x.key))
            .child(div().flex_1().min_w(0).truncate().text_color(x.category === "done" ? t.dim : t.foreground).child(x.summary))
            .child(div().flex_none().max_w(90).truncate().text_size(10).text_color(t.dim).child(x.status)))))));
  }

  shown(list) {
    const words = this.query ? this.query.split(/\s+/) : [];
    const text = (i) => [i.key, i.summary, i.assignee, i.status, i.priority, i.type, i.parent,
      ...(i.subtasks ?? []).flatMap((x) => [x.key, x.summary])].filter(Boolean).join(" ").toLowerCase();
    return list.filter((i) => !i.subtask && (!this.mineOnly || i.mine) && (!words.length || words.every((w) => text(i).includes(w))));
  }

  lanes(issues) {
    const sw = this.data.swimlanes ?? {};
    if (sw.strategy === "custom" && (sw.lanes ?? []).length) {
      const lanes = sw.lanes.map((l) => ({ name: l.name, keys: l.keys ? new Set(l.keys) : null, cards: [] }));
      const rest = lanes.find((l) => !l.keys) ?? (lanes.push({ name: "Everything else", keys: null, cards: [] }), lanes.at(-1));
      for (const i of issues) (lanes.find((l) => l.keys && l.keys.has(i.key)) ?? rest).cards.push(i);
      return lanes;
    }
    if (sw.strategy === "assignee") {
      const by = new Map();
      for (const i of issues) {
        const name = i.assignee ?? "Unassigned";
        if (!by.has(name)) by.set(name, { name, mine: i.mine, cards: [] });
        by.get(name).cards.push(i);
      }
      return [...by.values()].sort((a, b) => (b.mine - a.mine) || (a.name === "Unassigned") - (b.name === "Unassigned") || a.name.localeCompare(b.name));
    }
    return [{ name: null, cards: issues }];
  }

  scrollBy(dx, dy, cx) {
    const x = Math.max(0, Math.min(this.max.x, this.sx - dx));
    const y = Math.max(0, Math.min(this.max.y, this.sy - dy));
    if (x === this.sx && y === this.sy) return;
    this.sx = x;
    this.sy = y;
    cx.notify();
  }

  laneHeader(t, l, n, width, pinned) {
    const shut = this.lanesShut.has(l.name);
    const blocked = l.cards.filter(isBlocked).length;
    return h_flex().id(`${pinned ? "pin" : "lane"}-${n}`).w(width).h(26).px(8).gap(8).items_center().rounded(6).cursor_pointer()
      .bg(t.background).border_b(1).border_color(t.border).hover((s) => s.bg(t.hover))
      .on_click((_e, cx) => {
        shut ? this.lanesShut.delete(l.name) : this.lanesShut.add(l.name);
        this.save();
        cx.notify();
      })
      .child(div().flex_none().text_size(11).text_color(t.dim).child(shut ? "▸" : "▾"))
      .child(div().flex_none().text_size(12).font_semibold().text_color(t.foreground).child(l.name))
      .child(div().flex_none().text_size(11).text_color(t.dim).child(String(l.cards.length)))
      .when(blocked > 0, (el) => el.child(div().flex_none().text_size(11).text_color(t.blocked).child(`⚑ ${blocked}`)));
  }

  boardView(t) {
    const d = this.data;
    if (d.board?.type === "scrum" && !d.sprint) {
      return div().p(16).text_size(12.5).text_color(t.dim).child("No sprint is active. The backlog is one click away.");
    }
    const issues = this.shown(d.issues ?? []);
    const columns = (d.columns ?? []).map((c) => ({ name: c.name, ids: new Set(c.statuses.map(String)) }));
    const placed = (i) => columns.findIndex((c) => c.ids.has(String(i.statusId)));
    if (issues.some((i) => placed(i) < 0)) columns.push({ name: "Not on the board", ids: new Set() });
    const colOf = (i) => {
      const n = placed(i);
      return n < 0 ? columns.length - 1 : n;
    };
    const W = 250;
    const GAP = 10;
    const PAD = 12;
    const HEAD = 40;
    const width = columns.length * W + (columns.length - 1) * GAP;
    const lanes = this.lanes(issues).filter((l) => l.cards.length);
    const named = lanes.some((l) => l.name != null);

    const tops = [];
    let y = 0;
    const laneW = Math.max(200, Math.min(width, (this.vp?.width ?? 900) - 2 * PAD));
    for (const l of lanes) {
      tops.push(y);
      y += (this.laneH[l.name ?? ""] ?? 120) + GAP;
    }
    const vp = this.vp ?? { width: 900, height: 600 };
    this.max = { x: Math.max(0, width + 2 * PAD - vp.width), y: Math.max(0, HEAD + y + PAD - vp.height) };
    this.sx = Math.min(this.sx, this.max.x);
    this.sy = Math.min(this.sy, this.max.y);
    let current = -1;
    tops.forEach((top, n) => { if (top <= this.sy) current = n; });

    const head = h_flex().absolute().top(0).left(PAD - this.sx).h(HEAD).pb(10).gap(GAP).items_end().bg(t.background)
      .children(columns.map((c, n) => {
        const here = issues.filter((i) => colOf(i) === n);
        const blocked = here.filter(isBlocked).length;
        return h_flex().w(W).flex_none().h(30).px(10).gap(6).items_center().rounded(8).bg(t.chrome).border_1().border_color(t.border)
          .child(div().flex_1().min_w(0).truncate().text_size(11.5).font_medium().text_color(BLOCKED.test(c.name) && here.length ? t.blocked : t.muted).child(c.name.toUpperCase()))
          .when(blocked > 0, (el) => el.child(div().flex_none().text_size(11).text_color(t.blocked).child(`⚑ ${blocked}`)))
          .child(div().flex_none().text_size(11).text_color(t.dim).child(String(here.length)));
      }));

    const body = v_flex().absolute().top(HEAD - this.sy).left(PAD - this.sx).w(width).gap(GAP)
      .children(lanes.map((l, n) => {
        const shut = l.name != null && this.lanesShut.has(l.name);
        const row = h_flex().gap(GAP).items_start().flex_none().children(columns.map((_c, k) => v_flex().w(W).flex_none().gap(6)
          .children(l.cards.filter((i) => colOf(i) === k).map((issue) => this.card(t, issue)))));
        return v_flex().id(`lane-box-${n}`).gap(6).flex_none()
          .on_size_change((size, cx) => {
            const key = l.name ?? "";
            if (Math.abs((this.laneH[key] ?? 0) - size.height) < 1) return;
            this.laneH[key] = size.height;
            cx.notify();
          })
          .when(l.name != null, (el) => el.child(div().ml(this.sx).child(this.laneHeader(t, l, n, laneW, false))))
          .when(!shut, (el) => el.child(row));
      }));

    const pin = named && current >= 0 && this.sy > tops[current] && lanes[current].name != null
      ? div().absolute().top(HEAD).left(PAD).child(this.laneHeader(t, lanes[current], current, laneW, true))
      : null;

    return div().id("jr-board").flex_1().min_h(0).relative().overflow_hidden()
      .on_size_change((size, cx) => {
        if (this.vp && this.vp.width === size.width && this.vp.height === size.height) return;
        this.vp = size;
        cx.notify();
      })
      .on_scroll_wheel((e, cx) => {
        const dx = e.delta?.x ?? 0;
        const dy = e.delta?.y ?? 0;
        if (e.modifiers?.shift && !dx) this.scrollBy(dy, 0, cx);
        else this.scrollBy(dx, dy, cx);
      })
      .when(!lanes.length, (el) => el.child(div().absolute().top(HEAD).left(PAD).text_size(12.5).text_color(t.dim)
        .child(this.query || this.mineOnly ? "Nothing matches." : "The board is empty.")))
      .child(body)
      .child(head)
      .when(Boolean(pin), (el) => el.child(pin));
  }

  backlogView(t) {
    const list = this.shown(this.data.backlog ?? []);
    const label = (w, text) => div().w(w).flex_none().truncate().child(text);
    const head = h_flex().h(28).px(20).gap(8).flex_none().items_center().text_size(10.5).font_medium().text_color(t.dim)
      .border_b(1).border_color(t.border)
      .child(div().w(12).flex_none())
      .child(label(90, "KEY"))
      .child(div().flex_1().child("SUMMARY"))
      .child(label(50, "SUBS"))
      .child(label(70, "PRIORITY"))
      .child(label(90, "LEFT / EST."))
      .child(label(40, "AGE"))
      .child(label(110, "STATUS"))
      .child(label(130, "ASSIGNEE"));
    const rows = list.map((issue) => {
      const subs = issue.subtasks ?? [];
      return h_flex().id(`bl-${issue.key}`).h(30).px(8).gap(8).flex_none().items_center().rounded(6).cursor_pointer()
        .hover((s) => s.bg(t.hover)).on_click(() => this.openMenu(issue))
        .child(div().w(12).flex_none().text_size(11).text_color(isBlocked(issue) ? t.blocked : t.dim).child(isBlocked(issue) ? "⚑" : typeMark(issue.type)))
        .child(div().w(90).flex_none().text_size(11.5).text_color(isBlocked(issue) ? t.blocked : issue.mine ? t.accent : t.muted).child(issue.key))
        .child(div().flex_1().min_w(0).truncate().text_size(12.5).text_color(t.foreground).child(issue.summary))
        .child(div().w(50).flex_none().text_size(10.5).text_color(t.dim).child(subs.length ? `${subs.filter((x) => x.category === "done").length}/${subs.length}` : ""))
        .child(div().w(70).flex_none().truncate().text_size(11).text_color(prioColor(t, issue.priority)).child(issue.priority ?? ""))
        .child(div().w(90).flex_none().truncate().text_size(10.5).text_color(overrun(issue.estimate) ? t.blocked : t.dim).child(estimateText(issue.estimate) ?? "–"))
        .child(div().w(40).flex_none().text_size(10.5).text_color(t.dim).child(age(issue.created) ?? ""))
        .child(div().w(110).flex_none().truncate().text_size(11).text_color(t.dim).child(issue.status))
        .child(div().w(130).flex_none().truncate().text_size(11).text_color(t.dim).child(issue.assignee ?? "unassigned"));
    });
    return v_flex().flex_1().min_h(0)
      .child(head)
      .when(!list.length, (el) => el.child(div().p(16).text_size(12.5).text_color(t.dim)
        .child(this.query || this.mineOnly ? "Nothing matches." : "The backlog is empty.")))
      .child(v_flex().id("jr-backlog").flex_1().min_h(0).px(12).py(4).gap(2).overflow_y_scrollbar().children(rows));
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
      .child(h_flex().w(260).h(26).px(8).gap(6).flex_none().items_center().rounded(7).border_1().border_color(t.border).bg(t.chrome)
        .on_key_down((e, cx) => {
          if (e.key !== "escape") return;
          this.input.set_value("");
          this.query = "";
          cx.stop_propagation();
          cx.notify();
        })
        .child(svg("mods/workspace-chrome/search.svg").size(12).flex_none().text_color(t.dim))
        .child(Input.new(this.input).flex_1().h_full().text_size(12).text_color(t.foreground)))
      .when(Boolean(this.fixed), (el) => el.child(div().text_size(12).text_color(t.muted).child(VIEWS.find((v) => v.id === this.fixed).label)))
      .when(!this.fixed, (el) => el.children(VIEWS.map((v) => this.chip(t, `jr-v-${v.id}`, v.label, this.view === v.id, () => { this.view = v.id; }))))
      .child(this.chip(t, "jr-mine", "Mine", this.mineOnly, () => { this.mineOnly = !this.mineOnly; }))
      .child(div().id("jr-refresh").text_size(13).text_color(t.dim).cursor_pointer().hover((s) => s.text_color(t.foreground))
        .tooltip("Look again now").on_click((_e, cx) => this.poll(cx, true)).child(this.loading ? "…" : "↻"));
    return v_flex().size_full().min_h(0).bg(t.background).text_size(13)
      .child(header)
      .when(Boolean(this.error), (el) => el.child(div().px(16).pb(8).text_size(12).text_color(t.blocked).child(this.error)))
      .when(!d && !this.error, (el) => el.child(div().px(16).text_size(12).text_color(t.dim).child("Looking up the board…")))
      .when(Boolean(d) && this.view === "board", (el) => el.child(this.boardView(t)))
      .when(Boolean(d) && this.view === "backlog", (el) => el.child(this.backlogView(t)));
  }
}
