{ ... }:
{
  # Shortcut Bridge 75 Plus (ANSI), WB32 + wireless. Approach: compile a VIA-enabled
  # firmware from emolitor/qmk_firmware@em-bridge75 with Colemak as the default
  # keymap, then tweak it on the fly in VIA. The fork uses standard KC_BT* keycodes,
  # so VIA names the wireless keys correctly — unlike the stock firmware, where VIA
  # saw KC_BT2/KC_BT3 as LT(0,undefined) and dropped them to KC_NO on import.
  # Deployed to ~/keyboards/bridge75/:
  #   - colemak-keymap.c    : layer 0 = Colemak; Fn keeps KC_USB/KC_BT1..3/KC_2G4.
  #   - via-rules.mk        : VIA_ENABLE=yes for the compiled `via` keymap.
  #   - build-firmware.sh   : clone fork, drop in the via keymap, `qmk compile`.
  #                           nix-shell -p qmk gcc-arm-embedded gnumake git wb32-dfu-updater
  #                           (verified: builds a ~45 KB shortcut_bridge75_via.bin).
  #   - via-definition.json : load in usevia.app's Design tab to edit on the fly.
  #   - firmware.bin        : stock vendor firmware (factory restore).
  #   - layout.json         : VIA layout matching this firmware (Colemak + SYM/NAV,
  #                           BT as CUSTOM(0/1/2/3/6)); import in usevia.app to
  #                           restore the full keymap, or keep as a tweak backup.
  # Flash: hold Esc while plugging in USB (wb32-dfu bootloader), then QMK Toolbox.
  home.file = {
    "keyboards/bridge75/colemak-keymap.c".source = ./bridge75-colemak-keymap.c;
    "keyboards/bridge75/via-rules.mk".source = ./bridge75-via-rules.mk;
    "keyboards/bridge75/build-firmware.sh" = {
      source = ./build-bridge75-firmware.sh;
      executable = true;
    };
    "keyboards/bridge75/via-definition.json".source = ./bridge75-via.json;
    "keyboards/bridge75/firmware.bin".source = ./bridge75.bin;
    "keyboards/bridge75/layout.json".source = ./bridge75-layout.json;
  };
}
