"""mr-size: how much review the merge request this branch would open needs.

    mr-size                     report the current branch against its base
    mr-size check [MODE]        exit 1 when over the limit (MODE: range, staged, worktree)
    mr-size json [MODE]         the full measurement, for scripts
    mr-size mr-body             the review-difficulty section for an MR description
    mr-size claude-pre          PreToolUse hook
    mr-size claude-post         PostToolUse hook

Raw line counts say little about review effort: a 500-line rename is a
minute's work, 500 lines of new logic is an afternoon. So every changed
region is parsed with tree-sitter on both sides and priced by what a
reviewer actually has to read:

    comment-only, whitespace-only     free
    a rename or literal change        once per distinct old -> new mapping
    the same refactor at many sites   in full once, one line per repeat
    a near-copy of a block already    the lines where it differs, plus one; a
      priced (>= 70% alike)             name renamed consistently throughout
                                        counts once, not on every line
    code moved unchanged              one line per move
    deleted code                      a fifth of its lines
    anything else                     its non-blank lines

and import changes follow the same rules, capped at two lines a file.

The sum is the effective size, and the limits apply to it. A raw-size
ceiling stays as a backstop, so nothing enormous passes on the strength of
the estimate alone. Files in a language without a grammar fall back to
token comparison without the syntax-aware rules.

The base is the branch this one is stacked on: branch.<name>.mrBase when
set, else the nearest local branch the current one forked from, else
origin's default branch. Lockfiles, generated output, documentation, test
data and mocks are not counted; tests are. A repository adds patterns, one
glob per line, in .mr-size-ignore, and paths whose changes are riskier to
review in .mr-size-risk.

Limits, per repository with git config:
    mrSize.maxLines      effective lines        (default 400)
    mrSize.maxFiles      files with new, rewritten, moved or deleted code
                                                (default 20; files touched only
                                                by renames, repeats, imports or
                                                comments are skimmed, not read)
    mrSize.maxRawLines   raw added + deleted    (default 2000)
    mrSize.similarity    near-copy threshold    (default 0.7)

Over a limit the hook asks the user rather than refusing, with the figures.
branch.<name>.mrSizeOverride=true stops the asking for a branch. Both are
the user's call, never the agent's.

The difficulty score next to the size is an uncalibrated estimate: weights
chosen by hand, not fitted to how reviews actually went.
"""

import ctypes
import fnmatch
import hashlib
import json
import math
import os
import re
import subprocess
import sys
from collections import Counter
from dataclasses import dataclass, field
from difflib import SequenceMatcher

IGNORE_GLOBS = [
    "**/*.lock", "**/*.lockb", "**/package-lock.json", "**/npm-shrinkwrap.json",
    "**/pnpm-lock.yaml", "**/go.sum", "**/*.snap", "**/__snapshots__/**",
    "**/*.min.js", "**/*.min.css", "**/*.map", "**/dist/**", "**/generated/**",
    "**/*.generated.*", "**/*.pb.go", "**/*_pb2.py",
    "**/*.md", "**/*.mdx", "**/*.rst", "**/*.adoc", "**/docs/**",
    "**/fixtures/**", "**/__fixtures__/**", "**/*.fixture.*", "**/*.fixtures.*",
    "**/testdata/**", "**/test-data/**", "**/test_data/**",
    "**/__mocks__/**", "**/mocks/**", "**/mock/**", "**/*.mock.*", "**/*.mocks.*",
]

RISK_GLOBS = [
    "**/migrations/**", "**/*migration*", "**/*.sql", "**/auth/**", "**/*auth*.*",
    "**/security/**", "**/payment*/**", "**/billing/**", "**/crypto/**",
    ".gitlab-ci.yml", ".gitlab/**", ".github/workflows/**", "**/Dockerfile*",
    "**/docker-compose*.y*ml", "**/nginx*.conf", "**/.env*", "**/secrets*",
]

INTERFACE_GLOBS = [
    "**/openapi*.y*ml", "**/openapi*.json", "**/swagger*.y*ml", "**/*.graphql",
    "**/*.proto", "**/*.d.ts",
]

TEST_RE = re.compile(r"(^|/)(tests?|__tests__|spec|e2e|cypress|playwright)/|\.(test|spec)\.[^/]+$|(^|/)test_[^/]+\.py$|_test\.[^/]+$")

EXTENSIONS = {
    ".ts": "typescript", ".mts": "typescript", ".cts": "typescript",
    ".tsx": "tsx", ".js": "javascript", ".mjs": "javascript", ".cjs": "javascript",
    ".jsx": "javascript", ".py": "python", ".nix": "nix", ".html": "html",
    ".htm": "html", ".css": "css", ".scss": "scss", ".vue": "vue",
}

BRANCH_TYPES = {
    "if_statement", "else_clause", "elif_clause", "switch_statement", "switch_case",
    "switch_default", "case_clause", "for_statement", "for_in_statement",
    "for_of_statement", "while_statement", "do_statement", "catch_clause",
    "except_clause", "conditional_expression", "ternary_expression",
    "if_expression", "match_statement", "case_block", "try_statement",
}
BODY_TYPES = {"statement_block", "function_body", "block", "class_body", "arrow_function"}
BOOL_OPS = {"&&", "||", "??", "and", "or"}
VUE_BRANCH_DIRECTIVES = {"v-if", "v-else-if", "v-for", "v-show"}

