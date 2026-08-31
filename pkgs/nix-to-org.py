"""Turn a .nix file into the literate .org source it tangles back from.

Comment blocks become prose under an org heading; the code between them becomes
`nix' src blocks. Round-tripping is the contract: `lit-tangle' must reproduce
the original code exactly, and the caller is expected to verify that rather
than trust this script.

The hazard this exists to handle is embedded strings. Many modules carry shell
scripts inside nix `''' quotes, and those contain `#' comments of their own.
Lifting one of those out as prose would delete a line of shell from the middle
of a script and leave a file that still builds. So the scanner tracks string
state and only ever lifts a comment that is genuinely at nix's top level.
"""

import re
import sys
from pathlib import Path

HEADING_MAX = 68


def classify(text):
    """Yield (kind, line) for each line: kind is 'comment' or 'code'.

    'comment' means the whole line is a nix comment outside any string.
    Everything else -- code, blank lines, comment-looking lines inside a
    ''-string, trailing comments after code -- is 'code' and is passed
    through untouched.
    """
    out = []
    in_multi = False   # inside ''...''
    in_str = False     # inside "..."
    for raw in text.split("\n"):
        stripped = raw.strip()
        starts_comment = (not in_multi) and (not in_str) and stripped.startswith("#")
        out.append(("comment" if starts_comment else "code", raw))

        # Advance string state across this line, ignoring a trailing comment
        # when we are not already inside a string.
        i = 0
        line = raw
        n = len(line)
        while i < n:
            two = line[i:i + 2]
            if in_multi:
                if two == "''":
                    nxt = line[i + 2:i + 3]
                    if nxt in ("'", "$", "\\"):
                        i += 3          # ''' or ''${ or ''\ -- an escape
                        continue
                    in_multi = False
                    i += 2
                    continue
                i += 1
            elif in_str:
                if line[i] == "\\":
                    i += 2
                    continue
                if line[i] == '"':
                    in_str = False
                i += 1
            else:
                if two == "''":
                    in_multi = True
                    i += 2
                    continue
                if line[i] == '"':
                    in_str = True
                    i += 1
                    continue
                if line[i] == "#":
                    break               # rest of the line is a comment
                i += 1
    return out


def heading_from(comment_lines, fallback):
    for c in comment_lines:
        t = re.sub(r"^\s*#+\s?", "", c).strip()
        if t:
            t = t.rstrip(".")
            if len(t) > HEADING_MAX:
                t = t[:HEADING_MAX].rsplit(" ", 1)[0] + "..."
            return t
    return fallback


def convert(path: Path, title: str):
    rows = classify(path.read_text())
    chunks, cur_kind, cur = [], None, []
    for kind, line in rows:
        if kind != cur_kind and cur:
            chunks.append((cur_kind, cur))
            cur = []
        cur_kind = kind
        cur.append(line)
    if cur:
        chunks.append((cur_kind, cur))

    out = [f"#+TITLE: {title}",
           "#+PROPERTY: header-args:nix :tangle (my/lit-target) :comments org :mkdirp yes",
           ""]
    pending_prose = None
    first = True
    for kind, lines in chunks:
        if kind == "comment":
            body = [re.sub(r"^\s*#+\s?", "", l).rstrip() for l in lines]
            while body and not body[0]:
                body.pop(0)
            while body and not body[-1]:
                body.pop()
            pending_prose = body
        else:
            if not "".join(lines).strip():
                continue                     # blank run between sections
            head = heading_from(pending_prose or [], title if first else "Configuration")
            out.append(f"* {head}")
            out.append("")
            if pending_prose and len(pending_prose) > 1:
                out.extend(pending_prose[1:] if pending_prose[0].rstrip(".") == head else pending_prose)
                out.append("")
            elif pending_prose and pending_prose[0].rstrip(".") != head:
                out.extend(pending_prose)
                out.append("")
            code = "\n".join(lines).strip("\n")
            out.append("#+begin_src nix")
            out.append(code)
            out.append("#+end_src")
            out.append("")
            pending_prose = None
            first = False
    return "\n".join(out).rstrip() + "\n"


if __name__ == "__main__":
    src, dst, title = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(convert(src, title))
