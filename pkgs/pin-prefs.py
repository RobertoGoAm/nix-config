"""Regenerate a macOS defaults module from an app's live preferences.

targets.darwin.defaults pins the keys it declares, so the way to change one of
these apps is: change it in the app, then re-run this. Hand-editing the
generated file works until the next regeneration silently reverts it.

Two things are filtered out:

  * values Nix cannot express — data blobs and plist dates, left under the
    app's own control
  * runtime state — window frames, resume positions, last-used tools,
    update-check stamps. Pinning those resets them on every activation and
    makes every regeneration churn with no setting having changed.

Absolute paths under $HOME are emitted as ${config.home.homeDirectory}/… so the
module does not hard-code a user name.

Usage: pin-prefs <domain> <output.nix>
"""

import datetime
import os
import plistlib
import subprocess
import sys
import tempfile

# Runtime state per domain: real values, but not preferences.
EXCLUDED = {
    "com.vorssaint.utils": [
        "NSNavPanelExpandedSizeForOpenMode",
        "appUpdatesLastCheck",
        "appUpdatesLastCount",
        "appUpdatesNotifiedIDs",
        "mediaLastTool",
        "settingsWindowHeight",
        "settingsWindowWidth",
    ],
    "com.colliderli.iina": [
        "MainWindowLastPosition",
        "NSSplitView Subview Frames NSColorPanelSplitView",
        "NSToolbar Configuration com.apple.NSColorPanel",
        "NSWindow Frame IINAOpenURLWindow",
        "NSWindow Frame IINAWelcomeWindow",
        "NSWindow Frame NSColorPanel",
        "iinaLastPlayedFilePosition",
    ],
}

HOME = os.path.expanduser("~")
HOME_VAR = "${config.home.homeDirectory}"


def escape(s):
    """Escape a Nix string, then re-open the antiquotation for $HOME paths."""
    s = s.replace("\\", "\\\\").replace('"', '\\"').replace("${", "\\${")
    if s.startswith(HOME + "/"):
        s = HOME_VAR + s[len(HOME):]
    return s


def render(value, indent):
    pad = "  " * indent
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        return repr(value)
    if isinstance(value, str):
        return '"%s"' % escape(value)
    if isinstance(value, list):
        if not value:
            return "[ ]"
        items = "\n".join(f"{pad}  {render(v, indent + 1)}" for v in value)
        return f"[\n{items}\n{pad}]"
    if isinstance(value, dict):
        if not value:
            return "{ }"
        items = "\n".join(
            f'{pad}  "{escape(k)}" = {render(v, indent + 1)};' for k, v in sorted(value.items())
        )
        return f"{{\n{items}\n{pad}}}"
    raise TypeError(f"cannot render {type(value).__name__}")


def export(domain):
    with tempfile.NamedTemporaryFile(suffix=".plist", delete=False) as tmp:
        path = tmp.name
    try:
        subprocess.run(["defaults", "export", domain, path], check=True)
        with open(path, "rb") as handle:
            return plistlib.load(handle)
    finally:
        os.unlink(path)


def main():
    if len(sys.argv) != 3:
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 2
    domain, out_path = sys.argv[1], sys.argv[2]

    prefs = export(domain)
    excluded = EXCLUDED.get(domain, [])

    unrenderable, keep = [], {}
    for key, value in prefs.items():
        if key in excluded:
            continue
        if isinstance(value, (bytes, bytearray)):
            unrenderable.append((key, "data blob"))
        elif isinstance(value, datetime.datetime):
            unrenderable.append((key, "date"))
        else:
            keep[key] = value

    lines = [
        "{ config, ... }:",
        "{",
        f"  # {domain} preferences, pinned declaratively. targets.darwin.defaults",
        "  # writes only the keys listed here and leaves the rest of the domain",
        "  # alone, but these keys are reset to these values on every activation.",
        "  #",
        f"  # Generated — change the setting in the app, then re-run:",
        f"  #   nix run .#pin-prefs -- {domain} <this file>",
    ]
    if unrenderable:
        lines += ["  #", "  # Not expressible as Nix values, left to the app:"]
        lines += [f"  #   {k} ({why})" for k, why in sorted(unrenderable)]
    if excluded:
        lines += ["  #", "  # Runtime state, deliberately excluded:"]
        lines += [f"  #   {k}" for k in excluded]
    lines.append(f'  targets.darwin.defaults."{domain}" = {render(keep, 1)};')
    lines.append("}")

    with open(out_path, "w") as handle:
        handle.write("\n".join(lines) + "\n")

    print(f"{len(keep)} keys pinned to {out_path}")
    print(f"  excluded {len(excluded)} runtime, {len(unrenderable)} unrenderable")
    return 0


if __name__ == "__main__":
    sys.exit(main())