IDENT_RE = re.compile(r"identifier|^name$|^variable|^attr$|^class_name$|^id_name$")
LITERAL_RE = re.compile(r"string|fragment|number|integer|float|^text$|literal|escape|regex|_value$|^path")


def git(*args, check=True, binary=False, cwd=None):
    r = subprocess.run(["git", "-c", "core.quotePath=false", *args],
                       capture_output=True, cwd=cwd)
    if check and r.returncode != 0:
        raise RuntimeError(r.stderr.decode(errors="replace").strip())
    return r.stdout if binary else r.stdout.decode(errors="replace")


def git_ok(*args):
    try:
        return git(*args).strip()
    except RuntimeError:
        return ""


def config(key, default=None):
    return git_ok("config", "--get", key) or default


def int_limit(env, key, default):
    return int(os.environ.get(env) or config(key) or default)


# --- grammars ----------------------------------------------------------------

_LANGS = {}


def language(name):
    """The tree-sitter language for name, loaded straight from the grammar's
    shared library. nixpkgs' per-grammar Python wrappers all resolve their
    symbol against whichever grammar loaded first on darwin, so they are
    bypassed."""
    if name in _LANGS:
        return _LANGS[name]
    _LANGS[name] = None
    paths = json.loads(os.environ.get("MR_SIZE_GRAMMARS", "{}"))
    if name in paths:
        try:
            import tree_sitter as ts
            import warnings
            lib = ctypes.CDLL(paths[name])
            fn = getattr(lib, "tree_sitter_" + name)
            fn.restype = ctypes.c_void_p
            with warnings.catch_warnings():
                warnings.simplefilter("ignore")
                _LANGS[name] = ts.Parser(ts.Language(fn()))
        except Exception:
            pass
    return _LANGS[name]


@dataclass
class Tok:
    lo: int
    hi: int
    kind: str  # comment | ident | literal | other
    text: str
    imp: bool = False
    api: bool = False

    @property
    def abstract(self):
        return {"ident": "ID", "literal": "LIT"}.get(self.kind, self.text)


@dataclass
class Parsed:
    toks: list
    branches: int


def classify(node_type, named):
    if "comment" in node_type:
        return "comment"
    if node_type in ("directive_name", "directive_value", "directive_argument", "tag_name", "attribute_name"):
        return "other"
    if named and IDENT_RE.search(node_type):
        return "ident"
    if named and LITERAL_RE.search(node_type):
        return "literal"
    return "other"


def walk(tree_root, src, row_offset, toks, stack, counter, vue_lang_hint):
    cursor_stack = [(tree_root, stack)]
    while cursor_stack:
        node, anc = cursor_stack.pop()
        t = node.type
        if t in BRANCH_TYPES:
            counter[0] += 1
        elif t in ("binary_expression", "boolean_operator") and any(c.type in BOOL_OPS for c in node.children):
            counter[0] += 1
        elif t == "directive_name" and node.text.decode(errors="replace") in VUE_BRANCH_DIRECTIVES:
            counter[0] += 1
        # Vue embeds code three ways: <script>/<style> bodies, {{ }}
        # interpolations, and directive values (v-if="...", :prop, @event).
        embedded = t == "raw_text" or (t == "attribute_value" and "directive_attribute" in anc)
        if embedded and vue_lang_hint is not None:
            sub = vue_sublang(anc, vue_lang_hint)
            if sub and language(sub):
                sub_src = node.text
                sub_tree = language(sub).parse(sub_src)
                walk(sub_tree.root_node, sub_src, row_offset + node.start_point[0],
                     toks, anc + [t], counter, None)
                continue
        if node.child_count == 0:
            text = node.text.decode(errors="replace")
            if not text.strip():
                continue
            kind = classify(t, node.is_named)
            toks.append(Tok(
                row_offset + node.start_point[0], row_offset + node.end_point[0],
                kind, text,
                imp=any("import" in a for a in anc),
                # An exported declaration's signature, not the body behind it.
                api=any(a.startswith("export") for a in anc) and not any(a in BODY_TYPES for a in anc),
            ))
            continue
        nxt = anc + [t]
        for c in reversed(node.children):
            cursor_stack.append((c, nxt))


def vue_sublang(anc, hint):
    if "script_element" in anc:
        return hint.get("script", "typescript")
    if "style_element" in anc:
        return hint.get("style", "css")
    return "typescript"


def vue_hints(src):
    hint = {}
    m = re.search(rb"<script[^>]*\blang=[\"']?(\w+)", src)
    lang = (m.group(1).decode() if m else "js").lower()
    hint["script"] = {"ts": "typescript", "tsx": "tsx"}.get(lang, "javascript")
    m = re.search(rb"<style[^>]*\blang=[\"']?(\w+)", src)
    hint["style"] = "scss" if m and m.group(1).lower() in (b"scss", b"sass") else "css"
    return hint


def parse(path, src):
    lang = EXTENSIONS.get(os.path.splitext(path)[1].lower())
    if not lang or not language(lang) or not src:
        return None
    tree = language(lang).parse(src)
    toks, counter = [], [0]
    walk(tree.root_node, src, 0, toks, [], counter, vue_hints(src) if lang == "vue" else None)
    return Parsed(toks, counter[0])


