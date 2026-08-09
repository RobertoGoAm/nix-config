"""Report — and optionally fix — drift on the version pins nothing updates here.

flake.lock covers every nixpkgs package and warpd rides prev.warpd.src, so both
move on `nix-update`. Two things do not:

  * the Chromium snapshot in overlays/apple-silicon-chromium.nix, checked
    against the LAST_CHANGE marker in Google's Mac_Arm snapshot bucket
  * every marketplace extension pinned by version + sha256 in the VS Code
    module, checked against the Visual Studio Marketplace gallery API

Default is read-only. `--update` rewrites the stale pins in place, refreshing
both the version and its hash. `--quiet` prints nothing unless something is
behind, which is how the shell aliases call it.

Exit codes: 0 current, 1 drift found (or fixed), 2 a lookup or fetch failed.
"""

import argparse
import concurrent.futures
import json
import re
import subprocess
import sys
from pathlib import Path

CHROMIUM_OVERLAY = Path("overlays/apple-silicon-chromium.nix")
VSCODE_MODULE = Path("modules/home-manager/features/development/vscode/default.nix")

SNAPSHOT_BUCKET = "https://storage.googleapis.com/chromium-browser-snapshots/Mac_Arm"
# Chromium mainline advances on the order of a thousand revisions a week, so a
# freshly bumped pin is "behind" within hours and an exact comparison would
# report stale permanently. A milestone is roughly four weeks of commits; this
# threshold means "about a release behind", which is the point at which the
# bump is actually worth doing.
SNAPSHOT_DRIFT_THRESHOLD = 5000

MARKETPLACE_QUERY = (
    "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery"
)
VSIX_URL = (
    "https://{publisher}.gallery.vsassets.io/_apis/public/gallery/publisher/"
    "{publisher}/extension/{name}/{version}/assetbyname/"
    "Microsoft.VisualStudio.Services.VSIXPackage"
)

# The module writes these blocks in both field orders.
EXTENSION_BLOCK = re.compile(
    r'\{\s*(?:name = "(?P<n1>[^"]+)";\s*publisher = "(?P<p1>[^"]+)";'
    r'|publisher = "(?P<p2>[^"]+)";\s*name = "(?P<n2>[^"]+)";)'
    r'\s*version = "(?P<version>[^"]+)";'
    r'\s*sha256 = "(?P<sha256>[^"]+)";',
    re.MULTILINE,
)


def run(cmd, stdin=None):
    result = subprocess.run(cmd, capture_output=True, text=True, input=stdin)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"{cmd[0]} exited {result.returncode}")
    return result.stdout


def fetch(url, data=None):
    cmd = ["curl", "-sS", "--max-time", "30", url]
    if data is not None:
        cmd += [
            "-X", "POST",
            "-H", "Content-Type: application/json",
            "-H", "Accept: application/json;api-version=7.1-preview.1",
            "-d", data,
        ]
    return run(cmd)


def prefetch_sri(url):
    """Download url and return its hash in SRI form, as the nix files spell it."""
    base32 = run(["nix-prefetch-url", "--type", "sha256", url]).strip().splitlines()[-1]
    return run(["nix", "hash", "to-sri", "--type", "sha256", base32]).strip()


def latest_extension_version(extension_id):
    body = json.dumps(
        {
            "filters": [{"criteria": [{"filterType": 7, "value": extension_id}]}],
            "flags": 914,
        }
    )
    payload = json.loads(fetch(MARKETPLACE_QUERY, body))
    return payload["results"][0]["extensions"][0]["versions"][0]["version"]


def parse_extension_pins(text):
    for match in EXTENSION_BLOCK.finditer(text):
        yield {
            "name": match.group("n1") or match.group("n2"),
            "publisher": match.group("p1") or match.group("p2"),
            "version": match.group("version"),
            "sha256": match.group("sha256"),
            "span": match.span(),
        }


def check_chromium(root):
    overlay = root / CHROMIUM_OVERLAY
    if not overlay.exists():
        return {"status": "skip", "subject": "chromium", "detail": f"{CHROMIUM_OVERLAY} not found"}
    pinned = re.search(r'version = "(\d+)";', overlay.read_text())
    if not pinned:
        return {"status": "error", "subject": "chromium", "detail": "no version pin in the overlay"}
    latest = fetch(f"{SNAPSHOT_BUCKET}/LAST_CHANGE").strip()
    current = pinned.group(1)
    behind = int(latest) - int(current)
    if behind < SNAPSHOT_DRIFT_THRESHOLD:
        # Not "current" — it never is — but not worth acting on either.
        return {
            "status": "ok",
            "subject": "chromium snapshot",
            "detail": f"{current} ({behind} revisions behind, under threshold)",
        }
    return {
        "status": "stale",
        "subject": "chromium snapshot",
        "detail": f"{current} -> {latest} ({behind} revisions behind)",
        "kind": "chromium",
        "from": current,
        "to": latest,
    }


