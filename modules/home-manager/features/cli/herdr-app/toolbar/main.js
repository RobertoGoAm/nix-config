import { View, div, svg } from "gpui-kit";
import { h_flex } from "gpui-base";
import { spaces, agents, focused, panes, shared, theme, run, exec, hc, openOverlay, checking } from "herdr";


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

const UNREAD = "flag:unread";
const STATUSLINE = /\[((?:Opus|Sonnet|Haiku|Fable|Claude)[\w .-]*?)(?: [◔◑◕●○◐◒◓] (\w+))?\]/;
const ACCOUNT_MS = 10 * 60000;
const ACCOUNT = `pid=$(hc get "$1" --json 2>/dev/null | jq -r '.foreground.pid // .pid // empty')
[ -n "$pid" ] || exit 3
for d in "$HOME/.claude-work" "$HOME/.claude-personal" "$HOME/.claude"; do
  [ -f "$d/sessions/$pid.json" ] || continue
  printf '%s\n' "$d"
  if [ "$d" = "$HOME/.claude" ]; then CLAUDE_ACCOUNT=personal claude auth status --text 2>/dev/null
  else CLAUDE_CONFIG_DIR="$d" claude auth status --text 2>/dev/null; fi
  exit 0
done
exit 4`;

function accountLabel(text) {
  const org = text.match(/^Organization:\s*(.+)$/m)?.[1]?.trim();
  const plan = text.match(/^Login method:\s*Claude (\w+)/m)?.[1];
  if (!org && !plan) return null;
  const personal = !org || /'s Organization$/.test(org);
  return { label: `${personal ? "Personal" : org}${plan ? " · " + plan : ""}`, personal };
}

const TELEGRAM = "/Applications/Telegram.app";
const TELEGA_UNREAD = "(if (and (fboundp 'telega-server-live-p) (telega-server-live-p)) (or (plist-get (bound-and-true-p telega--unread-chat-count) :unread_unmuted_count) 0) -1)";


export default class Toolbar extends View {
  init(_props, cx) {
    this.music = null;
    this.mail = null;
    this.telegram = null;
    this.model = {};
    this.account = {};
    if (checking()) return;
    cx.timer.every(3000, (cx) => this.pollMusic(cx));
    cx.timer.every(5000, (cx) => this.pollModel(cx));
    cx.timer.every(60000, (cx) => this.pollMail(cx));
    cx.timer.every(15000, (cx) => this.pollTelegram(cx));
    this.pollMusic(cx);
    this.pollModel(cx);
    this.pollMail(cx);
    this.pollTelegram(cx);
  }

  pollMusic(cx) {
    cx.spawn(async (cx) => {
      const r = await spotifyCtl("now");
      const [state, artist, track] = (r?.code === 0 ? r.stdout.trim() : "").split("\t");
      this.music = track ? { playing: state === "▶", artist, track } : null;
      cx.notify();
    });
  }

  musicDo(cx, cmd) {
    cx.spawn(async (cx) => {
      await spotifyCtl(cmd);
      this.pollMusic(cx);
    });
  }

  pollMail(cx) {
    cx.spawn(async (cx) => {
      const r = await exec("mu", ["find", "--fields=i", UNREAD]).catch(() => null);
      if (r) this.mail = r.code === 0 ? r.stdout.split("\n").filter(Boolean).length : 0;
      cx.notify();
    });
  }

  pollTelegram(cx) {
    cx.spawn(async (cx) => {
      const e = await exec("emacsclient", ["-e", TELEGA_UNREAD], { timeout: 5000 }).catch(() => null);
      const telega = e?.code === 0 ? Number(e.stdout.trim()) : -1;
      if (telega >= 0) { this.telegram = { running: true, count: telega, via: "telega" }; return cx.notify(); }
      const installed = await exec("/bin/test", ["-d", TELEGRAM]).then((x) => x.code === 0).catch(() => false);
      if (!installed) { this.telegram = null; return cx.notify(); }
      const r = await exec("lsappinfo", ["info", "-only", "StatusLabel", "Telegram"]).catch(() => null);
      const running = Boolean(r?.stdout.trim());
      this.telegram = { running, count: running ? Number(r.stdout.match(/"label"="(\d+)"/)?.[1] ?? 0) : null };
      cx.notify();
    });
  }

  pollAccount(cx, address) {
    const now = Date.now();
    const known = this.account[address];
    if (known && now - known.at < ACCOUNT_MS) return;
    this.account[address] = { ...(known ?? {}), at: now };
    const on = address.includes("/") ? address.split("/")[0] : null;
    const local = address.includes("/") ? address.split("/").slice(1).join("/") : address;
    cx.spawn(async (cx) => {
      const r = await exec("sh", ["-c", ACCOUNT, "account", local], { on, timeout: 20000 }).catch(() => null);
      if (r?.code === 0) {
        const [dir, ...rest] = r.stdout.split("\n");
        this.account[address] = { at: now, dir, ...(accountLabel(rest.join("\n")) ?? { label: "signed out", personal: null }) };
      }
      cx.notify();
    });
  }

  focusedClaude() {
    const f = focused();
    const here = f?.pane && panes().find((p) => p.pane === f.pane);
    const chatPane = here?.mod === "chat" ? here.pane : null;
    const address = chatPane ? (shared("chat.panes") ?? {})[chatPane] : (f?.agent ?? f?.terminal);
    const a = agents().find((x) => x.address === address);
    return a && a.app === "claude-code" ? { address: a.address, pane: a.pane, chatPane } : null;
  }

