#!/usr/bin/env bash
# Build the Bridge75 Colemak firmware from emolitor's QMK fork, using the
# *colemak*keymap.c vendored next to this script.
#
# Needs qmk + the ARM toolchain. Easiest:
#   nix-shell -p qmk gcc-arm-embedded --run ~/keyboards/bridge75/build-firmware.sh
# or natively on macOS:
#   brew install qmk && qmk setup        # one-time; installs the toolchain
#   ~/keyboards/bridge75/build-firmware.sh
#
# Flash: hold Esc while plugging in USB to enter the wb32-dfu bootloader, then
# flash the printed .bin with QMK Toolbox — or `qmk flash -kb shortcut/bridge75 -km colemak`.
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
[ -n "$keymap_src" ] || { echo "No *colemak*keymap.c found next to this script." >&2; exit 1; }

if [ ! -e "$WORK/.git" ]; then
  echo "==> Cloning $FORK ($BRANCH) -> $WORK"
  git clone --depth 1 --branch "$BRANCH" "$FORK" "$WORK"
fi
export QMK_HOME="$WORK"
cd "$WORK"

echo "==> Fetching submodules (chibios, etc.)"
qmk git-submodule

echo "==> Installing the colemak keymap"
mkdir -p keyboards/shortcut/bridge75/keymaps/colemak
cp "$keymap_src" keyboards/shortcut/bridge75/keymaps/colemak/keymap.c

echo "==> Compiling shortcut/bridge75:colemak"
qmk compile -kb shortcut/bridge75 -km colemak

bin="$(ls -t "$WORK"/shortcut_bridge75_colemak.* 2>/dev/null | head -1 || true)"
echo
echo "Done."
echo "Firmware: ${bin:-look under $WORK for shortcut_bridge75_colemak.bin}"
echo "Flash:    hold Esc while plugging in USB (wb32-dfu bootloader), then QMK Toolbox,"
echo "          or  (cd \"$WORK\" && qmk flash -kb shortcut/bridge75 -km colemak)"
