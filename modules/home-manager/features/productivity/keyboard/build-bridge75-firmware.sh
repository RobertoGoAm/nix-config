#!/usr/bin/env bash
# Build the Bridge75 VIA firmware from emolitor's QMK fork, using the keymap +
# rules.mk vendored next to this script. The compiled base is Colemak; VIA is
# enabled so you can tweak on the fly from usevia.app afterwards (and the
# wireless keys KC_USB/KC_BT1..3/KC_2G4 are real keycodes, so BT survives).
#
# Needs qmk + the ARM toolchain. Easiest:
#   nix-shell -p qmk gcc-arm-embedded --run ~/keyboards/bridge75/build-firmware.sh
# or natively on macOS:
#   brew install qmk && qmk setup        # one-time; installs the toolchain
#   ~/keyboards/bridge75/build-firmware.sh
#
# Flash: hold Esc while plugging in USB (wb32-dfu bootloader), then flash the
# printed .bin with QMK Toolbox — or `qmk flash -kb shortcut/bridge75 -km via`.
# Then open https://usevia.app, enable the Design tab, and load
# ~/keyboards/bridge75/via-definition.json to edit on the fly.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${BRIDGE75_QMK_DIR:-$HOME/.cache/qmk/bridge75}"
FORK="${BRIDGE75_QMK_FORK:-https://github.com/emolitor/qmk_firmware.git}"
BRANCH="${BRIDGE75_QMK_BRANCH:-em-bridge75}"

command -v qmk >/dev/null 2>&1 || {
  echo "qmk not on PATH. Try:  nix-shell -p qmk gcc-arm-embedded   (or: brew install qmk && qmk setup)" >&2
  exit 1
}

keymap_src="$(ls "$HERE"/*colemak*keymap.c 2>/dev/null | head -1 || true)"
rules_src="$(ls "$HERE"/*via-rules.mk 2>/dev/null | head -1 || true)"
[ -n "$keymap_src" ] || { echo "No *colemak*keymap.c found next to this script." >&2; exit 1; }
[ -n "$rules_src" ]  || { echo "No *via-rules.mk found next to this script." >&2; exit 1; }

if [ ! -e "$WORK/.git" ]; then
  echo "==> Cloning $FORK ($BRANCH) -> $WORK"
  git clone --depth 1 --branch "$BRANCH" "$FORK" "$WORK"
fi
export QMK_HOME="$WORK"
cd "$WORK"

echo "==> Fetching submodules (chibios, etc.)"
qmk git-submodule

echo "==> Installing the via keymap (Colemak base + VIA_ENABLE)"
dest="keyboards/shortcut/bridge75/keymaps/via"
mkdir -p "$dest"
cp "$keymap_src" "$dest/keymap.c"
cp "$rules_src"  "$dest/rules.mk"

echo "==> Compiling shortcut/bridge75:via"
qmk compile -kb shortcut/bridge75 -km via

bin="$(ls -t "$WORK"/shortcut_bridge75_via.* 2>/dev/null | head -1 || true)"
echo
echo "Done."
echo "Firmware: ${bin:-look under $WORK for shortcut_bridge75_via.bin}"
echo "Flash:    hold Esc while plugging in USB (wb32-dfu), then QMK Toolbox,"
echo "          or  (cd \"$WORK\" && qmk flash -kb shortcut/bridge75 -km via)"
echo "Edit:     usevia.app -> Design tab -> load ~/keyboards/bridge75/via-definition.json"
