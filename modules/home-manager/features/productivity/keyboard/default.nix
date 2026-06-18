{ ... }:
{
  # Shortcut Bridge 75 Plus (ANSI), WB32 + wireless. Vendored here and deployed to
  # ~/keyboards/bridge75/ so they're on hand on any machine. Two ways to drive it:
  #
  #   QMK firmware (preferred — Colemak is compiled in, Bluetooth stays intact):
  #   - colemak-keymap.c  : 1:1 of the fork's default keymap with layer 0 remapped
  #                         to Colemak; the Fn layer keeps the real
  #                         KC_USB/KC_BT1..3/KC_2G4 keycodes, so BT works.
  #   - build-firmware.sh : clones emolitor/qmk_firmware@em-bridge75, drops the
  #                         keymap in, and `qmk compile`s it. Needs qmk + the ARM
  #                         toolchain (nix-shell -p qmk gcc-arm-embedded).
  #     Flash: hold Esc while plugging in USB (wb32-dfu bootloader), then QMK Toolbox.
  #
  #   VIA fallback (no compiler, but the BT keys can't be customised — VIA can't
  #   represent KC_BT2/KC_BT3, so importing a layout drops them to KC_NO):
  #   - firmware.bin        : stock vendor firmware (factory restore).
  #   - via-definition.json : load in VIA's Design tab if it doesn't auto-detect
  #                           (vendorId 0x0C45 / 0xFEFE).
  #   - layout.json         : VIA keymap export (Colemak L0, BT2/BT3 as raw hex).
  home.file = {
    "keyboards/bridge75/colemak-keymap.c".source = ./bridge75-colemak-keymap.c;
    "keyboards/bridge75/build-firmware.sh" = {
      source = ./build-bridge75-firmware.sh;
      executable = true;
    };
    "keyboards/bridge75/firmware.bin".source = ./bridge75.bin;
    "keyboards/bridge75/via-definition.json".source = ./bridge75-via.json;
    "keyboards/bridge75/layout.json".source = ./bridge75-layout.json;
  };
}