def text_toks(lines, start):
    out = []
    for i, line in enumerate(lines):
        for m in re.finditer(r"\w+|\S", line):
            out.append(Tok(start + i, start + i, "other", m.group(0)))
    return out


# --- diff --------------------------------------------------------------------

@dataclass
class Hunk:
    path: str
    old_lo: int
    old_n: int
    new_lo: int
    new_n: int
    old_lines: list = field(default_factory=list)
    new_lines: list = field(default_factory=list)


@dataclass
class FileDiff:
    old_path: str
    new_path: str
    added: int = 0
    deleted: int = 0
    binary: bool = False
    hunks: list = field(default_factory=list)


def pathspecs(top):
    specs = [":(top)"] + [f":(top,exclude,glob){g}" for g in IGNORE_GLOBS]
    for g in read_globs(top, ".mr-size-ignore"):
        specs.append(f":(top,exclude,glob){g}")
    return specs


def read_globs(top, name):
    p = os.path.join(top, name)
    if not os.path.isfile(p):
        return []
    with open(p) as f:
        return [l.strip() for l in f if l.strip() and not l.startswith("#")]


def diff_args(mb, mode):
    return {"range": [mb, "HEAD"], "staged": ["--cached", mb], "worktree": [mb]}[mode]


def collect(top, mb, mode):
    specs = pathspecs(top)
    args = diff_args(mb, mode)
    files = {}
    raw = git("diff", "-z", "--numstat", "-M", *args, "--", *specs).split("\0")
    i = 0
    while i < len(raw):
        rec = raw[i]
        if not rec:
            i += 1
            continue
        a, d, p = rec.split("\t", 2)
        if p == "":
            old, new = raw[i + 1], raw[i + 2]
            i += 3
        else:
            old = new = p
            i += 1
        fd = FileDiff(old, new, binary=a == "-")
        if a != "-":
            fd.added, fd.deleted = int(a), int(d)
        files[new] = fd

    patch = git("diff", "-U0", "--no-color", "--no-ext-diff", "--no-prefix", "-M",
                *args, "--", *specs)
    cur = None
    hunk = None
    for line in patch.split("\n"):
        if line.startswith("diff --git "):
            cur, hunk = None, None
        elif line.startswith("+++ "):
            p = line[4:]
            cur = files.get(p) if p != "/dev/null" else None
        elif line.startswith("--- ") and cur is None:
            p = line[4:]
            if p != "/dev/null":
                cur = next((f for f in files.values() if f.old_path == p), None)
        elif line.startswith("@@") and cur is not None:
            m = re.match(r"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@", line)
            ol, on, nl, nn = int(m[1]), int(m[2] or 1), int(m[3]), int(m[4] or 1)
            hunk = Hunk(cur.new_path, ol, on, nl, nn)
            cur.hunks.append(hunk)
        elif hunk is not None and line.startswith("-"):
            hunk.old_lines.append(line[1:])
        elif hunk is not None and line.startswith("+"):
            hunk.new_lines.append(line[1:])

    if mode == "worktree":
        for p in git("ls-files", "--others", "--exclude-standard", "-z", "--", *specs).split("\0"):
            if not p:
                continue
            try:
                with open(os.path.join(top, p), "rb") as f:
                    data = f.read()
            except OSError:
                continue
            fd = FileDiff(p, p)
            if b"\0" in data[:8000]:
                fd.binary = True
            else:
                lines = data.decode(errors="replace").splitlines()
                fd.added = len(lines)
                fd.hunks.append(Hunk(p, 0, 0, 1, len(lines), [], lines))
            files[p] = fd
    return list(files.values())


def content(top, mb, mode, path, side):
    if side == "old":
        return git("show", f"{mb}:{path}", check=False, binary=True)
    if mode == "range":
        return git("show", f"HEAD:{path}", check=False, binary=True)
    if mode == "staged":
        return git("show", f":{path}", check=False, binary=True)
    try:
        with open(os.path.join(top, path), "rb") as f:
            return f.read()
    except OSError:
        return b""


# --- pricing -----------------------------------------------------------------

def side_toks(parsed, lines, lo, n):
    if n == 0:
        return []
    if parsed is None:
        return text_toks(lines, lo - 1)
    a, b = lo - 1, lo - 1 + n - 1
    return [t for t in parsed.toks if t.lo <= b and t.hi >= a]


def nonblank(lines):
    return sum(1 for l in lines if l.strip())


def key(*parts):
    return hashlib.sha1(json.dumps(parts).encode()).hexdigest()


def trim(a, b):
    i = 0
    while i < len(a) and i < len(b) and a[i] == b[i]:
        i += 1
    j = 0
    while j < len(a) - i and j < len(b) - i and a[-1 - j] == b[-1 - j]:
        j += 1
    return a[i:len(a) - j], b[i:len(b) - j]


def matches(path, globs):
    return any(fnmatch.fnmatch(path, g) or fnmatch.fnmatch(path, g.removeprefix("**/")) for g in globs)


