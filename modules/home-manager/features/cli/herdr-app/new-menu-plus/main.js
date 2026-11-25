import { View, div, svg, image } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { theme, spaces, panes, terminals, knownAgents, run, exec, openOverlay, closeOverlay, props, window, keys, shared, setShared } from "herdr";

// Herdr's new-menu (the tab bar's +), with the space's companion tabs below
// it: the editor, Notes, MRs, Kanban and Backlog, opened by hand, or shown
// when the space has one. tabs-plus, derived from Herdr's tabs on every
// switch (herdr.org), opens this in place of new-menu.

// The last agents each machine reported, shown at once while knownAgents() checks again.
const KNOWN = "new-menu.agents";
const JIRA = "new-menu-plus.jira";

// The folder a space's companions work in: its repository, or for a space on
// another machine its terminals' folder, which the MRs tab reviews through
// the checkout at the same path here.
function companionFolder(space) {
  if (!space) return null;
  if (!space.machine) return (shared("space.repos") ?? {})[space.id]?.path ?? (space.folder || null);
  const local = space.id.slice(space.machine.length + 1);
  const t = terminals().find(x => x.address.startsWith(`${space.machine}/`) && x.labels?.["herdr.space"] === local && x.cwd);
  return space.folder || t?.cwd || null;
}

function shortcut(name) {
  const k = keys().find(b => b.section === "global" && b.action === name);
  if (!k?.keys.trim()) return "";
  const mac = window()?.platform === "macos";
  const names = mac ? { ctrl: "⌃", alt: "⌥", shift: "⇧", cmd: "⌘", fn: "fn" } : { ctrl: "Ctrl", alt: "Alt", shift: "Shift", cmd: "Super", fn: "Fn" };
  const alias = { secondary: mac ? "cmd" : "ctrl", super: "cmd", win: "cmd" };
  return k.keys.trim().split(/\s+/).map(stroke => {
    const parts = stroke.split("-");
    let key = parts.pop();
    if (key === "") { key = "-"; parts.pop(); }
    const held = new Set(parts.map(m => alias[m.toLowerCase()] ?? m.toLowerCase()));
    if (/^[A-Z]$/.test(key)) held.add("shift");
    const label = key.length === 1 ? key.toUpperCase() : key[0].toUpperCase() + key.slice(1).toLowerCase();
    return [...Object.keys(names).filter(m => held.has(m)).map(m => names[m]), label].join(mac ? "" : "+");
  }).join(" ");
}

export default class NewMenu extends View {
  init(_props, cx) {
    const machine = spaces().find(s => s.active)?.machine;
    const where = machine ?? "";
    this.agents = shared(KNOWN)?.[where] ?? [];
    this.handle = cx.focus_handle();
    this.handle.focus();
    const space = spaces().find(s => s.active);
    const folder = companionFolder(space);
    this.jira = shared(JIRA)?.[folder ?? ""] ?? null;
    if (folder && !space?.machine) cx.spawn(async cx => {
      try {
        const r = await exec("jira-board", ["project", folder, space.branch ?? ""], { timeout: 15000 });
        this.jira = r.code === 0 ? JSON.parse(r.stdout || "null")?.key ?? "" : "";
      } catch { this.jira = ""; }
      setShared(JIRA, { ...(shared(JIRA) ?? {}), [folder]: this.jira });
      cx.notify();
    });
    cx.spawn(async cx => {
      try {
        this.agents = await knownAgents({ on: machine });
        setShared(KNOWN, { ...shared(KNOWN), [where]: this.agents });
      }
      catch { this.failed = true; }
      cx.notify();
    });
  }
  row(id, icon, name, action, hint = "", enabled = true) {
    const t = theme();
    return h_flex().id(id).h(31).px(9).gap(10).rounded(7).items_center().flex_none()
      .text_color(enabled ? t.foreground : t.dim).when(enabled, el => el.hover(s => s.bg(t.selected)))
      .on_click(() => { if (enabled) { closeOverlay(props().overlay); action(); } })
      .child(icon).child(div().flex_1().child(name)).child(div().text_size(11).text_color(t.dim).child(hint));
  }
  // A row for one companion: shows the space's tab of that kind when there is
  // one, and opens it otherwise.
  companion(space, kind, icon, open, enabled = true, hint = "") {
    const tab = space?.tabs.find(x => x.name === kind || x.name.startsWith(`${kind} · `) || (kind === "Neovim" && x.name.startsWith("Neovim")));
    return this.row(`c-${kind}`, icon, kind, () => tab ? run("tab.select", { id: tab.id }) : open(), tab ? "show" : hint, enabled || Boolean(tab));
  }