def check_extension(pin):
    extension_id = f"{pin['publisher']}.{pin['name']}"
    try:
        latest = latest_extension_version(extension_id)
    except Exception as exc:  # noqa: BLE001 - one bad lookup must not sink the sweep
        return {"status": "error", "subject": extension_id, "detail": str(exc)}
    if latest == pin["version"]:
        return {"status": "ok", "subject": extension_id, "detail": pin["version"]}
    return {
        "status": "stale",
        "subject": extension_id,
        "detail": f"{pin['version']} -> {latest}",
        "kind": "extension",
        "pin": pin,
        "to": latest,
    }


def collect(root):
    module = root / VSCODE_MODULE
    pins = list(parse_extension_pins(module.read_text())) if module.exists() else []
    # The lookups are all independent network round trips; sequentially they cost
    # a few seconds, which is too much to put in front of every rebuild.
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        chromium = pool.submit(check_chromium, root)
        extensions = list(pool.map(check_extension, pins))
        report = [chromium.result()] + extensions
    if not module.exists():
        report.append({"status": "skip", "subject": "extensions", "detail": f"{VSCODE_MODULE} not found"})
    return report


def apply_updates(root, stale):
    """Rewrite stale pins in place, refreshing each hash alongside its version."""
    fixed, failed = [], []

    extensions = [row for row in stale if row.get("kind") == "extension"]
    if extensions:
        path = root / VSCODE_MODULE
        text = path.read_text()
        # Rewrite back to front so earlier spans stay valid as the text shifts.
        for row in sorted(extensions, key=lambda r: r["pin"]["span"][0], reverse=True):
            pin, new_version = row["pin"], row["to"]
            url = VSIX_URL.format(publisher=pin["publisher"], name=pin["name"], version=new_version)
            try:
                new_hash = prefetch_sri(url)
            except Exception as exc:  # noqa: BLE001
                failed.append((row["subject"], str(exc)))
                continue
            start, end = pin["span"]
            block = text[start:end]
            block = block.replace(f'version = "{pin["version"]}";', f'version = "{new_version}";')
            block = block.replace(f'sha256 = "{pin["sha256"]}";', f'sha256 = "{new_hash}";')
            text = text[:start] + block + text[end:]
            fixed.append(f"{row['subject']} {pin['version']} -> {new_version}")
        path.write_text(text)

    for row in [r for r in stale if r.get("kind") == "chromium"]:
        path = root / CHROMIUM_OVERLAY
        text = path.read_text()
        try:
            new_hash_sri = prefetch_sri(f"{SNAPSHOT_BUCKET}/{row['to']}/chrome-mac.zip")
            # The overlay spells this one as a bare base32 sha256.
            new_hash = run(["nix", "hash", "to-base32", "--type", "sha256", new_hash_sri]).strip()
        except Exception as exc:  # noqa: BLE001
            failed.append((row["subject"], str(exc)))
            continue
        old_hash = re.search(r'sha256 = "([^"]+)";', text).group(1)
        text = text.replace(f'version = "{row["from"]}";', f'version = "{row["to"]}";')
        text = text.replace(f'sha256 = "{old_hash}";', f'sha256 = "{new_hash}";')
        path.write_text(text)
        fixed.append(f"{row['subject']} {row['from']} -> {row['to']}")

    return fixed, failed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", default=".", help="repository root")
    parser.add_argument("--update", action="store_true", help="rewrite stale pins in place")
    parser.add_argument("--quiet", action="store_true", help="print only when something is behind")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    report = collect(root)

    stale = [row for row in report if row["status"] == "stale"]
    errors = [row for row in report if row["status"] == "error"]
    checked = len([row for row in report if row["status"] in ("ok", "stale")])

    if stale and not args.update:
        print("Pins behind upstream (nothing updates these automatically):")
    for row in report:
        if row["status"] == "stale" and not args.update:
            print(f"  STALE  {row['subject']:42} {row['detail']}")
        elif row["status"] == "error":
            print(f"  ERROR  {row['subject']:42} {row['detail']}")
        elif row["status"] == "skip" and not args.quiet:
            print(f"  SKIP   {row['subject']:42} {row['detail']}")

    if stale and not args.update:
        print("\n  fix with: nix run .#check-pins -- --update")

    if args.update and stale:
        fixed, failed = apply_updates(root, stale)
        for line in fixed:
            print(f"  UPDATED  {line}")
        for subject, detail in failed:
            print(f"  FAILED   {subject:40} {detail}")
        if failed:
            errors.extend(failed)

    if not args.quiet:
        print(f"\n{checked} pins checked, {len(stale)} stale, {len(errors)} unreadable")

    if errors:
        return 2
    return 1 if stale else 0


if __name__ == "__main__":
    sys.exit(main())
