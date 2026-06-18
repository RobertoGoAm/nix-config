# Enable VIA for the Bridge75 `via` keymap: dynamic keymaps in EEPROM + raw-HID,
# so the compiled Colemak base can be tweaked on the fly from usevia.app. The
# fork declares KC_USB/KC_BT1..5/KC_2G4/KC_BATQ in keyboard.json, so VIA names
# the wireless keys correctly (no LT(0,undefined) mangling like the stock fw).
VIA_ENABLE = yes
