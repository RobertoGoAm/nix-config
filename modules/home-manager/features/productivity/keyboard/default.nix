{ ... }:
{
  # Shortcut Bridge 75 Plus (ANSI, VIA). These artifacts are vendored in the repo
  # and deployed to ~/keyboards/bridge75/ so they're always on hand on any machine:
  #   - firmware.bin        : flash with qmk-toolbox (or `qmk flash`) when the
  #                           firmware needs (re)applying.
  #   - via-definition.json : load in the VIA app's Design tab if VIA doesn't
  #                           auto-detect the board (vendorId 0x0C45 / 0xFEFE).
  #   - layout.json         : the VIA keymap export (Colemak + layers). The board's
  #                           keymap lives only in EEPROM, so this is the sole
  #                           version-controlled copy — re-apply it via VIA's
  #                           "Load saved layout" on a fresh/reset board.
  home.file = {
    "keyboards/bridge75/firmware.bin".source = ./bridge75.bin;
    "keyboards/bridge75/via-definition.json".source = ./bridge75-via.json;
    "keyboards/bridge75/layout.json".source = ./bridge75-layout.json;
  };
}
