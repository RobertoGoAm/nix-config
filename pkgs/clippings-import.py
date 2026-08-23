"""Import e-reader clippings into the Obsidian vault, one note per book.

The Xteink X4 running CrossInk appends highlights to a Kindle-style
`My Clippings.txt`:

    ==========
    Book Title: Some Book
    Highlight Location: Page 42
    the highlighted text
    ==========

Kindle's own export uses a different second line ("- Your Highlight on page 42 |
Location 618-19 | Added on ..."), and the device's exact bytes are not something
this was written against -- so both shapes are parsed, and anything unrecognised
is reported rather than dropped. A highlight silently missing from a note is
worse than a loud parse failure.

Idempotent: each highlight carries a short content hash as an HTML comment, and
a re-import appends only hashes the note does not already have. Re-running after
every sync is therefore safe, and editing the prose around a highlight does not
cause it to be re-added.
"""

import argparse
import hashlib
import re
import sys
from datetime import date
from pathlib import Path

SEPARATOR = "=========="

# CrossInk: "Book Title: X" / "Highlight Location: Page N"
CROSSINK_TITLE = re.compile(r"^Book Title:\s*(?P<title>.+?)\s*$")
CROSSINK_LOC = re.compile(r"^Highlight Location:\s*(?P<loc>.+?)\s*$")

# Kindle: "Title (Author)" then "- Your Highlight on page 4 | Location 61-62 | ..."
KINDLE_META = re.compile(r"^[-—]\s*Your (?P<kind>\w+).*?(?P<loc>(?:page|Location)\s+[\d\-]+)", re.I)
KINDLE_TITLE = re.compile(r"^(?P<title>.+?)\s*(?:\((?P<author>[^)]+)\))?\s*$")

INVALID = re.compile(r'[<>:"/\\|?*\x00-\x1f]')


def slugify(title):
    """A filename Obsidian and the filesystem both accept, title preserved."""
    cleaned = INVALID.sub("", title).strip().rstrip(".")
    return (cleaned or "Untitled")[:120]


def digest(book, text):
    return hashlib.sha256(f"{book}\x00{text}".encode()).hexdigest()[:12]


def parse(raw):
    """Yield {book, location, text} from either export shape."""
    unparsed = []
    for block in raw.split(SEPARATOR):
        lines = [ln.rstrip("\r") for ln in block.strip("\n").split("\n")]
        lines = [ln for ln in lines if ln.strip()]
        if not lines:
            continue

        book = location = None
        body_from = 0

        m = CROSSINK_TITLE.match(lines[0])
        if m:
            book = m.group("title")
            body_from = 1
            if len(lines) > 1:
                loc = CROSSINK_LOC.match(lines[1])
                if loc:
                    location = loc.group("loc")
                    body_from = 2
        elif len(lines) > 1 and KINDLE_META.match(lines[1]):
            book = KINDLE_TITLE.match(lines[0]).group("title")
            location = KINDLE_META.match(lines[1]).group("loc")
            body_from = 2

        text = "\n".join(lines[body_from:]).strip()
        if not book or not text:
            unparsed.append(block.strip()[:120])
            continue
        yield {"book": book, "location": location, "text": text}

    if unparsed:
        for u in unparsed:
            print(f"  unparsed block: {u!r}", file=sys.stderr)


def note_path(vault, folder, book):
    return Path(vault) / folder / f"{slugify(book)}.md"


def render_header(book):
    today = date.today().isoformat()
    return (
        "---\n"
        "type: source\n"
        "status: seedling\n"
        "tags: [book, highlights, clippings]\n"
        f"created: {today}\n"
        f"lastUpdated: {today}\n"
        "---\n\n"
        f"# {book}\n\n"
        "## Highlights\n"
    )


def render(entry):
    loc = f" — {entry['location']}" if entry["location"] else ""
    marker = digest(entry["book"], entry["text"])
    quoted = "\n".join(f"> {ln}" if ln.strip() else ">" for ln in entry["text"].split("\n"))
    return f"\n{quoted}\n>\n> *{loc.lstrip(' —') or 'location unknown'}*\n<!-- clip:{marker} -->\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("clippings", help="path to My Clippings.txt (on the device or a copy)")
    ap.add_argument("--vault", required=True, help="Obsidian vault root")
    ap.add_argument("--folder", default="100 Inputs/Structured/Books",
                    help="folder inside the vault for book notes")
    ap.add_argument("--dry-run", action="store_true", help="report what would change, write nothing")
    args = ap.parse_args()

    src = Path(args.clippings)
    if not src.is_file():
        print(f"clippings-import: no file at {src}", file=sys.stderr)
        return 2

    entries = list(parse(src.read_text(errors="replace")))
    if not entries:
        print("clippings-import: nothing parsed", file=sys.stderr)
        return 2

    out_dir = Path(args.vault) / args.folder
    added = skipped = 0
    per_book = {}
    for e in entries:
        per_book.setdefault(e["book"], []).append(e)

    for book, items in sorted(per_book.items()):
        path = note_path(args.vault, args.folder, book)
        existing = path.read_text() if path.exists() else ""
        body = existing or render_header(book)
        new = []
        for e in items:
            if f"clip:{digest(book, e['text'])}" in body:
                skipped += 1
                continue
            new.append(render(e))
            added += 1
        if not new:
            continue
        # lastUpdated only moves when something is actually added.
        body = re.sub(r"^lastUpdated: .*$", f"lastUpdated: {date.today().isoformat()}",
                      body, count=1, flags=re.M)
        body = body.rstrip("\n") + "\n" + "".join(new)
        if args.dry_run:
            print(f"  would write {len(new)} new to {path.name}")
        else:
            out_dir.mkdir(parents=True, exist_ok=True)
            path.write_text(body)

    verb = "would add" if args.dry_run else "added"
    print(f"{verb} {added} highlight(s) across {len(per_book)} book(s); {skipped} already present")
    return 0


if __name__ == "__main__":
    sys.exit(main())