  companions(space) {
    const t = theme();
    const folder = companionFolder(space);
    if (!space || !folder) return [];
    const project = (shared("space.repos") ?? {})[space.id]?.name ?? folder.split("/").filter(Boolean).pop();
    const glyph = (c) => div().w(14).text_color(t.dim).child(c);
    const jira = this.jira;
    const jiraHint = jira == null ? "checking…" : jira ? jira : "no Jira project";
    const remote = Boolean(space.machine);
    return [
      div().h(1).mx(4).my(5).bg(t.border),
      div().px(9).pt(4).pb(4).text_size(11).text_color(t.dim).child("Open in this space"),
      this.companion(space, "Neovim", glyph("✎"), () => run("tab.new", { space: space.id, folder, argv: ["nvim", "."] })),
      this.companion(space, "Notes", glyph("¶"), () => run("tab.new", { space: space.id, name: `Notes · ${project}`, folder, argv: ["notes"] }), !remote, remote ? "this computer only" : ""),
      this.companion(space, "MRs", glyph("⇄"), () => run("tab.new", { space: space.id, name: `MRs · ${project}`, mod: "mrs", props: { folder, space: space.id } })),
      ...[["Kanban", "board", "▦"], ["Backlog", "backlog", "≡"]].map(([kind, view, c]) =>
        this.companion(space, kind, glyph(c), () => run("tab.new", { space: space.id, name: `${kind} · ${project} (${jira})`, mod: "jira", props: { folder, space: space.id, view } }), Boolean(jira) && !remote, remote ? "this computer only" : jiraHint)),
    ];
  }

  render() {
    const t = theme();
    const space = spaces().find(s => s.active);
    const extra = this.companions(space);
    const installed = this.agents.filter(a => a.installed);
    const choices = this.failed ? installed : [...installed, ...this.agents.filter(a => !a.installed).slice(0, 2)];
    return v_flex().min_h(0).w_full().h(Math.min(491, 167 + Math.max(1, choices.length + (this.failed ? 1 : 0)) * 31) + (extra.length ? 36 + (extra.length - 2) * 31 : 0)).bg(t.popover).p(5).text_size(12.8)
      .id("new-menu").track_focus(this.handle)
      .on_key_down((e) => {
        if (e.modifiers.control || e.modifiers.platform || e.modifiers.alt) return;
        const agent = /^[1-9]$/.test(e.key) ? installed[Number(e.key) - 1] : null;
        if (!agent) return;
        closeOverlay(props().overlay);
        run("tab.new", { name: agent.name, space: space?.id, argv: agent.run });
      })
      .child(this.row("terminal", svg("icons/shell.svg").size(14), "Terminal", () => run("tab.new", { space: space?.id }), shortcut("tab.new")))
      .child(div().px(9).pt(8).pb(4).text_size(11).text_color(t.dim).child("Start an agent"))
      .child(v_flex().flex_1().min_h(0).overflow_y_scrollbar()
        .children(choices.map((a, i) => this.row(a.key, a.tint ? svg(a.icon).size(14).text_color(t.foreground) : image(a.icon).size(14), a.name,
          () => run("tab.new", { name: a.name, space: space?.id, argv: a.run }), a.installed ? (i < 9 ? String(i + 1) : "") : "not installed", a.installed)))
        .when(this.failed || this.agents.length === 0, el => el.child(div().px(9).py(6).text_color(t.dim).child(this.failed ? "Could not check installed agents" : "Checking installed agents…"))))
      .child(div().h(1).mx(4).my(5).bg(t.border))
      .child(this.row("space", div().w(14).child("+"), "New space", () => run("space.new"), shortcut("space.new")))
      .child(this.row("worktree", svg("mods/workspace-chrome/branch.svg").size(14), "New worktree…", () => openOverlay({ mod: "worktree", kind: "dialog", width: 460, height: 280, props: { space: space?.id, folder: panes().find(p => p.focused)?.cwd, action: "new" } }), "", Boolean(space)))
      .child(this.row("worktree-open", svg("mods/workspace-chrome/branch.svg").size(14), "Open worktree\u2026", () => openOverlay({ mod: "worktree", kind: "dialog", width: 560, height: 480, props: { space: space?.id, folder: panes().find(p => p.focused)?.cwd, action: "open" } }), "", Boolean(space)))
      .children(extra);
  }
}
