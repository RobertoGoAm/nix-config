import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex, InputState, Input } from "gpui-base";
import { exec, hc, run, home, pickFolder, theme, props, closeOverlay, checking, shared, setShared } from "herdr";

const PROVIDERS = {
  claude: {
    label: "Claude",
    models: [
      { id: "default", label: "default" },
      { id: "opus", label: "Opus" },
      { id: "sonnet", label: "Sonnet" },
      { id: "haiku", label: "Haiku" },
      { id: "claude-fable-5-1", label: "Fable" },
    ],
    efforts: ["default", "low", "medium", "high", "xhigh", "max"],
    argv: (m, e) => ["claude", ...(m !== "default" ? ["--model", m] : []), ...(e !== "default" ? ["--effort", e] : [])],
  },
  codex: {
    label: "Codex",
    models: [
      { id: "default", label: "default" },
      { id: "gpt-6-astra", label: "gpt-6-astra" },
    ],
    efforts: ["default", "low", "medium", "high", "xhigh", "ultra"],
    argv: (m, e) => ["codex", ...(m !== "default" ? ["-m", m] : []), ...(e !== "default" ? ["-c", `model_reasoning_effort="${e}"`] : [])],
  },
  shell: { label: "Shell", models: [], efforts: [], argv: () => null },
};
const ORDER = ["claude", "codex", "shell"];
const MAX_RECENT = 12;
const COMPANIONS = [["notes", "Notes"], ["kanban", "Kanban"], ["backlog", "Backlog"]];
const PENDING_MS = 10 * 60000;

function fuzzy(q, text) {
  if (!q) return true;
  if (text.includes(q)) return true;
  let i = 0;
  for (const ch of text) if (ch === q[i] && ++i === q.length) return true;
  return false;
}

function load(key, fallback) {
  try {
    const v = JSON.parse(localStorage.getItem(key) ?? "null");
    return v ?? fallback;
  } catch {
    return fallback;
  }
}

export default class Launcher extends View {
  init(_props, cx) {
    const last = load("last", {});
    this.provider = PROVIDERS[last.provider] ? last.provider : "claude";
    this.model = { claude: "default", codex: "default", ...(last.model ?? {}) };
    this.effort = { claude: "default", codex: "default", ...(last.effort ?? {}) };
    this.machine = props()?.machine !== undefined ? (props().machine || null) : (last.machine ?? null);
    this.asTab = Boolean(last.asTab);
    this.extras = { editor: true, prs: false, notes: true, kanban: true, backlog: true, ...(last.extras ?? {}) };
    this.machines = [null];
    this.dirs = {};
    this.query = "";
    this.at = 0;
    this.input = InputState.new({ placeholder: "Search recent projects, or type a path…" });
    this.input.on("change", (_e, cx) => {
      this.query = this.input.value();
      this.at = 0;
      cx.notify();
    });
    this.input.on("submit", (_e, cx) => this.launch(this.pick()));
    this.input.focus();
    cx.timer.after(400, () => this.input.focus());
    if (checking()) return;
    cx.spawn(async (cx) => {
      try {
        const r = await hc(["machine", "ls", "--json"]);
        if (r.code === 0) this.machines = [null, ...(JSON.parse(r.stdout).machines ?? []).filter((m) => m.state === "connected" && !m.temporary).map((m) => m.name)];
      } catch {}
      cx.notify();
    });
    this.loadDirs(cx, this.machine);
  }

  loadDirs(cx, machine) {
    const key = machine ?? "";
    if (this.dirs[key] || checking()) return;
    this.dirs[key] = { home: machine ? null : home(), list: [] };
    cx.spawn(async (cx) => {
      const on = machine;
      const [z, h] = await Promise.all([
        exec("zoxide", ["query", "-l"], { on, timeout: 10000 }).catch(() => null),
        machine ? exec("sh", ["-c", "printf %s \"$HOME\""], { on }).catch(() => null) : null,
      ]);
      if (h?.code === 0) this.dirs[key].home = h.stdout.trim();
      this.dirs[key].list = z?.code === 0 ? z.stdout.split("\n").filter(Boolean) : [];
      cx.notify();
    });
  }

  recent() {
    return load(`recent:${this.machine ?? ""}`, []);
  }