def analyse(top, mb, mode, similarity=0.7):
    files = collect(top, mb, mode)
    risk_globs = RISK_GLOBS + read_globs(top, ".mr-size-risk")
    records = []
    branch_delta = 0
    exports = set()
    for fd in files:
        if fd.binary or not fd.hunks:
            continue
        old_p = parse(fd.old_path, content(top, mb, mode, fd.old_path, "old")) if any(h.old_n for h in fd.hunks) else None
        new_p = parse(fd.new_path, content(top, mb, mode, fd.new_path, "new")) if any(h.new_n for h in fd.hunks) else None
        syntax = (old_p or new_p) is not None
        branch_delta += max(0, (new_p.branches if new_p else 0) - (old_p.branches if old_p else 0))
        for h in fd.hunks:
            o = side_toks(old_p if syntax else None, h.old_lines, h.old_lo, h.old_n if h.old_lines else 0)
            n = side_toks(new_p if syntax else None, h.new_lines, h.new_lo, h.new_n if h.new_lines else 0)
            # Changed or removed existing exports; new ones break no caller.
            if any(t.api for t in o):
                exports.add(fd.new_path)
            records.append(classify_hunk(fd, h, o, n, syntax))

    # Moves: a removed block that reappears unchanged elsewhere.
    dels = {}
    for r in records:
        if r["cat"] == "deleted":
            dels.setdefault(r["concrete"], []).append(r)
    for r in records:
        if r["cat"] == "new" and dels.get(r["concrete"]):
            d = dels[r["concrete"]].pop()
            d["cat"] = "moved-away"
            r["cat"] = "moved"

    seen_pairs, seen_shapes = set(), set()
    near = NearCopies(similarity)
    near_copies = []
    import_cost = {}
    cats = {}
    per_file = {}
    read_files = set()
    for r in records:
        c, cost = r["cat"], 0
        if c in ("comment", "whitespace", "moved-away"):
            cost = 0
        elif c == "moved":
            cost = 1
        elif c == "deleted":
            cost = math.ceil(r["lines"] / 5)
        elif c == "rename":
            new = [p for p in r["pairs"] if p not in seen_pairs]
            seen_pairs.update(new)
            cost = len(new)
        elif c in ("new", "changed"):
            if r["shape"] in seen_shapes:
                c, cost = "repeat", 1
            else:
                cost = r["lines"]
                m = near.match(r)
                if m:
                    ratio, prior, ops = m
                    nc_cost, check = near_cost(prior["seq"], r["seq"], ops)
                    if nc_cost < cost:
                        c, cost = "near-copy", nc_cost
                        near_copies.append({
                            "block": f"{r['path']}:{r['range'][0]}-{r['range'][1]}",
                            "of": f"{prior['path']}:{prior['range'][0]}-{prior['range'][1]}",
                            "alike": round(100 * ratio), "check": ranges(check),
                        })
                if c != "near-copy":
                    seen_shapes.add(r["shape"])
            near.add(r)
        if r.get("imports") and c not in ("comment", "whitespace"):
            c = "imports"
            cost = min(cost, max(0, 2 - import_cost.get(r["path"], 0)))
            import_cost[r["path"]] = import_cost.get(r["path"], 0) + cost
        if c in ("changed", "new", "near-copy", "moved", "deleted"):
            read_files.add(r["path"])
        r["cat"], r["cost"] = c, cost
        e = cats.setdefault(c, {"raw": 0, "cost": 0, "count": 0})
        e["raw"] += r["raw"]
        e["cost"] += cost
        e["count"] += 1
        per_file[r["path"]] = per_file.get(r["path"], 0) + cost

    effective = sum(per_file.values())
    costly = [p for p, c in per_file.items() if c > 0]
    read = [p for p in costly if p in read_files]
    test_cost = sum(c for p, c in per_file.items() if TEST_RE.search(p))
    code_cost = effective - test_cost
    areas = sorted({"/".join(os.path.dirname(p).split("/")[:2]) or "." for p in costly})
    risk = sorted({p for p in costly if matches(p, risk_globs)})
    interface = sorted(exports | {p for p in costly if matches(p, INTERFACE_GLOBS)})
    shapes = len(seen_shapes) + (1 if seen_pairs else 0)

    return {
        "raw_lines": sum(f.added + f.deleted for f in files),
        "raw_files": len(files),
        "effective": effective,
        "files": len(read),
        "skimmed_files": len(costly) - len(read),
        "categories": cats,
        "shapes": shapes,
        "renames": len(seen_pairs),
        "branches": branch_delta,
        "areas": areas,
        "risk": risk,
        "interface": interface,
        "test_cost": test_cost,
        "code_cost": code_cost,
        "near_copies": near_copies,
        "largest": sorted(per_file.items(), key=lambda kv: -kv[1])[:10],
        "difficulty": difficulty(effective, shapes, branch_delta, areas, interface, risk,
                                 test_cost, code_cost, len(near_copies)),
    }


