{ lib, pkgs, ... }:
{
  # warpd — keyboard-driven mouse pointer control. nixpkgs ships it for Linux;
  # on darwin pkgs.warpd is built from source (overlays/warpd.nix). Linux pulls
  # it in here via home-manager; on darwin it's installed system-wide by the
  # launchd service module instead — the standalone darwin homeConfigurations use
  # an un-overlaid pkgs set where nixpkgs warpd is Linux-only and wouldn't eval.
  home.packages = lib.mkIf pkgs.stdenv.hostPlatform.isLinux [ pkgs.warpd ];

  # Movement mirrors my Colemak vim keys (development/nvim/keybinds.nix):
  #   h = left, n = down, e = up, i = right.
  # Activation hotkeys: on macOS the launchd agent (modules/macos/services/warpd)
  # runs the daemon and grabs Alt+Cmd+x (hint) / +g (grid) / +c (normal) globally.
  # On perseus/Wayland global grabs aren't allowed, so the GNOME module binds
  # Alt+Super+x/g/c to `warpd --hint/--grid/--normal` instead.
  xdg.configFile."warpd/config".text = ''
    # Normal (cursor) mode — Colemak h/n/e/i
    left: h
    down: n
    up: e
    right: i
    # Jump to the top / bottom screen edge (shifted up / down)
    top: E
    bottom: N

    # Scroll — moved off the default 'e' (now "up") onto the left hand
    scroll_down: t
    scroll_up: r

    # Hint mode — generate labels from the Colemak home row for fast typing
    hint_chars: arstdhneio
  '';
}
