import { View, div, svg } from "gpui-kit";
import { h_flex } from "gpui-base";
import { spaces, agents, focused, theme, run, exec, hc, keys, window, openOverlay, checking } from "herdr";

const SPOTIFY = 'if application "Spotify" is running then tell application "Spotify" to return (player state as text) & tab & artist of current track & tab & name of current track';
const UNREAD = "flag:unread AND NOT flag:trashed AND maildir:/Inbox$/";
const STATUSLINE = /\[([A-Za-z][\w .-]*?) [◔◑◕●○◐◒◓] (\w+)\]/;

const osa = (script) => exec("osascript", ["-e", script]).catch(() => null);

export default class Toolbar extends View {
  init(_props, cx) {
    this.music = null;
    this.mail = null;
    this.telegram = null;
    this.model = {};
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
      const r = await osa(SPOTIFY);
      const [state, artist, track] = (r?.code === 0 ? r.stdout.trim() : "").split("\t");
      this.music = state ? { playing: state === "playing", artist, track } : null;
      cx.notify();
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
      const r = await exec("lsappinfo", ["info", "-only", "StatusLabel", "Telegram"]).catch(() => null);
      const n = r?.stdout.match(/"label"="([^"]*)"/)?.[1];
      this.telegram = r && r.stdout.trim() ? (n || "0") : null;
      cx.notify();
    });
  }

  pollModel(cx) {
    const f = focused();
    const agent = f?.agent ?? f?.terminal;
    const a = agents().find((x) => x.address === agent);
    this.agent = a && a.app === "claude-code" ? a.address : null;
    if (!this.agent) return cx.notify();
    const address = this.agent;
    cx.spawn(async (cx) => {
      const r = await hc(["read", address]).catch(() => null);
      const lines = (r?.stdout ?? "").split("\n").reverse();
      for (const l of lines) {
        const m = l.match(STATUSLINE);
        if (m) { this.model[address] = { model: m[1], effort: m[2] }; break; }
      }
      cx.notify();
    });
  }

  hint() {
    const mac = window()?.platform === "macos";
    const mod = { cmd: mac ? "⌘" : "Ctrl+", ctrl: mac ? "⌃" : "Ctrl+", shift: mac ? "⇧" : "Shift+", alt: mac ? "⌥" : "Alt+" };
    const b = keys().find((k) => k.section === "global" && k.action === "mod.open:leader");
    return b ? `${b.keys.split("-").map((p) => mod[p.toLowerCase()] ?? p).join("")}  leader` : "leader";
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
    const m = this.agent && this.model[this.agent];
    const music = this.music;
    const sep = () => div().w(1).h(14).bg(t.border);

    return h_flex().size_full().px(14).gap(12).items_center().bg(t.chrome).border_t(1).border_color(t.border).text_size(11.8).text_color(t.muted)
      .child(label(space?.machine ? "server" : "monitor", space?.machine ?? "This computer"))
      .when(Boolean(space?.branch), (el) => el.child(label("branch", space.branch)))
      .child(h_flex().gap(6).items_center().child(div().size(6).rounded(3).bg(t.dim)).child(`${list.length} agents`)
        .when(needs > 0, (el) => el.child(div().text_color(t.blocked).child(`· ${needs} needs you`))))
      .child(div().flex_1())
      .when(Boolean(m), (el) => el
        .child(this.chip(t, "tb-model", `◆ ${m.model}`, t.foreground, leader(["a", "m"]), "Model of the focused Claude (⌘; a m)"))
        .child(this.chip(t, "tb-effort", `◔ ${m.effort}`, t.foreground, leader(["a", "E"]), "Effort of the focused Claude (⌘; a E)"))
        .child(sep()))
      .when(Boolean(music), (el) => el
        .child(this.chip(t, "tb-prev", "⏮", null, () => osa('tell application "Spotify" to previous track'), "Previous"))
        .child(this.chip(t, "tb-play", music.playing ? "⏸" : "▶", t.foreground, () => osa('tell application "Spotify" to playpause'), "Play / pause"))
        .child(this.chip(t, "tb-next", "⏭", null, () => osa('tell application "Spotify" to next track'), "Next"))
        .child(this.chip(t, "tb-track", h_flex().max_w(260).child(div().truncate().child(`${music.track} — ${music.artist}`)), music.playing ? t.done : t.dim, () => osa('tell application "Spotify" to activate'), "Open Spotify"))
        .child(sep()))
      .when(this.mail != null, (el) => el.child(this.chip(t, "tb-mail", `✉ ${this.mail}`, this.mail ? t.accent : t.dim,
        () => exec("emacsclient", ["-c", "-n", "-a", "", "-e", "(mu4e)"]).catch(() => {}), "Unread in your inboxes (mu4e)")))
      .when(this.telegram != null, (el) => el.child(this.chip(t, "tb-telegram", `✈ ${this.telegram}`, this.telegram !== "0" ? t.accent : t.dim,
        () => osa('tell application "Telegram" to activate'), "Telegram")))
      .child(sep())
      .child(div().id("tb-leader").text_color(t.dim).cursor_pointer().on_click(leader(null)).child(this.hint()));
  }
}