def classify_hunk(fd, h, o, n, syntax):
    base = {"path": fd.new_path, "raw": len(h.old_lines) + len(h.new_lines),
            "lines": nonblank(h.old_lines) + nonblank(h.new_lines)}
    onc = [t for t in o if t.kind != "comment"]
    nnc = [t for t in n if t.kind != "comment"]
    ot, nt = [t.text for t in onc], [t.text for t in nnc]
    if ot == nt:
        changed_comments = [t.text for t in o if t.kind == "comment"] != [t.text for t in n if t.kind == "comment"]
        return {**base, "cat": "comment" if changed_comments else "whitespace"}
    imports = bool(syntax and onc + nnc and all(t.imp for t in onc + nnc))
    oa, na = [t.abstract for t in onc], [t.abstract for t in nnc]
    base["imports"] = imports
    if not h.new_lines and not imports:
        return {**base, "cat": "deleted", "concrete": key(ot)}
    if not h.old_lines and not imports:
        # New code dedupes only when it is a verbatim copy: the same structure
        # calling different things is still different code to read.
        return {**base, "cat": "new", "concrete": key(nt), "shape": key("add", nt),
                "seq": seq(nnc, "n"), "range": (h.new_lo, h.new_lo + h.new_n - 1)}
    if syntax and oa == na:
        pairs = sorted({(a, b) for a, b in zip(ot, nt) if a != b})
        return {**base, "cat": "rename", "pairs": [tuple(p) for p in pairs]}
    # The refactor's shape: what changed, with the names it merely carries
    # through abstracted, and the names it introduces kept, so wrapping
    # values in f() at many sites is one refactor but wrapping them in f()
    # here and g() there is two.
    old_names = {t.text for t in onc if t.kind == "ident"}
    ns = ["ID" if t.kind == "ident" and t.text in old_names else t.abstract if t.kind == "literal" else t.text for t in nnc]
    to, tn = trim(oa, ns)
    return {**base, "cat": "changed", "shape": key("chg", to, tn), "concrete": key(ot, nt),
            "seq": seq(onc, "o") + [("->", "->", "x", -1)] + seq(nnc, "n"),
            "range": (h.new_lo, h.new_lo + max(h.new_n, 1) - 1)}


def seq(toks, side):
    return [(t.abstract, t.text, side, t.lo + 1) for t in toks]


# --- near-copies -------------------------------------------------------------
#
# A block that is mostly like one already priced is read as "like that one,
# except here", so it costs the lines where it differs. Candidates are found
# by shared 5-token shingles of the structure (names and literals as
# placeholders), so blocks are not all compared pairwise; the best few are
# then aligned token by token. Within the aligned stretches the real names
# are compared: one renamed the same way at least twice and nowhere else is
# a systematic rename and costs once; any other differing name or literal
# (save() here, delete() there) charges its line, because that is exactly
# where a copy-paste slip hides.

SHINGLE = 5
MIN_TOKENS = 15


def shingles(sq):
    a = [t[0] for t in sq]
    return {tuple(a[i:i + SHINGLE]) for i in range(max(1, len(a) - SHINGLE + 1))}


class NearCopies:
    def __init__(self, threshold):
        self.threshold = threshold
        self.blocks = []
        self.index = {}

    def match(self, r):
        sq = r.get("seq") or []
        if len(sq) < MIN_TOKENS:
            return None
        votes = Counter(i for sh in shingles(sq) for i in self.index.get(sh, ()))
        best = None
        for i, _ in votes.most_common(3):
            prior = self.blocks[i]
            sm = SequenceMatcher(None, [t[0] for t in prior["seq"]], [t[0] for t in sq], autojunk=False)
            ratio = sm.ratio()
            if ratio >= self.threshold and (best is None or ratio > best[0]):
                best = (ratio, prior, sm.get_opcodes())
        return best

    def add(self, r):
        sq = r.get("seq") or []
        if len(sq) < MIN_TOKENS:
            return
        self.blocks.append(r)
        for sh in shingles(sq):
            self.index.setdefault(sh, set()).add(len(self.blocks) - 1)


def near_cost(prior, cur, opcodes):
    """Lines of cur a reviewer must check against prior, and how many
    systematic renames there are."""
    charged = set()
    pairs = []
    for tag, i1, i2, j1, j2 in opcodes:
        if tag == "equal":
            pairs += [(a, b) for a, b in zip(prior[i1:i2], cur[j1:j2]) if a[1] != b[1]]
        elif j1 < j2:
            charged.update((t[2], t[3]) for t in cur[j1:j2])
        elif cur:
            t = cur[min(j1, len(cur) - 1)]
            charged.add((t[2], t[3]))
    counts = Counter((a[1], b[1]) for a, b in pairs)
    targets = {}
    for (a, b) in counts:
        targets.setdefault(a, set()).add(b)
    systematic = {(a, b) for (a, b), n in counts.items() if n >= 2 and len(targets[a]) == 1}
    charged.update((b[2], b[3]) for a, b in pairs if (a[1], b[1]) not in systematic)
    charged = {c for c in charged if c[0] != "x"}
    check = sorted({line for side, line in charged if side == "n"})
    return len(charged) + len(systematic) + 1, check


def ranges(nums):
    out, start, prev = [], None, None
    for n in nums:
        if start is None:
            start = prev = n
        elif n == prev + 1:
            prev = n
        else:
            out.append(f"{start}" if start == prev else f"{start}-{prev}")
            start = prev = n
    if start is not None:
        out.append(f"{start}" if start == prev else f"{start}-{prev}")
    return ", ".join(out)