  toggleView() {
    const c = this.focusedClaude();
    if (!c) return;
    run("pane.focus", { pane: c.chatPane ?? c.pane });
    run("agents-plus.chat");
  }

  pollModel(cx) {
    this.agent = this.focusedClaude()?.address ?? null;
    if (!this.agent) return cx.notify();
    const address = this.agent;
    this.pollAccount(cx, address);
    cx.spawn(async (cx) => {
      const r = await hc(["read", address]).catch(() => null);
      const lines = (r?.stdout ?? "").split("\n").reverse();
      for (const l of lines) {
        const m = l.match(STATUSLINE);
        if (m) { this.model[address] = { model: m[1], effort: m[2] ?? "default" }; break; }
      }
      cx.notify();
    });
  }

  chip(t, id, text, color, onClick, tip) {
    return h_flex().id(id).h(20).px(7).gap(5).rounded(5).items_center().cursor_pointer()
      .text_color(color ?? t.muted)
      .hover((s) => s.bg(t.hover).text_color(t.foreground))
      .when(Boolean(tip), (el) => el.tooltip(tip))
      .on_click(onClick)
      .child(text);
  }

  render() {
    const t = theme();
    const space = spaces().find((s) => s.active);
    const list = agents();
    const needs = list.filter((a) => a.status === "blocked").length;
    const label = (icon, text) => h_flex().gap(6).items_center().child(svg(`mods/workspace-chrome/${icon}.svg`).size(13)).child(text);
    const leader = (start) => () => openOverlay({ mod: "leader", kind: "dialog", width: 640, height: 0.55, props: { start } });
    const claude = this.focusedClaude();
    if (claude && claude.address !== this.agent && !checking()) { this.agent = claude.address; }
    const m = this.agent && this.model[this.agent];
    const acct = this.agent && this.account[this.agent];
    const music = this.music;
    const sep = () => div().w(1).h(14).bg(t.border);

    return h_flex().size_full().px(14).gap(12).items_center().bg(t.chrome).border_t(1).border_color(t.border).text_size(11.8).text_color(t.muted)
      .child(label(space?.machine ? "server" : "monitor", space?.machine ?? "This computer"))
      .when(Boolean(space?.branch), (el) => el.child(label("branch", space.branch)))
      .child(h_flex().gap(6).items_center().child(div().size(6).rounded(3).bg(t.dim)).child(`${list.length} agents`)
        .when(needs > 0, (el) => el.child(div().text_color(t.blocked).child(`· ${needs} needs you`))))
      .child(div().flex_1())
      .when(Boolean(claude), (el) => el.child(this.chip(t, "tb-view", claude.chatPane ? "⇄ Terminal" : "⇄ Chat", t.accent, () => this.toggleView(),
        claude.chatPane ? "Show this agent's terminal (⌘⇧C)" : "Show this agent as a chat (⌘⇧C)")))
      .when(Boolean(m), (el) => el
        .when(Boolean(acct?.label), (el) => {
          const wantsPersonal = /\/\.claude(-personal)?$/.test(acct.dir ?? "");
          const wrong = acct.personal === false && wantsPersonal;
          return el.child(this.chip(t, "tb-account", `◉ ${acct.label}${wrong ? " !" : ""}`, wrong ? t.blocked : acct.personal ? t.done : t.accent, () => {},
            wrong ? `${acct.dir} should be your personal login but is signed into ${acct.label}. Run \`claude auth login\` outside the work folders and pick your personal account.` : `Account of the focused Claude, from ${acct.dir ?? "?"}`));
        })
        .child(this.chip(t, "tb-model", `◆ ${m.model}`, t.foreground, leader(["a", "m"]), "Model of the focused Claude (⌘; a m)"))
        .child(this.chip(t, "tb-effort", `◔ ${m.effort}`, t.foreground, leader(["a", "E"]), "Effort of the focused Claude (⌘; a E)"))
        .child(sep()))
      .when(Boolean(music), (el) => el
        .child(this.chip(t, "tb-prev", "⏮", null, (_e, cx) => this.musicDo(cx, "previous"), "Previous"))
        .child(this.chip(t, "tb-play", music.playing ? "⏸" : "▶", t.foreground, (_e, cx) => this.musicDo(cx, "playpause"), "Play / pause"))
        .child(this.chip(t, "tb-next", "⏭", null, (_e, cx) => this.musicDo(cx, "next"), "Next"))
        .child(this.chip(t, "tb-track", h_flex().max_w(260).child(div().truncate().child(`${music.track} — ${music.artist}`)), music.playing ? t.done : t.dim, () => openMusic(), "Playlists, search and devices (smudge in a Herdr tab)"))
        .child(sep()))
      .when(this.mail != null, (el) => el.child(this.chip(t, "tb-mail", `✉ ${this.mail}`, this.mail ? t.accent : t.dim,
        () => exec("/usr/bin/open", ["-b", "com.apple.mail"]).catch(() => {}), "Unread mail (mu, as in Emacs). Click: Mail")))
      .when(this.telegram != null, (el) => el.child(this.chip(t, "tb-telegram",
        this.telegram.running ? `✈ ${this.telegram.count}` : "✈",
        this.telegram.count ? t.accent : t.dim,
        () => (this.telegram.via === "telega" ? openTelega() : exec("/usr/bin/open", ["-a", TELEGRAM]).catch(() => {})),
        this.telegram.via === "telega" ? "Unread unmuted chats (telega). Click: telega tab" : this.telegram.running ? "Telegram: unread chats" : "Telegram is closed: click to open")));
  }
}