  rows() {
    const d = this.dirs[this.machine ?? ""] ?? { list: [] };
    const seen = new Set();
    const all = [];
    for (const p of [...this.recent(), ...d.list]) if (p && !seen.has(p)) { seen.add(p); all.push(p); }
    const homeDir = d.home;
    const pretty = (p) => (homeDir && p.startsWith(homeDir) ? "~" + p.slice(homeDir.length) : p);
    const q = this.query.trim().toLowerCase();
    const rows = all
      .filter((p) => p !== homeDir)
      .filter((p) => fuzzy(q, pretty(p).toLowerCase()))
      .slice(0, 60)
      .map((p) => ({ path: p, name: p.split("/").filter(Boolean).pop() ?? p, shown: pretty(p), recent: this.recent().includes(p) }));
    const typed = this.query.trim();
    if (/^[~/]/.test(typed)) {
      const abs = typed.startsWith("~") && homeDir ? homeDir + typed.slice(1) : typed;
      if (!rows.some((r) => r.path === abs)) rows.unshift({ path: abs, name: abs.split("/").filter(Boolean).pop() ?? abs, shown: typed, typed: true });
    }
    return rows;
  }

  pick() {
    const rows = this.rows();
    return rows[Math.min(this.at, rows.length - 1)]?.path ?? null;
  }

  remember(folder) {
    localStorage.setItem("last", JSON.stringify({ provider: this.provider, model: this.model, effort: this.effort, machine: this.machine, asTab: this.asTab, extras: this.extras }));
    if (!folder) return;
    const key = `recent:${this.machine ?? ""}`;
    const list = [folder, ...this.recent().filter((p) => p !== folder)].slice(0, MAX_RECENT);
    localStorage.setItem(key, JSON.stringify(list));
  }

  launch(folder) {
    if (!folder) return;
    const p = PROVIDERS[this.provider];
    const argv = p.argv(this.model[this.provider] ?? "default", this.effort[this.provider] ?? "default");
    this.remember(folder);
    closeOverlay(props().overlay);
    const args = { folder, ...(argv ? { argv } : {}) };
    if (this.asTab) return run("tab.new", args);
    run("space.new", { ...args, machine: this.machine ?? "" });
    if (this.extras.editor) run("tab.new", { folder, argv: ["nvim", "."], focus: false });
    if (this.extras.prs) run("tab.new", { folder, name: "PRs", argv: ["tuicr-prs"], focus: false });
    if (this.machine == null) {
      const skip = COMPANIONS.filter(([key]) => !this.extras[key]).map(([, kind]) => kind);
      const pending = Object.fromEntries(Object.entries(shared("companions.pending") ?? {}).filter(([, v]) => Date.now() - v.at < PENDING_MS));
      setShared("companions.pending", { ...pending, [folder]: { skip, at: Date.now() } });
    }
  }

  async browse(cx) {
    const folder = await pickFolder({ prompt: "Open" });
    if (folder) this.launch(folder);
    else cx.notify();
  }

  cycle(kind, dir = 1) {
    if (kind === "provider") {
      const i = ORDER.indexOf(this.provider);
      this.provider = ORDER[(i + dir + ORDER.length) % ORDER.length];
      return;
    }
    const p = PROVIDERS[this.provider];
    const list = kind === "model" ? p.models.map((m) => m.id) : p.efforts;
    if (!list.length) return;
    const cur = (kind === "model" ? this.model : this.effort)[this.provider] ?? list[0];
    const next = list[(list.indexOf(cur) + dir + list.length) % list.length];
    (kind === "model" ? this.model : this.effort)[this.provider] = next;
  }

  toggleChip(t, id, label, key) {
    const on = Boolean(this.extras[key]);
    return div().id(id).px(8).h(24).rounded(6).flex().items_center().gap(5).cursor_pointer().text_size(12)
      .border_1().border_color(on ? t.accent : t.border).text_color(on ? t.foreground : t.muted)
      .when(on, (el) => el.bg(t.selected))
      .hover((s) => s.bg(t.hover).text_color(t.foreground))
      .on_click((_e, cx) => { this.extras[key] = !on; cx.notify(); })
      .child(on ? "✓" : "+")
      .child(label);
  }

  chips(t, id, items, on, set) {
    return h_flex().gap(4).flex_wrap().children(items.map(([value, label]) => div()
      .id(`${id}-${value ?? "here"}`)
      .px(8)
      .h(24)
      .rounded(6)
      .flex()
      .items_center()
      .cursor_pointer()
      .text_size(12)
      .border_1()
      .border_color(value === on ? t.accent : t.border)
      .text_color(value === on ? t.foreground : t.muted)
      .when(value === on, (el) => el.bg(t.selected))
      .hover((s) => s.bg(t.hover).text_color(t.foreground))
      .on_click((_e, cx) => { set(value, cx); cx.notify(); })
      .child(label)));
  }