def difficulty(effective, shapes, branches, areas, interface, risk, test_cost, code_cost, near):
    # Many near-copies are cheap to read but are duplication a reviewer may
    # want folded into a helper: a nudge, not a size.
    points = (effective / 50 + min(10, shapes) * 0.5 + min(5, branches / 10)
              + min(4, max(0, len(areas) - 1)) + (2 if interface else 0)
              + min(6, 3 * len(risk)) + min(3, near * 0.5))
    untested = code_cost > 50 and test_cost < 0.2 * code_cost
    if untested:
        points += 2
    band = "S" if points < 5 else "M" if points < 10 else "L" if points < 20 else "XL"
    minutes = max(5, round(effective / 5 + 2 * min(15, shapes) + min(30, branches / 3)))
    return {"band": band, "points": round(points, 1), "minutes": minutes, "untested": untested}


# --- base resolution ---------------------------------------------------------

def default_branch():
    ref = git_ok("symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD")
    if ref:
        return ref
    for b in ("main", "master", "develop"):
        if git_ok("rev-parse", "--verify", "--quiet", f"refs/heads/{b}"):
            return b
    return ""


def resolve_base(branch):
    head = git_ok("rev-parse", "HEAD")
    explicit = config(f"branch.{branch}.mrBase")
    if explicit:
        return explicit, git_ok("merge-base", explicit, "HEAD")
    d = default_branch()
    if branch == d.removeprefix("origin/") and git_ok("rev-parse", "--verify", "--quiet", "@{u}"):
        return git_ok("rev-parse", "--abbrev-ref", "@{u}"), git_ok("merge-base", "@{u}", "HEAD")
    cands = git_ok("for-each-ref", "--format=%(refname:short)", "refs/heads").splitlines()
    if d:
        cands.append(d)
    best = None
    for c in cands:
        if c == branch:
            continue
        mb = git_ok("merge-base", c, "HEAD")
        if not mb:
            continue
        # A branch stacked on this one contains HEAD; it is not what this
        # branch forked from. One still sitting at HEAD is: nothing committed yet.
        if mb == head and git_ok("rev-parse", c) != mb:
            continue
        n = int(git_ok("rev-list", "--count", f"{mb}..HEAD") or 0)
        # On a tie, a branch whose tip is the fork point (what this one was
        # cut from) beats a sibling that has moved on, and the default branch
        # beats both.
        rank = (n, git_ok("rev-parse", c) != mb, c != d)
        if best is None or rank < best[0]:
            best = (rank, c, mb)
    return (best[1], best[2]) if best else ("HEAD", head)


@dataclass
class Measure:
    branch: str
    base: str
    m: dict
    max_lines: int
    max_files: int
    max_raw: int

    @property
    def over(self):
        return (self.m["effective"] > self.max_lines or self.m["files"] > self.max_files
                or self.m["raw_lines"] > self.max_raw)

    @property
    def exempt(self):
        if self.branch == "HEAD":
            return True
        if config(f"branch.{self.branch}.mrSizeOverride", "").lower() == "true":
            return True
        # Work committed straight to the default branch opens no MR.
        return self.branch == default_branch().removeprefix("origin/")


def measure(mode):
    top = git("rev-parse", "--show-toplevel").strip()
    os.chdir(top)
    branch = git_ok("symbolic-ref", "--quiet", "--short", "HEAD") or "HEAD"
    base, mb = resolve_base(branch)
    return Measure(branch, base, analyse(top, mb, mode, float(config("mrSize.similarity", "0.7"))),
                   int_limit("MR_SIZE_MAX_LINES", "mrSize.maxLines", 400),
                   int_limit("MR_SIZE_MAX_FILES", "mrSize.maxFiles", 20),
                   int_limit("MR_SIZE_MAX_RAW_LINES", "mrSize.maxRawLines", 2000))


# --- wording -----------------------------------------------------------------

CAT_LABEL = {
    "changed": "new or rewritten logic", "new": "new code", "repeat": "repeated refactor",
    "rename": "renames / literal changes", "imports": "imports", "comment": "comments",
    "whitespace": "formatting", "moved": "moved code", "moved-away": "moved code (source)",
    "deleted": "deleted code", "near-copy": "near-copies",
}


def breakdown(m):
    parts = []
    for c, e in sorted(m["categories"].items(), key=lambda kv: -kv[1]["raw"]):
        if c == "moved-away" or not e["raw"]:
            continue
        extra = f", {m['renames']} mappings" if c == "rename" else f", x{e['count']}" if c == "repeat" else ""
        parts.append(f"{e['raw']} {CAT_LABEL[c]} (costs {e['cost']}{extra})")
    return "; ".join(parts)


def summary(x):
    m = x.m
    return (f"{x.branch} vs {x.base}: {m['effective']} effective lines, {m['files']} files to read "
            f"(+{m['skimmed_files']} to skim) "
            f"({m['raw_lines']} raw lines in {m['raw_files']} files; limits {x.max_lines} effective / "
            f"{x.max_files} files / {x.max_raw} raw; lockfiles, generated files, docs, test data "
            f"and mocks not counted)")


