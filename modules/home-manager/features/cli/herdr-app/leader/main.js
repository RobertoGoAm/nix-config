import { View, div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { openOverlay, agents, spaces, panes, terminals, focused, run, exec, hc, theme, props, closeOverlay, setShared, checking } from "herdr";


function openTelega() {
  for (const s of spaces()) {
    const tab = s.machine == null && s.tabs.find((x) => x.name === "telega");
    if (tab) {
      run("space.select", { id: s.id });
      run("tab.select", { id: tab.id });
      return;
    }
  }
  run("tab.new", { name: "telega", argv: ["emacsclient", "-t", "-a", "", "-e", "(telega)"] });
}

const HINTS = "arstneio";

const send = (text) => (target) => {
  if (!target) return;
  hc(["send", target, text]).catch(() => {});
};

function openJira() {
  const space = spaces().find((s) => s.active);
  if (!space) return;
  const tab = space.tabs.find((x) => x.name === "Kanban" || x.name.startsWith("Kanban · "));
  if (tab) return run("tab.select", { id: tab.id });
  const project = space.folder.split("/").filter(Boolean).pop() ?? space.name;
  run("tab.new", { space: space.id, name: `Kanban · ${project}`, mod: "jira", props: { folder: space.folder, space: space.id, view: "board" } });
}

const osa = (script) => () => exec("osascript", ["-e", script]).catch(() => {});

function openMusic() {
  for (const s of spaces()) {
    const tab = s.machine == null && s.tabs.find((x) => x.name === "music");
    if (tab) {
      run("space.select", { id: s.id });
      run("tab.select", { id: tab.id });
      return;
    }
  }
  run("tab.new", { name: "music", argv: ["emacsclient", "-t", "-a", "", "-e", "(smudge-my-playlists)"] });
}

const spotifyCtl = (cmd) => exec("spotify-ctl", [cmd], { timeout: 15000 }).catch(() => null);

const emacs = (form) => () => exec("emacsclient", ["-c", "-n", "-a", "", "-e", form]).catch(() => {});

const MODEL = {
  label: "model",
  agent: true,
  keys: {
    o: { label: "opus", agentAct: send("/model opus") },
    s: { label: "sonnet", agentAct: send("/model sonnet") },
    h: { label: "haiku", agentAct: send("/model haiku") },
    d: { label: "default", agentAct: send("/model default") },
  },
};

const EFFORT = {
  label: "effort",
  agent: true,
  keys: {
    l: { label: "low", agentAct: send("/effort low") },
    m: { label: "medium", agentAct: send("/effort medium") },
    h: { label: "high", agentAct: send("/effort high") },
    x: { label: "xhigh", agentAct: send("/effort xhigh") },
    M: { label: "max", agentAct: send("/effort max") },
  },
};

const TREE = {
  label: "leader",
  keys: {
    space: { label: "run command", act: () => run("app.palette") },
    a: {
      label: "ai / agents",
      keys: {
        a: { label: "next needing you", act: () => run("agents-plus.attention") },
        n: { label: "next agent", act: () => run("agent.next") },
        e: { label: "previous agent", act: () => run("agent.prev") },
        l: { label: "switch agent…", act: () => run("mod.open", { name: "picker-plus" }) },
        f: { label: "cycle filter", act: () => run("agents-plus.filter") },
        s: { label: "search agents", act: () => run("agents-plus.search") },
        R: { label: "review PR (tuicr)", act: () => run("agents-plus.review") },
        c: { label: "chat ⇄ terminal", act: () => run("agents-plus.chat") },
        m: MODEL,
        E: EFFORT,
      },
    },
    b: {
      label: "buffers",
      keys: {
        b: { label: "find tab / agent", act: () => run("mod.open", { name: "picker-plus" }) },
        d: { label: "destroy tab", act: () => run("tab.close") },
      },
    },
    j: {
      label: "jump",
      keys: {
        j: { label: "anything", jump: "all" },
        a: { label: "agent", jump: "agent" },
        t: { label: "tab", jump: "tab" },
        w: { label: "pane", jump: "pane" },
      },
    },
    t: {
      label: "tabs",
      keys: {
        c: { label: "new", act: () => run("tab.new") },
        x: { label: "close", act: () => run("tab.close") },
        r: { label: "rename", act: () => run("tab.rename") },
        n: { label: "next", act: () => run("tab.next") },
        e: { label: "previous", act: () => run("tab.prev") },
        ...Object.fromEntries([1, 2, 3, 4, 5, 6, 7, 8, 9].map((i) => [String(i), { label: `tab ${i}`, act: () => run("tab.select", { index: i }) }])),
      },
    },
    s: {
      label: "spaces",
      keys: {
        c: { label: "new session…", act: () => openOverlay({ mod: "launcher", kind: "dialog", width: 680, height: 0.72, props: { machine: "" } }) },
        v: { label: "new on vulcan…", act: () => openOverlay({ mod: "launcher", kind: "dialog", width: 680, height: 0.72, props: { machine: "vulcan" } }) },
        n: { label: "next", act: () => run("space.next") },
        e: { label: "previous", act: () => run("space.prev") },
        r: { label: "rename", act: () => run("space.rename") },
        x: { label: "close", act: () => run("space.close") },
      },
    },
    w: {
      label: "windows / panes",
      keys: {
        h: { label: "focus left", act: () => run("pane.go", { direction: "left" }) },
        n: { label: "focus down", act: () => run("pane.go", { direction: "down" }) },
        e: { label: "focus up", act: () => run("pane.go", { direction: "up" }) },
        i: { label: "focus right", act: () => run("pane.go", { direction: "right" }) },
        H: { label: "swap left", act: () => run("pane.swap", { direction: "left" }) },
        N: { label: "swap down", act: () => run("pane.swap", { direction: "down" }) },
        E: { label: "swap up", act: () => run("pane.swap", { direction: "up" }) },
        I: { label: "swap right", act: () => run("pane.swap", { direction: "right" }) },
        v: { label: "split right", act: () => run("pane.split", { direction: "right" }) },
        s: { label: "split down", act: () => run("pane.split", { direction: "down" }) },
        z: { label: "zoom", act: () => run("pane.zoom") },
        x: { label: "close", act: () => run("pane.close") },
      },
    },
    m: {
      label: "music",
      keys: {
        m: { label: "play / pause", act: () => spotifyCtl("playpause") },
        n: { label: "next track", act: () => spotifyCtl("next") },
        p: { label: "previous track", act: () => spotifyCtl("previous") },
        l: { label: "my playlists", act: () => openMusic() },
        o: { label: "open Spotify app", act: osa('tell application "Spotify" to activate') },
      },
    },
    i: {
      label: "inbox",
      keys: {
        i: { label: "open mail", act: emacs("(mu4e)") },
        c: { label: "compose", act: emacs("(mu4e-compose-new)") },
        s: { label: "search mail", act: emacs("(call-interactively #'mu4e-search)") },
      },
    },
    o: {
      label: "open",
      keys: {
        t: { label: "telega", act: () => openTelega() },
        T: { label: "Telegram app", act: osa('tell application "Telegram" to activate') },
      },
    },
    k: { label: "jira board (kanban)", act: () => openJira() },
    l: { label: "next layout", act: () => run("layout.switch") },
    ",": { label: "settings", act: () => run("app.settings") },
    "?": { label: "all keys", act: () => run("app.help") },
  },
};

function codes(n) {
  const out = [];
  for (const a of HINTS) for (const b of HINTS) out.push(a + b);
  return out.slice(0, n);
}

export default class Leader extends View {
  init(_props, cx) {
    const f = focused();
    this.agent = f?.agent ?? f?.terminal ?? null;
    this.path = [];
    this.typed = "";
    this.jump = null;
    this.handle = cx.focus_handle();
    const start = props()?.start;
    if (Array.isArray(start)) this.path = start.filter((_, i) => start.slice(0, i + 1).reduce((n, k) => n?.keys?.[k], TREE)?.keys);
    if (checking()) return;
    cx.timer.after(30, () => this.handle.focus());
  }

  async close() {
    setShared("leader.jump", null);
  }

  node() {
    return this.path.reduce((n, k) => n.keys[k], TREE);
  }

  done() {
    setShared("leader.jump", null);
    closeOverlay(props().overlay);
  }

  targets(kind) {
    let list = [];
    for (const a of agents()) list.push({ kind: "agent", id: a.address, label: `${a.space_name} · ${(a.title || a.program?.name || a.address).replace(/^[^\p{L}\p{N}]+/u, "")}`, go: () => run("agent.focus", { terminal: a.address }) });
    for (const s of spaces()) for (const tab of s.tabs) list.push({ kind: "tab", id: tab.id, label: `${s.name} / ${tab.name}`, go: () => { run("space.select", { id: s.id }); run("tab.select", { id: tab.id }); } });
    const here = focused()?.tab;
    for (const p of panes().filter((p) => p.tab === here)) list.push({ kind: "pane", id: p.pane, label: p.title || p.program?.name || p.pane, go: () => run("pane.focus", { pane: p.pane }) });
    if (kind && kind !== "all") list = list.filter((t) => t.kind === kind);
    const cs = codes(list.length);
    return list.map((t, i) => ({ ...t, code: cs[i] }));
  }

  startJump(kind) {
    this.jump = this.targets(kind);
    this.typed = "";
    setShared("leader.jump", Object.fromEntries(this.jump.filter((t) => t.kind === "agent").map((t) => [t.id, t.code])));
  }

  press(k) {
    if (this.jump) {
      this.typed += k;
      const hit = this.jump.find((t) => t.code === this.typed);
      if (hit) { this.done(); hit.go(); return; }
      if (!this.jump.some((t) => t.code.startsWith(this.typed))) this.typed = "";
      return;
    }
    const n = this.node().keys[k];
    if (!n) return;
    if (n.jump) return this.startJump(n.jump);
    if (n.keys) { this.path.push(k); return; }
    this.done();
    if (n.agentAct) n.agentAct(this.agent);
    else n.act?.();
  }

  render(cx) {
    const t = theme();
    const node = this.node();
    const crumbs = ["⌘;", ...this.path.map((k, i) => this.path.slice(0, i + 1).reduce((n, kk) => n.keys[kk], TREE).label)].join("  ›  ");
    const keyCap = (k) => div().min_w(22).h(20).px(5).rounded(5).flex().items_center().justify_center().bg(t.raised).border_1().border_color(t.border).text_size(11.5).font_semibold().text_color(t.accent).child(k);

    const body = this.jump
      ? v_flex().gap(2).children(this.jump.map((x) => h_flex().gap(10).items_center().h(24)
          .child(div().w(30).text_size(12.5).font_bold().text_color(x.code.startsWith(this.typed) ? t.accent : t.dim).child(x.code))
          .child(div().w(44).text_size(10.5).text_color(t.dim).child(x.kind))
          .child(div().flex_1().truncate().text_color(x.code.startsWith(this.typed) ? t.foreground : t.dim).child(x.label))))
      : h_flex().flex_wrap().gap_x(18).gap_y(6).children(Object.entries(node.keys).map(([k, n]) => h_flex().w(170).gap(8).items_center()
          .child(keyCap(k))
          .child(div().truncate().text_color(n.keys ? t.accent : t.foreground).child(n.keys ? `+${n.label}` : n.label))));

    return v_flex()
      .id("leader")
      .track_focus(this.handle)
      .size_full()
      .p(16)
      .gap(12)
      .bg(t.popover)
      .text_size(13)
      .on_key_down((e, cx) => {
        cx.stop_propagation();
        const k = e.key;
        if (k === "escape") return this.done();
        if (k === "backspace") {
          if (this.jump) { this.jump = this.typed ? this.jump : null; this.typed = ""; if (!this.jump) setShared("leader.jump", null); }
          else this.path.pop();
          return cx.notify();
        }
        const key = e.modifiers?.shift && /^[a-z]$/.test(k) ? k.toUpperCase() : k;
        if (key.length !== 1 && key !== "space") return;
        this.press(key);
        cx.notify();
      })
      .child(h_flex().items_center().child(div().flex_1().text_size(11.5).text_color(t.dim).child(this.jump ? `jump  ${this.typed || "…"}` : crumbs))
        .when(Boolean(node.agent) && !this.jump, (el) => el.child(div().text_size(11).text_color(this.agent ? t.muted : t.blocked).child(this.agent ? `→ ${this.agent}` : "no agent focused"))))
      .child(div().id("leader-body").flex_1().min_h(0).overflow_y_scroll().child(body));
  }
}
