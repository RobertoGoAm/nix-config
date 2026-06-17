{ ... }:
{
  # Shortcut Bridge 75 Plus (ANSI, VIA). Both artifacts are vendored in the repo
  # and deployed to ~/keyboards/bridge75/ so they're always on hand on any machine:
  #   - firmware.bin        : flash with qmk-toolbox (or `qmk flash`) when the
  #                           firmware needs (re)applying.
  #   - via-definition.json : load in the VIA app's Design tab if VIA doesn't
  #                           auto-detect the board (vendorId 0x0C45 / 0xFEFE).
  #
  # Your per-layer keymap itself lives in the board's EEPROM (set via VIA); export
  # it from VIA and drop it here too if you want that under version control.
  home.file = {
    "keyboards/bridge75/firmware.bin".source = ./bridge75.bin;
    "keyboards/bridge75/via-definition.json".source = ./bridge75-via.json;
  };
}
