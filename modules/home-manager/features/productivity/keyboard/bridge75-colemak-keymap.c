// Bridge75 keymap — Colemak base plus the symbol & nav layers, ported from the
// old VIA layout (commit b6a73b2). FN is the fork's default Fn layer with the
// real KC_USB/KC_BT1..3/KC_2G4 wireless keycodes. Built as the `via` keymap, so
// it can be tweaked live in usevia.app on top of this compiled default.
//
// BASE: Colemak; Caps = LT(NAV, Esc); RAlt = MO(SYM); MO(FN); left Cmd is a
//   mod-tap — tap = F18 (the "switch windows" trigger, like tap-Cmd on the macs),
//   hold = Left GUI/Cmd. Right Shift is a tap-hold too — tap = GUI+Tab ("last
//   app": Cmd+Tab on macOS, Super+Tab on GNOME), hold = normal Right Shift.
// SYM (hold RAlt): shifted digits + symbols + media.
// NAV (hold Caps): numpad, arrows, Home/PgUp/End, and warpd activation —
//   Caps+M = hint, Caps+D = grid, Caps+C = normal (each sends Cmd+Opt+<x/d/c> on
//   mac / Super+Alt+<x/d/c> on Linux — warpd's activation chords). Karabiner/keyd
//   own these on the other keyboards but ignore this board, so the keymap sends
//   them directly. PgDn keeps its dedicated key on BASE.
// FN (hold MO(FN)) is the "system layer": media/brightness, RGB, the wireless
//   keys, EE_CLR on Esc, and QK_BOOT (jump to the wb32-dfu bootloader) on
//   Fn+Backspace — so re-flashing needs no unplug-and-hold-Esc dance.
// LEDs: the RGB toggle (Fn + its key) flips the base lighting on/off WITHOUT
//   disabling the matrix, so indicators stay live while the base is dark. Holding
//   Fn lights the keys that do something and turns Esc into a battery gauge
//   (green/orange/red by level, or green/amber while charging); at rest Esc just
//   pulses red on low battery.
// SPDX-License-Identifier: GPL-2.0-or-later

#include QMK_KEYBOARD_H

enum layers { BASE, FN, SYM, NAV };

enum custom_keycodes {
    // Right-Shift tap-hold: tap sends GUI+Tab (switch to the last app — Cmd+Tab
    // on macOS, Super+Tab on GNOME); hold is a normal Right Shift. Logic lives in
    // process_record_user below. SAFE_RANGE keeps it clear of VIA's keycodes.
    TT_LASTAPP = SAFE_RANGE,
};

#ifdef WIRELESS_ENABLE
// The wireless module reports the battery level (0-100); used by the low-battery
// indicator below. Declared here so the keymap needn't pull in module headers.
extern uint8_t *md_getp_bat(void);
#endif