def split_advice(x):
    largest = "\n".join(f"  {c:6d}  {p}" for p, c in x.m["largest"])
    return f"""Breakdown: {breakdown(x.m)}.
Largest by review cost:
{largest}{near_lines(x.m)}
If the change is mechanical beyond what the breakdown already discounts (a vendored drop, a codemod), it is reviewable as it stands: say so to the user and let them approve it. Never set branch.{x.branch}.mrSizeOverride yourself.
Otherwise reviewers should get it as several MRs of at most {x.max_lines} effective lines / {x.max_files} files each, and every one must pass CI on its own, because each is pipelined and merged separately:
  - cut along dependencies, foundations first: types, schemas, migrations, helpers and their tests land before the code that uses them
  - tests travel with the code they test, never in a later MR
  - an unused-but-tested piece is fine; a piece that only compiles once the next MR lands is not; code that would be half-wired goes behind a flag or stays in the later MR
  - independent pieces: one branch each off {x.base}; dependent pieces: a stack, each branch off the previous one, with the parent recorded so each link is measured alone:
      git switch -c <next> && git config branch.<next>.mrBase <previous>
  - move commits already made with git switch -c <part> <base> && git cherry-pick <commits>, or git rebase --onto
  - before pushing each branch, run what CI runs (see the project's CI config: lint, typecheck, tests, build) on that branch alone
If no split keeps every MR green, do not force one: tell the user why and let them approve the larger MR."""


def near_lines(m):
    if not m["near_copies"]:
        return ""
    return "\nNear-copies (consider a shared helper before splitting):\n" + "\n".join(
        f"  {n['block']} ~ {n['of']} ({n['alike']}%), differs at {n['check'] or 'a rename'}" for n in m["near_copies"][:10])


MARKER = "<!-- mr-size -->"


def mr_body(x):
    m, d = x.m, x.m["difficulty"]
    rows = [
        ("Effective size", f"{m['effective']} lines, {m['files']} files to read, {m['skimmed_files']} to skim ({m['raw_lines']} raw lines, {m['raw_files']} files)"),
        ("Breakdown", breakdown(m) or "-"),
        ("Distinct change shapes", str(m["shapes"])),
        ("Branching logic added", f"+{m['branches']}"),
        ("Areas touched", ", ".join(f"`{a}`" for a in m["areas"]) or "-"),
        ("Interface changes", ", ".join(f"`{p}`" for p in m["interface"]) or "none"),
        ("Risk paths", ", ".join(f"`{p}`" for p in m["risk"]) or "none"),
        ("Tests", f"{m['test_cost']} of {m['effective']} effective lines" + (" (code looks under-tested)" if d["untested"] else "")),
    ]
    if m["near_copies"]:
        shown = [f"`{n['block']}` follows `{n['of']}` ({n['alike']}% alike), check {n['check'] or 'the rename'}"
                 for n in m["near_copies"][:5]]
        more = len(m["near_copies"]) - len(shown)
        rows.append(("Near-copies (review the differences)", "<br>".join(shown) + (f"<br>and {more} more" if more > 0 else "")))
    table = "\n".join(f"| {k} | {v} |" for k, v in rows)
    return f"""{MARKER}
### Review difficulty: {d['band']} (about {d['minutes']} min)

| | |
|---|---|
{table}

<sub>Measured by mr-size against `{x.base}`: changes are parsed and repeated, mechanical or moved edits discounted. The difficulty is an uncalibrated estimate.</sub>"""


def mr_instructions(x, tool):
    d = x.m["difficulty"]
    body = mr_body(x)
    label = f"difficulty::{d['band']}"
    how = {
        "glab": f'Put the section at the end of --description, and add --label "{label}".',
        "gh": "Put the section at the end of --body (or the --body-file).",
        "df": f"df mr-generate writes the description itself: once the MR exists, append the section with glab mr update <iid> --description \"<existing description>\n\n<section>\" and add the label with glab mr update <iid> --label \"{label}\".",
    }[tool]
    return f"Review-difficulty section for this MR (difficulty {d['band']}, about {d['minutes']} min). {how}\n\n{body}"


# --- hooks -------------------------------------------------------------------

GIT_RE = r"(^|[;&|(]\s*|^\s*)(rtk\s+)?git(\s+-C\s+\S+)?\s+"
MR_RES = {
    "glab": re.compile(r"glab\s+mr\s+create"),
    "gh": re.compile(r"gh\s+pr\s+create"),
    "df": re.compile(r"\bdf\s+mr-generate"),
}


def hook_dir(cmd, cwd):
    m = re.match(r"\s*cd\s+(\"([^\"]+)\"|([^\s;&|]+))", cmd) or re.search(r"git\s+-C\s+(\"([^\"]+)\"|([^\s;&|]+))", cmd)
    if not m:
        return cwd
    d = os.path.expanduser(m.group(2) or m.group(3))
    return d if os.path.isabs(d) else os.path.join(cwd, d)


def in_repo(d):
    try:
        os.chdir(d)
    except OSError:
        return False
    return bool(git_ok("rev-parse", "--git-dir"))


def body_has_marker(cmd, cwd):
    if MARKER in cmd or "Review difficulty" in cmd:
        return True
    m = re.search(r"(?:--body-file|--description-file|-F)\s+(\"[^\"]+\"|\S+)", cmd)
    if m:
        p = os.path.join(cwd, os.path.expanduser(m.group(1).strip('"')))
        try:
            with open(p) as f:
                return MARKER in f.read()
        except OSError:
            pass
    return False


