import { View, div, svg, image } from "gpui-kit";
import { v_flex, h_flex, TextareaState, Textarea, TextView, ScrollHandle, EditorState, Editor } from "gpui-base";
import { agents, terminals, panes, run, exec, hc, theme, settings, props, shared, setShared, nextCommand, checking, appHome, spaces, window } from "herdr";

const FIND = `t="$1"
pid=$(hc get "$t" --json 2>/dev/null | jq -r '.foreground.pid // .pid // empty')
[ -n "$pid" ] || exit 3
for d in "$HOME/.claude" "$HOME/.claude-work" "$HOME/.claude-personal"; do
  f="$d/sessions/$pid.json"
  [ -f "$f" ] || continue
  id=$(jq -r '.sessionId // empty' "$f")
  [ -n "$id" ] || continue
  for j in "$d"/projects/*/"$id".jsonl; do
    [ -f "$j" ] && { printf '%s' "$j"; exit 0; }
  done
done
exit 4`;

const READ = `size=$(wc -c < "$1" 2>/dev/null | tr -d ' ') || exit 3
[ -n "$size" ] || exit 3
echo "$size"
[ "$size" -gt "$2" ] && tail -c +$(($2 + 1)) "$1"
exit 0`;

const IMAGE = `out="$1"; file="$2"; uuid="$3"; idx="$4"; on="$5"
mkdir -p "$(dirname "$out")"
if [ ! -s "$out" ]; then
  if [ -n "$on" ]; then
    hc exec --on "$on" -- sh -c 'grep -F "\"uuid\":\"$2\"" "$1" | head -1 | jq -r ".message.content[$3].source.data // empty"' x "$file" "$uuid" "$idx"
  else
    grep -F "\"uuid\":\"$uuid\"" "$file" | head -1 | jq -r ".message.content[$idx].source.data // empty"
  fi | base64 -d > "$out" 2>/dev/null
  [ -s "$out" ] || { rm -f "$out"; exit 3; }
fi
sips -g pixelWidth -g pixelHeight "$out" 2>/dev/null | awk '/pixelWidth/{w=$2}/pixelHeight/{h=$2}END{print w, h}'`;
const THUMB_W = 260;
const THUMB_H = 320;
const IMAGE_REF = /\[Image(?: #\d+)?(?:: source: [^\]]*)?\]/g;

const SEEN_EVERY = 4000;

function stamp(iso) {
  if (!iso) return "";
  const d = new Date(iso);
  if (isNaN(d)) return "";
  const hm = `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
  const now = new Date();
  if (d.toDateString() === now.toDateString()) return hm;
  const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  return `${months[d.getMonth()]} ${d.getDate()} ${hm}`;
}

const FIRST_BYTES = 1500000;
const KEEP = 400;
const SHOWN = 160;

const STOPPED = /^\[Request interrupted by user( for tool use)?\]/;
const REJECTED = /^The user doesn't want to proceed with this tool use/;
const SYSTEM_TAG = /^<(system-reminder|local-command-caveat|local-command-stdout|command-message|task-notification|user-prompt-submit-hook)/;

function commandLine(text) {
  const name = text.match(/<command-name>([^<]*)<\/command-name>/)?.[1];
  if (!name) return null;
  const args = text.match(/<command-args>([^<]*)<\/command-args>/)?.[1]?.trim();
  return [name.startsWith("/") ? name : `/${name}`, args].filter(Boolean).join(" ");
}

function toolSummary(name, input) {
  const i = input ?? {};
  const first = (s) => String(s ?? "").split("\n")[0].slice(0, 160);
  const pick = i.description || i.command || i.file_path || i.path || i.pattern || i.url || i.query || i.prompt || i.subject || i.skill;
  return `${name}${pick ? ": " + first(pick) : ""}`;
}

const DIFF_PREVIEW = 24;
const FENCE = /```([\w+#.-]*)[^\n]*\n([\s\S]*?)```/g;
const LANGS = {
  js: "javascript", jsx: "javascript", mjs: "javascript", cjs: "javascript", javascript: "javascript",
  ts: "typescript", tsx: "tsx", typescript: "typescript",
  sh: "bash", bash: "bash", zsh: "bash", shell: "bash", console: "bash",
  py: "python", python: "python", rb: "ruby", ruby: "ruby", rs: "rust", rust: "rust", go: "go",
  nix: "nix", json: "json", jsonc: "json", yaml: "yaml", yml: "yaml", toml: "toml",
  php: "php", html: "html", css: "css", scss: "css", sql: "sql", lua: "lua", md: "markdown", markdown: "markdown",
  el: "elisp", elisp: "elisp", lisp: "elisp", c: "c", h: "c", cpp: "cpp", java: "java", kt: "kotlin", swift: "swift", diff: "diff",
};
const langOf = (name) => LANGS[(name ?? "").toLowerCase()] ?? "text";
const extLang = (path) => langOf(String(path ?? "").split(".").pop());
const KEYWORDS = new Set("if else elif fi then do done for while in of return function fn func def class import from export const let var new await async try catch finally throw case switch default break continue match struct enum impl pub use mod trait type interface extends implements public private protected static self this super null nil None true false True False undefined with inherit rec where package echo local and or not is lambda yield".split(" "));
const TOKEN = /(\/\/.*$|#(?![{!]).*$|--\s.*$|;;.*$|\/\*.*?\*\/)|("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|`(?:[^`\\]|\\.)*`)|(\b\d[\d_.xa-fA-F]*\b)|([A-Za-z_$][\w$-]*)(?=\s*\()|([A-Za-z_$][\w$]*)/g;

function syntaxColors(t) {
  return {
    keyword: t.ansi5, string: t.ansi2, comment: t.idle ?? t.dim, function: t.ansi4, type: t.ansi6,
    number: t.ansi3, constant: t.ansi3, boolean: t.ansi3, variable: t.foreground, operator: t.ansi6,
    punctuation: t.muted, "string.escape": t.ansi1,
  };
}

function highlight(text, lang, t) {
  const c = syntaxColors(t);
  const commentOk = (m) => !(m.startsWith("#") && !["bash", "python", "ruby", "nix", "yaml", "toml", "elisp", "text"].includes(lang))
    && !(m.startsWith("--") && !["sql", "lua"].includes(lang)) && !(m.startsWith(";;") && lang !== "elisp");
  const out = [];
  let at = 0, m;
  TOKEN.lastIndex = 0;
  while ((m = TOKEN.exec(text))) {
    if (m.index > at) out.push([text.slice(at, m.index), null]);
    const [all, comment, str, num, fn, word] = m;
    const color = comment && commentOk(comment) ? c.comment : str ? c.string : num ? c.number : fn ? c.function
      : word && KEYWORDS.has(word) ? c.keyword : word && /^[A-Z][a-z]/.test(word) ? c.type : null;
    if (comment && !commentOk(comment)) { out.push([all[0], null]); at = m.index + 1; TOKEN.lastIndex = at; continue; }
    out.push([all, color]);
    at = m.index + all.length;
  }
  if (at < text.length) out.push([text.slice(at), null]);
  return out;
}

function segments(text) {
  const out = [];
  let at = 0, m;
  FENCE.lastIndex = 0;
  while ((m = FENCE.exec(text))) {
    if (m.index > at) out.push({ prose: text.slice(at, m.index) });
    out.push({ lang: langOf(m[1]), label: m[1] || "code", code: m[2].replace(/\n$/, "") });
    at = m.index + m[0].length;
  }
  if (at < text.length) out.push({ prose: text.slice(at) });
  return out.filter((x) => x.code != null || x.prose.trim());
}

const hashOf = (s) => { let h = 0; for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) | 0; return (h >>> 0).toString(36); };

function lineDiff(a, b) {
  const x = a ? a.split("\n") : [], y = b ? b.split("\n") : [];
  if (x.length * y.length > 250000) return [...x.map((l) => ["-", l]), ...y.map((l) => ["+", l])];
  const n = x.length, m = y.length;
  const dp = Array.from({ length: n + 1 }, () => new Array(m + 1).fill(0));
  for (let i = n - 1; i >= 0; i--) for (let j = m - 1; j >= 0; j--) dp[i][j] = x[i] === y[j] ? dp[i + 1][j + 1] + 1 : Math.max(dp[i + 1][j], dp[i][j + 1]);
  const out = [];
  let i = 0, j = 0;
  while (i < n && j < m) {
    if (x[i] === y[j]) { out.push([" ", x[i]]); i++; j++; }
    else if (dp[i + 1][j] >= dp[i][j + 1]) out.push(["-", x[i++]]);
    else out.push(["+", y[j++]]);
  }
  while (i < n) out.push(["-", x[i++]]);
  while (j < m) out.push(["+", y[j++]]);
  return out;
}

function diffOf(name, input) {
  const i = input ?? {};
  const pairs = name === "Edit" ? [[i.old_string, i.new_string]]
    : name === "MultiEdit" ? (i.edits ?? []).map((e) => [e.old_string, e.new_string])
    : name === "Write" ? [["", i.content]]
    : name === "NotebookEdit" ? [["", i.new_source]]
    : null;
  if (!pairs) return null;
  const lines = [];
  pairs.forEach(([a, b], k) => {
    if (k > 0) lines.push(["@", "…"]);
    lines.push(...lineDiff(String(a ?? ""), String(b ?? "")));
  });
  return { lines, add: lines.filter((l) => l[0] === "+").length, del: lines.filter((l) => l[0] === "-").length };
}

function resultText(content) {
  if (typeof content === "string") return content;
  if (Array.isArray(content)) return content.map((c) => (c?.type === "text" ? c.text : c?.type === "image" ? "[image]" : "")).join("\n");
  return "";
}

export default class Chat extends View {
  init(_props, cx) {
    this.address = props()?.terminal ?? null;
    this.on = this.address?.includes("/") ? this.address.split("/")[0] : null;
    this.local = this.address?.includes("/") ? this.address.split("/").slice(1).join("/") : this.address;
    this.file = null;
    this.offset = 0;
    this.partial = "";
    this.items = [];
    this.byMessage = new Map();
    this.tools = new Map();
    this.open = new Set();
    this.pending = [];
    this.error = null;
    this.screen = null;
    this.showAll = false;
    this.images = {};
    this.editors = new Map();
    this.scroll = ScrollHandle.new();
    this.input = TextareaState.new({ placeholder: "Message Claude… (Enter sends, Shift+Enter new line)" });
    this.input.set_auto_grow(1, 8);
    this.input.on("submit", (_e, cx) => { this.send(); cx.notify(); });
    if (checking() || !this.address) return;
    cx.timer.after(200, () => this.input.focus());
    this.locate(cx);
    cx.timer.every(1500, (cx) => this.poll(cx));
    cx.timer.every(2000, (cx) => this.pollScreen(cx));
    cx.timer.every(SEEN_EVERY, () => this.markSeen());
    cx.spawn(async (cx) => {
      for (;;) {
        const c = await nextCommand();
        if (c === "focus") this.input.focus();
        cx.notify();
      }
    });
  }

  locate(cx) {
    cx.spawn(async (cx) => {
      try {
        const r = await exec("sh", ["-c", FIND, "find", this.local], { on: this.on, timeout: 15000 });
        if (r.code === 0 && r.stdout.trim()) {
          this.file = r.stdout.trim();
          this.error = null;
          this.poll(cx, true);
        } else this.error = "Could not find this session's transcript. Is it a Claude Code agent?";
      } catch (e) {
        this.error = `Could not reach ${this.on ?? "this computer"}: ${e}`;
      }
      cx.notify();
    });
  }

  poll(cx, first = false) {
    if (!this.file || this.reading) return;
    this.reading = true;
    cx.spawn(async (cx) => {
      try {
        let from = this.offset;
        if (first) {
          const s = await exec("sh", ["-c", READ, "read", this.file, String(Number.MAX_SAFE_INTEGER)], { on: this.on });
          const size = Number(s.stdout.split("\n")[0]) || 0;
          from = Math.max(0, size - FIRST_BYTES);
        }
        const r = await exec("sh", ["-c", READ, "read", this.file, String(from)], { on: this.on, timeout: 20000 });
        if (r.code === 0) {
          const nl = r.stdout.indexOf("\n");
          const size = Number(r.stdout.slice(0, nl)) || 0;
          let body = r.stdout.slice(nl + 1);
          if (size < this.offset) { this.reset(); from = 0; }
          if (body) {
            if (first && from > 0) body = body.slice(body.indexOf("\n") + 1);
            this.ingest(this.partial + body);
            this.offset = size;
            this.stick = true;
          }
        }
      } catch {}
      this.reading = false;
      cx.notify();
    });
  }

  pollScreen(cx) {
    const a = agents().find((x) => x.address === this.address);
    const blocked = a?.status === "blocked";
    const queued = this.pending.length > 0 && a?.status === "working";
    if (!blocked && !queued) {
      if (this.screen || this.sendNowKey) { this.screen = null; this.sendNowKey = null; cx.notify(); }
      return;
    }
    cx.spawn(async (cx) => {
      const r = await hc(["read", this.address]).catch(() => null);
      const lines = (r?.stdout ?? "").split("\n").map((l) => l.replace(/\s+$/, "")).filter(Boolean);
      this.screen = blocked ? lines.slice(-16).join("\n") : null;
      const hint = lines.slice(-20).join("\n").match(/\b((?:ctrl|cmd|alt|shift|meta)\+[a-z]+|enter|tab)\b[^\n]{0,12}\bsend (?:it )?now\b/i);
      this.sendNowKey = hint ? hint[1].toLowerCase() : null;
      cx.notify();
    });
  }

  onScreen() {
    if (!window()?.active) return false;
    const mine = Object.entries(shared("chat.panes") ?? {}).find(([, t]) => t === this.address)?.[0];
    const pane = mine && panes().find((p) => p.pane === mine);
    if (!pane) return false;
    const space = spaces().find((s) => s.active);
    return Boolean(space?.tabs.some((tab) => tab.id === pane.tab && tab.active));
  }

  markSeen() {
    if (!this.onScreen()) return;
    setShared("chat.seen", { ...(shared("chat.seen") ?? {}), [this.address]: Date.now() });
  }

  reset() {
    this.items = [];
    this.byMessage.clear();
    this.tools.clear();
    this.partial = "";
    this.offset = 0;
  }

  ingest(text) {
    const lines = text.split("\n");
    this.partial = lines.pop() ?? "";
    for (const line of lines) {
      if (!line.trim()) continue;
      let e;
      try { e = JSON.parse(line); } catch { continue; }
      if (e.isSidechain) continue;
      if (e.type === "assistant") this.assistant(e);
      else if (e.type === "user") this.user(e);
    }
    if (this.items.length > KEEP) this.items = this.items.slice(-KEEP);
    this.ensureEditors();
  }

  assistant(e) {
    const id = e.message?.id ?? e.uuid;
    for (const c of e.message?.content ?? []) {
      if (c.type === "text" && c.text?.trim()) {
        const last = this.byMessage.get(id);
        if (last && this.items.at(-1) === last) last.text += "\n\n" + c.text;
        else {
          const item = { kind: "assistant", text: c.text, ts: e.timestamp, key: `${id}-${this.items.length}` };
          this.items.push(item);
          this.byMessage.set(id, item);
        }
      } else if (c.type === "tool_use") {
        const item = { kind: "tool", id: c.id, name: c.name, input: c.input, summary: toolSummary(c.name, c.input), diff: diffOf(c.name, c.input), result: null, error: false, key: c.id };
        this.items.push(item);
        this.tools.set(c.id, item);
        this.byMessage.delete(id);
      }
    }
  }

  user(e) {
    const content = e.message?.content;
    if (typeof content === "string") return this.userText(content, e);
    for (const c of content ?? []) {
      if (c.type === "tool_result") {
        const t = this.tools.get(c.tool_use_id);
        if (t) {
          t.result = resultText(c.content);
          t.stopped = Boolean(c.is_error) && REJECTED.test(t.result.trim());
          t.error = Boolean(c.is_error) && !t.stopped;
        }
      } else if (c.type === "text") this.userText(c.text, e);
      else if (c.type === "image") {
        const idx = content.indexOf(c);
        const ext = (c.source?.media_type ?? "image/png").split("/")[1]?.replace("jpeg", "jpg") ?? "png";
        this.items.push({ kind: "image", uuid: e.uuid, idx, ext, ts: e.timestamp, key: `${e.uuid}-img-${idx}` });
      }
    }
  }

  userText(text, e) {
    if (!text?.trim() || e.isMeta) return;
    const stop = text.trim().match(STOPPED);
    if (stop) return this.items.push({ kind: "stopped", forTool: Boolean(stop[1]), ts: e.timestamp, key: `${e.uuid}-stop` });
    const cmd = commandLine(text);
    if (cmd) return this.items.push({ kind: "command", text: cmd, ts: e.timestamp, key: `${e.uuid}-cmd` });
    if (SYSTEM_TAG.test(text.trim())) return;
    const clean = text.replace(/<system-reminder>[\s\S]*?<\/system-reminder>/g, "").replace(IMAGE_REF, "").trim();
    if (!clean) return;
    this.pending = this.pending.filter((p) => p.trim() !== clean.trim());
    this.items.push({ kind: "user", text: clean, ts: e.timestamp, key: `${e.uuid}-${this.items.length}` });
  }

  blockKey(item, i, code) {
    return `${item.key}:${i}:${hashOf(code)}`;
  }

  ensureEditors() {
    const t = theme();
    const wanted = new Set();
    for (const item of this.items.slice(-SHOWN)) {
      if (item.kind !== "assistant") continue;
      segments(item.text).forEach((seg, i) => {
        if (seg.code == null) return;
        const key = this.blockKey(item, i, seg.code);
        wanted.add(key);
        if (this.editors.has(key)) return;
        try {
          this.editors.set(key, EditorState.new({
            language: seg.lang, value: seg.code, readonly: true, line_numbers: false, folding: false,
            soft_wrap: false, font_size: 12, syntax: syntaxColors(t),
          }));
        } catch {}
      });
    }
    for (const [key, ed] of this.editors) if (!wanted.has(key)) { try { ed.release?.(); } catch {} this.editors.delete(key); }
  }

  codeBlock(t, key, seg) {
    const lines = seg.code.split("\n").length;
    const h = Math.min(420, lines * 18 + 14);
    const ed = this.editors.get(key);
    return v_flex().w_full().rounded(8).overflow_hidden().border_1().border_color(t.border).bg(t.chrome)
      .child(h_flex().px(10).h(22).items_center().border_b(1).border_color(t.border).text_size(10.5).text_color(t.dim).child(seg.label))
      .child(ed
        ? div().w_full().h(h).px(4).child(Editor.new(ed).size_full())
        : div().w_full().px(10).py(6).font_family(settings()?.font ?? "Menlo").text_size(12).text_color(t.foreground).child(seg.code));
  }

  assistantBody(t, item) {
    const segs = segments(item.text);
    if (!segs.some((x) => x.code != null)) return TextView.markdown(`a-${item.key}`, item.text).selectable(true);
    return v_flex().w_full().gap(8).children(segs.map((seg, i) => seg.code != null
      ? this.codeBlock(t, this.blockKey(item, i, seg.code), seg)
      : TextView.markdown(`a-${item.key}-${i}`, seg.prose).selectable(true)));
  }

  loadImage(item, cx) {
    if (this.images[item.key] || !this.file) return;
    const rel = `data/chat-images/${item.uuid}-${item.idx}.${item.ext}`;
    this.images[item.key] = { state: "loading", rel, abs: `${appHome()}/${rel}` };
    cx.spawn(async (cx) => {
      try {
        const r = await exec("sh", ["-c", IMAGE, "image", this.images[item.key].abs, this.file, item.uuid, String(item.idx), this.on ?? ""], { timeout: 30000 });
        const [w, h] = r.stdout.trim().split(/\s+/).map(Number);
        this.images[item.key] = r.code === 0 && w && h ? { ...this.images[item.key], state: "ready", w, h } : { ...this.images[item.key], state: "failed" };
      } catch {
        this.images[item.key].state = "failed";
      }
      cx.notify();
    });
  }

  thumb(t, item, cx) {
    const im = this.images[item.key];
    if (!im) this.loadImage(item, cx);
    if (!im || im.state !== "ready") {
      return div().w(THUMB_W).h(80).rounded(10).border_1().border_color(t.border).flex().items_center().justify_center().text_size(11.5).text_color(t.dim)
        .child(im?.state === "failed" ? "image unavailable" : "loading image…");
    }
    let w = THUMB_W, h = Math.round((THUMB_W * im.h) / im.w);
    if (h > THUMB_H) { w = Math.round((THUMB_H * im.w) / im.h); h = THUMB_H; }
    return div().id(`img-${item.key}`).rounded(10).overflow_hidden().border_1().border_color(t.border).cursor_pointer()
      .hover((s) => s.opacity(0.85))
      .tooltip("Open full size")
      .on_click(() => exec("open", [im.abs]).catch(() => {}))
      .child(image(im.rel).w(w).h(h));
  }

  send() {
    const text = this.input.value().replace(/\s+$/, "");
    if (!text.trim() || !this.address) return;
    this.input.set_value("");
    this.pending.push(text);
    this.stick = true;
    hc(["send", this.address, text]).catch(() => {});
  }

  keys(...k) {
    hc(["keys", this.address, ...k]).catch(() => {});
  }

  back() {
    setShared("chat.prefer", { ...(shared("chat.prefer") ?? {}), [this.address]: "terminal" });
    const mine = Object.entries(shared("chat.panes") ?? {}).find(([, t]) => t === this.address)?.[0];
    const agent = agents().find((a) => a.address === this.address);
    if (agent) run("pane.focus", { pane: agent.pane });
    if (mine) {
      const reg = { ...(shared("chat.panes") ?? {}) };
      delete reg[mine];
      setShared("chat.panes", reg);
      run("pane.close", { pane: mine });
    }
  }

  visible() {
    return this.showAll ? this.items : this.items.slice(-SHOWN);
  }

  bubble(t, item, cx) {
    if (item.kind === "stopped") {
      const when = stamp(item.ts);
      return h_flex().w_full().gap(10).items_center().py(2)
        .child(div().flex_1().h(1).bg(t.blocked + "55"))
        .child(div().flex_none().text_size(11.5).text_color(t.blocked)
          .child(`⏹ You stopped Claude${item.forTool ? " during a tool" : ""}${when ? " · " + when : ""}`))
        .child(div().flex_1().h(1).bg(t.blocked + "55"));
    }
    const body = this.bubbleBody(t, item, cx);
    const when = item.kind === "tool" ? "" : stamp(item.ts);
    if (!when) return body;
    const right = item.kind !== "assistant";
    return v_flex().w_full().gap(3)
      .child(body)
      .child(h_flex().w_full().when(right, (el) => el.justify_end()).px(4)
        .child(div().text_size(10.5).text_color(t.dim).child(when)));
  }

  bubbleBody(t, item, cx) {
    if (item.kind === "image") return h_flex().w_full().justify_end().child(this.thumb(t, item, cx));
    if (item.kind === "user") {
      return h_flex().w_full().justify_end().child(
        div().max_w_4_5().px(12).py(8).rounded(12).bg(t.accent + "2e").border_1().border_color(t.accent + "66").text_color(t.foreground)
          .child(TextView.markdown(`u-${item.key}`, item.text).selectable(true)));
    }
    if (item.kind === "command") {
      return h_flex().w_full().justify_end().child(div().px(8).py(3).rounded(6).border_1().border_color(t.border).text_size(11.5).text_color(t.muted).child(item.text));
    }
    if (item.kind === "assistant") {
      return h_flex().w_full().justify_start().child(
        div().max_w_full().mr(48).px(14).py(10).rounded(12).bg(t.ansi3 + "17").border_1().border_color(t.ansi3 + "45").text_color(t.foreground)
          .child(this.assistantBody(t, item)));
    }
    const open = this.open.has(item.key);
    const color = item.error ? t.blocked : item.stopped ? t.ansi3 : item.result == null ? t.working : t.dim;
    if (item.diff) return this.diffBlock(t, item, open, color);
    return v_flex().w_full()
      .child(h_flex().id(`tool-${item.key}`).gap(6).items_center().cursor_pointer().text_size(12).text_color(color)
        .hover((s) => s.text_color(t.foreground))
        .on_click((_e, cx) => { open ? this.open.delete(item.key) : this.open.add(item.key); cx.notify(); })
        .child(svg(`mods/workspace-chrome/chevron-${open ? "down" : "right"}.svg`).size(10).flex_none())
        .when(item.result == null, (el) => el.child(svg("mods/workspace-chrome/spinner.svg").size(10).flex_none().spin(900)))
        .child(div().flex_1().min_w(0).truncate().child(item.summary))
        .when(Boolean(item.stopped), (el) => el.child(div().flex_none().text_size(11).child("stopped"))))
      .when(open, (el) => el.child(v_flex().ml(16).mt(4).p(8).gap(6).rounded(6).bg(t.raised).text_size(11.5)
        .child(TextView.markdown(`ti-${item.key}`, "```json\n" + JSON.stringify(item.input ?? {}, null, 2).slice(0, 4000) + "\n```").selectable(true))
        .when(item.result != null, (el) => el.child(TextView.markdown(`tr-${item.key}`, "```\n" + String(item.result).slice(0, 6000) + "\n```").selectable(true)))));
  }

  diffBlock(t, item, open, color) {
    const d = item.diff;
    const mono = settings()?.font ?? "Menlo";
    const shown = open ? d.lines : d.lines.slice(0, DIFF_PREVIEW);
    const more = d.lines.length - shown.length;
    const lang = extLang(item.input?.file_path ?? item.input?.notebook_path);
    const row = ([k, text], i) => h_flex()
      .id(`dl-${item.key}-${i}`)
      .pl(6)
      .pr(8)
      .whitespace_nowrap()
      .font_family(mono)
      .text_size(11.5)
      .border_l(3)
      .border_color(k === "+" ? t.done : k === "-" ? t.blocked : "#00000000")
      .when(k === "+", (el) => el.bg(t.done + "2e"))
      .when(k === "-", (el) => el.bg(t.blocked + "2e"))
      .child(div().w(14).flex_none().font_bold().text_color(k === "+" ? t.done : k === "-" ? t.blocked : t.dim).child(k === "@" ? "…" : k === " " ? "" : k))
      .children(k === "@" ? [] : highlight(text, lang, t).map(([str, color], n) => div().text_color(color ?? (k === " " ? t.muted : t.foreground)).child(str)));
    return v_flex().w_full().gap(4)
      .child(h_flex().gap(6).items_center().text_size(12).text_color(color)
        .when(item.result == null, (el) => el.child(svg("mods/workspace-chrome/spinner.svg").size(10).flex_none().spin(900)))
        .child(div().flex_1().min_w(0).truncate().child(item.summary))
        .child(div().flex_none().text_color(t.done).child(`+${d.add}`))
        .child(div().flex_none().text_color(t.blocked).child(`−${d.del}`)))
      .child(v_flex().id(`diff-${item.key}`).w_full().py(4).rounded(6).border_1().border_color(t.border).bg(t.raised).overflow_x_scroll()
        .children(shown.map(row)))
      .when(more > 0 || open, (el) => el.child(div().id(`dm-${item.key}`).text_size(11.5).text_color(t.dim).cursor_pointer()
        .hover((s) => s.text_color(t.foreground))
        .on_click((_e, cx) => { open ? this.open.delete(item.key) : this.open.add(item.key); cx.notify(); })
        .child(open ? "show less" : `show all ${d.lines.length} lines`)))
      .when(item.error, (el) => el.child(div().text_size(11.5).text_color(t.blocked).child(String(item.result ?? "").slice(0, 300))));
  }

  render(cx) {
    const t = theme();
    const agent = agents().find((a) => a.address === this.address);
    const status = agent?.status ?? "idle";
    const title = (agent?.title ?? "").replace(/^[^\p{L}\p{N}]+/u, "") || "Claude";
    const items = this.visible();
    const hidden = this.items.length - items.length;
    const btn = (id, label, f, color) => div().id(id).px(8).h(22).rounded(6).flex().items_center().cursor_pointer().text_size(11.5)
      .border_1().border_color(t.border).text_color(color ?? t.muted).hover((s) => s.bg(t.hover).text_color(t.foreground))
      .on_click((_e, cx) => { f(); cx.notify(); }).child(label);

    const needs = status === "blocked" ? v_flex().mx(14).mb(8).p(10).gap(8).flex_none().rounded(8).border_1().border_color(t.blocked).bg(t.blocked + "14")
      .child(div().text_size(12).font_semibold().text_color(t.blocked).child("Claude needs you"))
      .when(Boolean(this.screen), (el) => el.child(TextView.markdown("needs-screen", "```\n" + this.screen + "\n```").selectable(true)))
      .child(h_flex().gap(6).flex_wrap()
        .child(btn("k1", "1", () => this.keys("1")))
        .child(btn("k2", "2", () => this.keys("2")))
        .child(btn("k3", "3", () => this.keys("3")))
        .child(btn("kenter", "Enter", () => this.keys("enter")))
        .child(btn("kesc", "Esc", () => this.keys("esc")))
        .child(btn("kterm", "Answer in terminal", () => this.back()))) : null;

    const rows = [];
    if (hidden > 0) rows.push(div().id("chat-more").text_size(11.5).text_color(t.dim).cursor_pointer().hover((s) => s.text_color(t.foreground))
      .on_click((_e, cx) => { this.showAll = true; cx.notify(); }).child(`${hidden} earlier messages`));
    if (this.error) rows.push(div().text_size(12).text_color(t.blocked).child(this.error));
    if (!this.error && !this.file) rows.push(div().text_size(12).text_color(t.dim).child("Finding the session…"));
    for (const it of items) rows.push(this.bubble(t, it, cx));
    this.pending.forEach((p, i) => rows.push(v_flex().w_full().items_end().gap(3)
      .child(div().max_w_4_5().px(12).py(8).rounded(12).bg(t.accent + "1a").border_1().border_color(t.accent + "66").text_color(t.muted).child(p))
      .child(h_flex().gap(8).items_center().px(4).text_size(10.5).text_color(t.dim)
        .child(div().px(5).h(16).flex().items_center().rounded(4).border_1().border_color(t.accent + "66").text_color(t.accent).child("Queued"))
        .child(div().child(status === "working" ? "Claude reads it at its next step" : "sending…"))
        .when(Boolean(this.sendNowKey) && i === 0, (el) => el.child(div().id("chat-send-now").px(6).h(18).flex().items_center().rounded(5)
          .cursor_pointer().bg(t.accent).text_color(t.accent_foreground).font_semibold().hover((s) => s.opacity(0.9))
          .tooltip(`Interrupts Claude's current step to read it now (${this.sendNowKey})`)
          .on_click((_e, cx) => { this.keys(this.sendNowKey); cx.notify(); })
          .child("Send now"))))));
    if (this.stick && rows.length) {
      this.scroll.scroll_to_item(rows.length - 1);
      this.stick = false;
    }
    if (status !== this.lastStatus) { this.lastStatus = status; if (rows.length) this.scroll.scroll_to_item(rows.length - 1); }
    const working = status === "working" ? h_flex().mx(18).mb(4).gap(8).flex_none().items_center().text_size(11.5).text_color(t.working)
      .child(svg("mods/workspace-chrome/spinner.svg").size(11).spin(900))
      .child(div().child("Claude is working…")) : null;

    const list = v_flex().id("chat-list").flex_1().min_h(0).px(18).py(12).gap(12).overflow_y_scroll().track_scroll(this.scroll).children(rows);

    return v_flex().id("chat").size_full().bg(t.background).text_size(13)
      .child(list)
      .when(Boolean(working), (el) => el.child(working))
      .when(Boolean(needs), (el) => el.child(needs))
      .child(h_flex().px(14).pb(12).pt(4).gap(8).flex_none().items_end()
        .child(div().flex_1().min_w(0).rounded(10).border_1().border_color(t.border).bg(t.input ?? t.raised).px(10).py(6)
          .child(Textarea.new(this.input).w_full().text_size(13).text_color(t.foreground)))
        .when(status === "working", (el) => el.child(div().id("chat-stop").h(32).px(12).rounded(9).flex().items_center().cursor_pointer()
          .border_1().border_color(t.blocked).text_color(t.blocked).text_size(12.5).font_semibold().hover((s) => s.bg(t.blocked + "1f"))
          .tooltip("Stop Claude (Esc)")
          .on_click((_e, cx) => { this.keys("esc"); cx.notify(); }).child("Stop")))
        .child(div().id("chat-send").h(32).px(12).rounded(9).flex().items_center().cursor_pointer().bg(t.accent).text_color(t.accent_foreground)
          .text_size(12.5).font_semibold().hover((s) => s.opacity(0.9))
          .on_click((_e, cx) => { this.send(); cx.notify(); }).child("Send")));
  }
}