// clang-format off
const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
    [BASE] = LAYOUT_ansi(
        HYPR(KC_SPC), KC_F1, KC_F2, KC_F3, KC_F4, KC_F5, KC_F6, KC_F7, KC_F8, KC_F9, KC_F10, KC_F11, KC_F12, KC_DEL,
        KC_GRV, KC_1, KC_2, KC_3, KC_4, KC_5, KC_6, KC_7, KC_8, KC_9, KC_0, KC_MINS, KC_EQL, KC_BSPC, KC_HOME,
        KC_TAB, KC_Q, KC_W, KC_F, KC_P, KC_G, KC_J, KC_L, KC_U, KC_Y, KC_SCLN, KC_LBRC, KC_RBRC, KC_BSLS, KC_PGUP,
        LT(NAV,KC_ESC), KC_A, KC_R, KC_S, KC_T, KC_D, KC_H, KC_N, KC_E, KC_I, KC_O, KC_QUOT, KC_ENT, KC_PGDN,
        KC_LSFT, KC_Z, KC_X, KC_C, KC_V, KC_B, KC_K, KC_M, KC_COMM, KC_DOT, KC_SLSH, TT_LASTAPP, KC_UP, KC_END,
        KC_LCTL, KC_LALT, LGUI_T(KC_F18), KC_SPC, MO(SYM), MO(FN), KC_LEFT, KC_DOWN, KC_RGHT
    ),
    [FN] = LAYOUT_ansi(
        EE_CLR, KC_BRID, KC_BRIU, KC_MCTL, KC_LPAD, KC_F5, KC_F6, KC_MPRV, KC_MPLY, KC_MNXT, KC_MUTE, KC_VOLD, KC_VOLU, _______,
        KC_USB, KC_BT1, KC_BT2, KC_BT3, KC_2G4, _______, _______, _______, _______, _______, _______, _______, _______, QK_BOOT, _______,
        _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______,
        _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______,
        _______, RGB_TOG, RGB_MOD, RGB_RMOD, RGB_HUI, RGB_HUD, RGB_SAI, RGB_SAD, RGB_VAI, RGB_VAD, _______, _______, _______, _______,
        _______, _______, _______, _______, _______, _______, _______, _______, _______
    ),
    [SYM] = LAYOUT_ansi(
        _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______,
        _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______,
        _______, S(KC_1), S(KC_2), S(KC_3), S(KC_4), S(KC_5), S(KC_6), S(KC_7), S(KC_8), S(KC_9), S(KC_0), S(KC_GRV), _______, _______, _______,
        LT(FN,KC_ESC), KC_MPRV, KC_VOLD, KC_VOLU, KC_MNXT, KC_MPLY, KC_MINS, KC_EQL, KC_LBRC, KC_RBRC, KC_BSLS, KC_GRV, _______, _______,
        _______, KC_NO, KC_NO, KC_NO, KC_NO, KC_NO, S(KC_MINS), S(KC_EQL), S(KC_LBRC), S(KC_RBRC), _______, _______, _______, _______,
        _______, _______, _______, _______, _______, _______, _______, _______, _______
    ),
    [NAV] = LAYOUT_ansi(
        _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______,
        _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, KC_DEL,
        _______, KC_P1, KC_P2, KC_P3, KC_P4, KC_P5, KC_P6, KC_P7, KC_P8, KC_P9, KC_P0, KC_NO, KC_NO, KC_NO, _______,
        _______, KC_CAPS, KC_NO, KC_NO, KC_NO, LGUI(LALT(KC_D)), KC_LEFT, KC_DOWN, KC_UP, KC_RGHT, KC_BSPC, KC_DEL, _______, _______,
        _______, KC_NO, KC_NO, LGUI(LALT(KC_C)), KC_NO, KC_NO, KC_HOME, LGUI(LALT(KC_X)), KC_PGUP, KC_END, KC_NO, KC_NO, _______, _______,
        _______, _______, _______, _______, MO(FN), _______, _______, _______, _______
    )
};
// clang-format on

// Resolve the left-Cmd mod-tap to its hold (Left GUI) the instant another key is
// pressed, so chorded shortcuts (Cmd+C/V/Z, etc.) never register as the F18 tap.
// A solo tap+release still sends F18 — the "switch windows" trigger.
bool get_hold_on_other_key_press(uint16_t keycode, keyrecord_t *record) {
    switch (keycode) {
        case LGUI_T(KC_F18):
            return true;
        default:
            return false;
    }
}

// Right Shift is a tap-hold: hold = Shift (registered eagerly so capitals never
// lag), tap = GUI+Tab to switch to the last app. Shift is held from key-down, and
// GUI+Tab fires only on release when no other key intervened and the press was
// quick — so Shift+<key> always shifts and never mis-fires the app switch, while
// a long solo hold is just Shift.
bool process_record_user(uint16_t keycode, keyrecord_t *record) {
    static uint16_t lastapp_timer;
    static bool     lastapp_interrupted;

    if (keycode == TT_LASTAPP) {
        if (record->event.pressed) {
            lastapp_timer       = timer_read();
            lastapp_interrupted = false;
            register_code(KC_RSFT);
        } else {
            unregister_code(KC_RSFT);
            if (!lastapp_interrupted && timer_elapsed(lastapp_timer) < TAPPING_TERM) {
                register_code(KC_LGUI);
                tap_code(KC_TAB);
                unregister_code(KC_LGUI);
            }
        }
        return false;
    }

    // Any other key pressed while Right Shift is held means it's being used as a
    // modifier, so suppress the last-app tap on release.
    if (record->event.pressed) {
        lastapp_interrupted = true;
    }

#ifdef RGB_MATRIX_ENABLE
    // Repurpose the RGB toggle: flip the base effect on/off instead of disabling
    // the whole matrix. Disabling it would also stop the indicator hooks below, so
    // keep the matrix enabled and just swap the base to RGB_MATRIX_NONE (all-black)
    // and back to the last real effect.
    if (keycode == RGB_TOG && record->event.pressed) {
        static uint8_t saved_mode = RGB_MATRIX_SOLID_COLOR;
        if (rgb_matrix_get_mode() != RGB_MATRIX_NONE) {
            saved_mode = rgb_matrix_get_mode();
            rgb_matrix_mode(RGB_MATRIX_NONE);
        } else {
            rgb_matrix_mode(saved_mode);
        }
        return false;
    }
#endif

    return true;
}

