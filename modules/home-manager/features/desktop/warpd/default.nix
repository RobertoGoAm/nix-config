{ lib, pkgs, ... }:
{
  # warpd — keyboard-driven mouse pointer control. nixpkgs ships it for Linux;
  # on darwin pkgs.warpd is built from source (overlays/warpd.nix). Linux pulls
  # it in here via home-manager; on darwin it's installed system-wide by the
  # launchd service module instead — the standalone darwin homeConfigurations use
  # an un-overlaid pkgs set where nixpkgs warpd is Linux-only and wouldn't eval.
  home.packages = lib.mkIf pkgs.stdenv.hostPlatform.isLinux [ pkgs.warpd ];

  # Bindings are placed by PHYSICAL key position — each value is the Colemak
  # letter at the physical position of warpd's QWERTY default — so the finger
  # motions match QWERTY warpd and survive a switch back to QWERTY (cursor
  # h/n/e/i are the physical QWERTY hjkl keys, matching my vim remaps in
  # development/nvim/keybinds.nix). Global activation is grabbed by the launchd
  # agent on macOS (modules/macos/services/warpd); on perseus/Wayland the GNOME
  # module binds the same physical keys to `warpd --hint/--grid/--normal`.
  xdg.configFile."warpd/config".text = ''
    # Each value is the Colemak letter at warpd's QWERTY-default physical key, so
    # the finger motions are identical to QWERTY warpd. Defaults unchanged in
    # Colemak (left h, top H, middle M, accelerator a, hint x, cursor c,
    # history h, drag v, buttons m , .) aren't repeated here.

    # Cursor movement — QWERTY h j k l → Colemak h n e i
    left: h
    down: n
    up: e
    right: i
    # Jump to bottom edge — QWERTY L → Colemak I
    bottom: I

    # Scroll — QWERTY r (up) / e (down) → Colemak p / f
    scroll_up: p
    scroll_down: f

    # Slow-pointer modifier — QWERTY d → Colemak s
    decelerator: s

    # History stack (normal mode) — deliberately left at warpd's default C-o / C-i
    # (NOT remapped by physical position): nvim's jumplist is also unremapped
    # C-o / C-i, so both fire on the Colemak letters o / i and the motion matches.

    # Sub-modes from normal mode — QWERTY g / s / ; / p → Colemak d / r / o / ;
    grid: d
    screen: r
    history: o
    print: ;
    # Oneshot click buttons — QWERTY "n - /" → Colemak "k - /"
    oneshot_buttons: k - /

    # Grid mode — QWERTY w a s d → w a r s; quadrant keys u i j k → l u n e
    grid_down: r
    grid_right: s
    grid_keys: l u n e

    # Global activation chords — QWERTY grid g / screen s / hint-oneshot l /
    # 2-pass-oneshot L → Colemak d / r / i / I (hint A-M-x, hint2 A-M-X, cursor
    # A-M-c, history A-M-h unchanged — those keys keep their QWERTY position).
    grid_activation_key: A-M-d
    screen_activation_key: A-M-r
    hint_oneshot_key: A-M-i
    hint2_oneshot_key: A-M-I

    # Hint labels — the physical home row (QWERTY asdfghjkl; → Colemak arstdhneio)
    hint_chars: arstdhneio
    # Clear-all in hint mode — QWERTY C-u → Colemak C-l (same physical u key).
    hint_undo_all: C-l
    # Screen-select + two-pass-hint label sets — each QWERTY default mapped to the
    # Colemak letter on the same physical key, so the keys pressed match QWERTY
    # warpd: screen jkl;asdfg -> neioarstd, hint2 hjkl;asdfg... -> hneioarstd...
    screen_chars: neioarstd
    hint2_chars: hneioarstdqwfpgjluy;zxcvb
  '';
}