def emit(**out):
    print(json.dumps({"hookSpecificOutput": out}))


def claude_pre():
    inp = json.load(sys.stdin)
    cmd = inp.get("tool_input", {}).get("command", "")
    cwd = inp.get("cwd", "")
    mr_tool = next((t for t, r in MR_RES.items() if r.search(cmd)), None)
    if mr_tool or re.search(GIT_RE + r"push(\s|$)", cmd):
        # Deleting a remote branch or pushing tags opens no MR.
        if not mr_tool and re.search(r"--delete|--tags|\s:\S", cmd):
            return
        mode = "range"
    elif re.search(GIT_RE + r"commit(\s|$)", cmd):
        # commit -a carries every tracked edit, not just the index.
        mode = "worktree" if re.search(GIT_RE + r"commit[^;&|]*\s(-[a-zA-Z]*a[a-zA-Z]*|--all)(\s|$)", cmd) else "staged"
    else:
        return
    d = hook_dir(cmd, cwd)
    if not in_repo(d):
        return
    x = measure(mode)
    if mr_tool in ("glab", "gh") and not body_has_marker(cmd, d) and x.branch != "HEAD":
        emit(hookEventName="PreToolUse", permissionDecision="deny",
             permissionDecisionReason="MR size: include the review-difficulty section in the MR description, then retry.\n" + mr_instructions(x, mr_tool))
        return
    if x.exempt or not x.over:
        if mr_tool == "df":
            emit(hookEventName="PreToolUse", additionalContext=mr_instructions(x, "df"))
        return
    # The user sees the reason in the permission prompt; the agent gets the
    # advice, so a refusal leads to a split rather than a retry.
    ctx = f"MR size gate: {summary(x)}. The user is being asked whether to allow it. If they deny, split the work.\n{split_advice(x)}"
    if mr_tool == "df":
        ctx += "\n\n" + mr_instructions(x, "df")
    emit(hookEventName="PreToolUse", permissionDecision="ask",
         permissionDecisionReason=(f"MR size gate: {summary(x)}. {breakdown(x.m)}. "
                                   f"Approve if it is reviewable as one MR (to stop asking for this branch: "
                                   f"git config branch.{x.branch}.mrSizeOverride true); deny to have it split."),
         additionalContext=ctx)


def claude_post():
    """After an edit or a commit, tell the agent the moment the work in
    progress outgrows one MR, and again only each time it grows past another
    multiple of the limit, so a long refactor is not nagged on every edit."""
    inp = json.load(sys.stdin)
    ti = inp.get("tool_input", {})
    if inp.get("tool_name") == "Bash":
        cmd = ti.get("command", "")
        if not re.search(GIT_RE + r"commit(\s|$)", cmd):
            return
        d, mode = hook_dir(cmd, inp.get("cwd", "")), "range"
    else:
        d, mode = os.path.dirname(ti.get("file_path") or ti.get("notebook_path") or ""), "worktree"
    if not d or not in_repo(d):
        return
    x = measure(mode)
    if x.exempt:
        return
    state = git("rev-parse", "--git-path", "mr-size-warned").strip()
    band = max(x.m["effective"] // x.max_lines, x.m["files"] // x.max_files, x.m["raw_lines"] // x.max_raw)
    seen = {}
    if os.path.exists(state):
        with open(state) as f:
            seen = dict(l.rstrip("\n").rsplit(" ", 1) for l in f if " " in l)
    prev = int(seen.get(x.branch, 0))
    seen[x.branch] = str(band)
    with open(state + ".tmp", "w") as f:
        f.writelines(f"{k} {v}\n" for k, v in seen.items())
    os.replace(state + ".tmp", state)
    if not x.over or band <= prev:
        return
    emit(hookEventName="PostToolUse",
         additionalContext=(f"MR size gate: the work in progress is already more than one MR. {summary(x)}. "
                            f"Commits, pushes and MR creation on this branch will need the user's approval.\n{split_advice(x)}"))


def report():
    c = measure("range")
    w = measure("worktree")
    print(f"committed:        {summary(c)}")
    print(f"with uncommitted: {summary(w)}")
    print(f"breakdown:        {breakdown(w.m) or '-'}")
    d = w.m["difficulty"]
    print(f"difficulty:       {d['band']} (about {d['minutes']} min, {d['points']} points; uncalibrated)")
    if w.over:
        print()
        print(split_advice(w))


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "report"
    mode = sys.argv[2] if len(sys.argv) > 2 else "range"
    try:
        if cmd == "report":
            report()
        elif cmd == "check":
            x = measure(mode)
            print(summary(x))
            sys.exit(1 if x.over and not x.exempt else 0)
        elif cmd == "json":
            x = measure(mode)
            print(json.dumps({"branch": x.branch, "base": x.base, **x.m}, indent=2))
        elif cmd == "mr-body":
            print(mr_body(measure(mode)))
        elif cmd == "claude-pre":
            claude_pre()
        elif cmd == "claude-post":
            claude_post()
        else:
            print(__doc__.split("\n\n")[1], file=sys.stderr)
            sys.exit(64)
    except RuntimeError as e:
        # Hooks never break a turn over a repository they cannot read.
        if cmd.startswith("claude-"):
            sys.exit(0)
        print(f"mr-size: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