#ifdef RGB_MATRIX_ENABLE
// Timer-free "pleasant blink": brightness oscillates 1->255->1 each frame, used to
// pulse the low-battery warning. (Pattern salvaged from bridge75_iso.)
static uint8_t blink_val = 1;
static int8_t  blink_dir = 1;

// Keep the matrix enabled every boot so the indicator hooks always run; the base
// can still be dark (RGB_MATRIX_NONE, via the toggle above). Without this, a
// matrix toggled off in EEPROM would take the indicators down with it. Also set
// the charge-detect pins as inputs — the ANSI keyboard core doesn't (iso does).
void keyboard_post_init_user(void) {
    rgb_matrix_enable_noeeprom();
    gpio_set_pin_input(BT_CABLE_PIN);       // high when the charge cable is connected
    gpio_set_pin_input_high(BT_CHARGE_PIN); // low while charging, high when full
}

// Indicators that survive the base lighting being off:
//   - Holding Fn lights every key that does something on the FN ("system") layer.
//   - Esc (LED 0) reports the battery. At rest it only pulses red when low. While
//     Fn is held it's a full gauge: green/orange/red by level on battery, or
//     green (charged) / amber-pulse (charging) when plugged — the charge state is
//     read from the BT_CABLE/BT_CHARGE pins (reliable, unlike the level report).
bool rgb_matrix_indicators_advanced_user(uint8_t led_min, uint8_t led_max) {
    blink_val += blink_dir;
    if (blink_val == UINT8_MAX)   blink_dir = -1;
    else if (blink_val == 1)      blink_dir = 1;

    bool fn = (get_highest_layer(layer_state) == FN);

    if (fn) {
        for (uint8_t row = 0; row < MATRIX_ROWS; row++) {
            for (uint8_t col = 0; col < MATRIX_COLS; col++) {
                uint8_t index = g_led_config.matrix_co[row][col];
                if (index >= led_min && index < led_max && index != NO_LED &&
                    keymap_key_to_keycode(FN, (keypos_t){col, row}) > KC_TRNS) {
                    rgb_matrix_set_color(index, 0x00, 0x88, 0x88); // Fn keys: cyan
                }
            }
        }
    }

    // Esc battery/charge status. Charge state is read from the hardware pins
    // (reliable); the on-battery level comes from the wireless module.
    if (led_min == 0) {
        bool plugged = gpio_read_pin(BT_CABLE_PIN); // high when the cable is in
        if (fn) {
            if (plugged) {
                if (gpio_read_pin(BT_CHARGE_PIN)) {
                    rgb_matrix_set_color(0, 0x00, 0xAA, 0x00);            // green: charged
                } else {
                    rgb_matrix_set_color(0, blink_val, blink_val / 2, 0); // amber pulse: charging
                }
            } else {
#ifdef WIRELESS_ENABLE
                uint8_t bat = *md_getp_bat();                            // 0 = unknown
                if (bat > 50)      rgb_matrix_set_color(0, 0x00, 0xAA, 0x00); // green
                else if (bat > 20) rgb_matrix_set_color(0, 0xAA, 0x40, 0x00); // orange
                else if (bat > 0)  rgb_matrix_set_color(0, 0xAA, 0x00, 0x00); // red
#endif
            }
        } else if (!plugged) {
#ifdef WIRELESS_ENABLE
            uint8_t bat = *md_getp_bat();
            if (bat > 0 && bat <= 20) rgb_matrix_set_color(0, blink_val, 0x00, 0x00); // pulsing low
#endif
        }
    }

    return true;
}
#endif
