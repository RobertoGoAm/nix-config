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
// SPDX-License-Identifier: GPL-2.0-or-later

#include QMK_KEYBOARD_H

enum layers { BASE, FN, SYM, NAV };

enum custom_keycodes {
    // Right-Shift tap-hold: tap sends GUI+Tab (switch to the last app — Cmd+Tab
    // on macOS, Super+Tab on GNOME); hold is a normal Right Shift. Logic lives in
    // process_record_user below. SAFE_RANGE keeps it clear of VIA's keycodes.
    TT_LASTAPP = SAFE_RANGE,
};

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
        KC_USB, KC_BT1, KC_BT2, KC_BT3, KC_2G4, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______,
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
    return true;
}
