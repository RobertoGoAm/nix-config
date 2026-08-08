"""Report drift on the version pins that nothing in this repo updates for you.

Checks two sources:

  * the Chromium snapshot in overlays/apple-silicon-chromium.nix, against the
    LAST_CHANGE marker in Google's Mac_Arm snapshot bucket
  * every marketplace extension pinned in the VS Code module, against the
    Visual Studio Marketplace gallery API

Exits 1 when anything is behind so it can gate a check, 0 when everything is
current, and 2 when a lookup itself failed.
"""

import json
import re
import subprocess
import sys
from pathlib import Path

CHROMIUM_OVERLAY = Path("overlays/apple-silicon-chromium.nix")
VSCODE_MODULE = Path("modules/home-manager/features/development/vscode/default.nix")

SNAPSHOT_LAST_CHANGE = (
    "https://storage.googleapis.com/chromium-browser-snapshots/Mac_Arm/LAST_CHANGE"
)
MARKETPLACE_QUERY = (
    "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery"
)

# Matches either field order; the module uses both.
EXTENSION_BLOCK = re.compile(
    r'\{\s*(?:name = "(?P<n1>[^"]+)";\s*publisher = "(?P<p1>[^"]+)";'
    r'|publisher = "(?P<p2>[^"]+)";\s*name = "(?P<n2>[^"]+)";)'
    r'\s*version = "(?P<version>[^"]+)";',
    re.MULTILINE,
)


def fetch(url, data=None):
    cmd = ["curl", "-sS", "--max-time", "30", url]
    if data is not None:
        cmd += [
            "-X",
            "POST",
            "-H",
            "Content-Type: application/json",
            "-H",
            "Accept: application/json;api-version=7.1-preview.1",
            "-d",
            data,
        ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"curl exited {result.returncode}")
    return result.stdout


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
        name = match.group("n1") or match.group("n2")
        publisher = match.group("p1") or match.group("p2")
        yield f"{publisher}.{name}", match.group("version")


def check_chromium(root, report):
    overlay = root / CHROMIUM_OVERLAY
    if not overlay.exists():
        report.append(("skip", "chromium", f"{CHROMIUM_OVERLAY} not found"))
        return
    pinned = re.search(r'version = "(\d+)";', overlay.read_text())
    if not pinned:
        report.append(("error", "chromium", "no version pin found in the overlay"))
        return
    latest = fetch(SNAPSHOT_LAST_CHANGE).strip()
    if pinned.group(1) == latest:
        report.append(("ok", "chromium snapshot", pinned.group(1)))
    else:
        behind = int(latest) - int(pinned.group(1))
        report.append(
            (
                "stale",
                "chromium snapshot",
                f"{pinned.group(1)} -> {latest} ({behind} revisions behind)",
            )
        )


def check_extensions(root, report):
    module = root / VSCODE_MODULE
    if not module.exists():
        report.append(("skip", "extensions", f"{VSCODE_MODULE} not found"))
        return
    for extension_id, pinned in parse_extension_pins(module.read_text()):
        try:
            latest = latest_extension_version(extension_id)
        except Exception as exc:  # noqa: BLE001 - report, do not abort the sweep
            report.append(("error", extension_id, str(exc)))
            continue
        if latest == pinned:
            report.append(("ok", extension_id, pinned))
        else:
            report.append(("stale", extension_id, f"{pinned} -> {latest}"))


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    report = []
    check_chromium(root, report)
    check_extensions(root, report)

    stale = [row for row in report if row[0] == "stale"]
    errors = [row for row in report if row[0] == "error"]

    for status, subject, detail in report:
        if status == "stale":
            print(f"  STALE  {subject:42} {detail}")
        elif status == "error":
            print(f"  ERROR  {subject:42} {detail}")
        elif status == "skip":
            print(f"  SKIP   {subject:42} {detail}")

    checked = len([row for row in report if row[0] in ("ok", "stale")])
    print(f"\n{checked} pins checked, {len(stale)} stale, {len(errors)} unreadable")

    if errors:
        return 2
    return 1 if stale else 0


if __name__ == "__main__":
    sys.exit(main())