  render(cx) {
    const t = theme();
    const p = PROVIDERS[this.provider];
    const rows = this.rows();
    this.at = Math.max(0, Math.min(this.at, rows.length - 1));
    const label = (text) => div().w(64).flex_none().text_size(11).text_color(t.dim).child(text);

    const options = v_flex().gap(8)
      .child(h_flex().gap(8).items_center().child(label("machine"))
        .child(this.chips(t, "mc", this.machines.map((m) => [m, m ?? "This computer"]), this.machine, (v, cx) => { this.machine = v; this.at = 0; this.loadDirs(cx, v); })))
      .child(h_flex().gap(8).items_center().child(label("agent"))
        .child(this.chips(t, "pv", ORDER.map((k) => [k, PROVIDERS[k].label]), this.provider, (v) => { this.provider = v; })))
      .when(p.models.length > 0, (el) => el.child(h_flex().gap(8).items_center().child(label("model"))
        .child(this.chips(t, "md", p.models.map((m) => [m.id, m.label]), this.model[this.provider], (v) => { this.model[this.provider] = v; }))))
      .when(p.efforts.length > 0, (el) => el.child(h_flex().gap(8).items_center().child(label("effort"))
        .child(this.chips(t, "ef", p.efforts.map((e) => [e, e]), this.effort[this.provider], (v) => { this.effort[this.provider] = v; }))))
      .child(h_flex().gap(8).items_center().child(label("open as"))
        .child(this.chips(t, "as", [[false, "new space"], [true, "tab in this space"]], this.asTab, (v) => { this.asTab = v; })))
      .when(!this.asTab, (el) => el.child(h_flex().gap(8).items_center().child(label("also open"))
        .child(h_flex().gap(4)
          .child(this.toggleChip(t, "ex-editor", "editor (nvim .)", "editor"))
          .child(this.toggleChip(t, "ex-prs", "PRs (tuicr)", "prs"))
          .when(this.machine == null, (el) => el.children(COMPANIONS.map(([key, kind]) => this.toggleChip(t, `ex-${key}`, kind, key)))))));

    const list = v_flex().id("ln-list").flex_1().min_h(0).overflow_y_scroll().gap(1)
      .children(rows.map((r, i) => h_flex()
        .id(`ln-${i}`)
        .h(30)
        .px(10)
        .gap(10)
        .flex_none()
        .rounded(7)
        .items_center()
        .cursor_pointer()
        .when(i === this.at, (el) => el.bg(t.hover))
        .hover((s) => s.bg(t.hover))
        .on_click(() => this.launch(r.path))
        .child(svg(`mods/workspace-chrome/${r.typed ? "folder-plus" : "folder"}.svg`).size(13).flex_none().text_color(r.recent ? t.accent : t.dim))
        .child(div().flex_none().max_w(200).truncate().text_color(t.foreground).child(r.name))
        .child(div().flex_1().min_w(0).truncate().text_size(11.5).text_color(t.dim).child(r.shown))))
      .when(rows.length === 0, (el) => el.child(div().px(10).py(8).text_size(12).text_color(t.dim).child("No recent projects match. Type a full path, or browse.")));

    return v_flex()
      .id("launcher")
      .size_full()
      .p(18)
      .gap(12)
      .bg(t.popover)
      .text_size(13)
      .on_key_down((e, cx) => {
        const k = e.key, ctrl = e.modifiers?.control;
        if (k === "escape") return closeOverlay(props().overlay);
        if (k === "down") this.at = Math.min(this.at + 1, rows.length - 1);
        else if (k === "up") this.at = Math.max(this.at - 1, 0);
        else if (k === "tab") this.cycle("provider", e.modifiers?.shift ? -1 : 1);
        else if (ctrl && k === "m") this.cycle("model");
        else if (ctrl && k === "e") this.cycle("effort");
        else if (ctrl && k === "o") { cx.stop_propagation(); return this.browse(cx); }
        else return;
        cx.stop_propagation();
        cx.notify();
      })
      .child(h_flex().items_center()
        .child(div().flex_1().text_size(15).font_semibold().text_color(t.foreground).child("New session"))
        .child(div().text_size(11).text_color(t.dim).child("Tab agent · ⌃M model · ⌃E effort · ⌃O browse · Esc")))
      .child(options)
      .child(h_flex().gap(8).items_center()
        .child(h_flex().flex_1().h(36).px(10).gap(8).items_center().rounded(9).border_1().border_color(t.accent).bg(t.background)
          .child(svg("mods/workspace-chrome/search.svg").size(15).text_color(t.dim))
          .child(Input.new(this.input).flex_1().h_full().text_size(12.8).text_color(t.foreground)))
        .when(this.machine == null, (el) => el.child(div().id("ln-browse").h(36).px(12).rounded(9).flex().items_center().gap(6).cursor_pointer()
          .border_1().border_color(t.border).text_color(t.muted).hover((s) => s.bg(t.hover).text_color(t.foreground))
          .on_click((_e, cx) => this.browse(cx))
          .child(svg("mods/workspace-chrome/folder.svg").size(13))
          .child("Browse…"))))
      .child(list);
  }
}
