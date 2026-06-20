{ lib, pkgs, ... }:

with lib.hm.gvariant;

{
  home.packages = [ pkgs.rofi ]; # X11 window switcher (rofi -show window)

  dconf.settings = {
    # Extensions
    "org/gnome/shell" = {
      disable-user-extensions = false;
      last-selected-power-profile = "performance";

      disabled-extensions = [
        "disabled"
      ];

      enabled-extensions = [
        "forge@jmmaranan.com"
        "space-bar@luchrioh"
        "sp-tray@sp-tray.esenliyim.github.com"
      ];

      favorite-apps = [
        "org.gnome.Nautilus.desktop"
        "org.gnome.Settings.desktop"
        "org.gnome.Calendar.desktop"
        "firefox.desktop"
        "chromium-browser.desktop"
        "thunderbird.desktop"
        "spotify.desktop"
        "Alacritty.desktop"
        "code.desktop"
        "org.telegram.desktop.desktop"
        "vlc.desktop"
        "obsidian.desktop"
        "remnote.desktop"
        "vmware-view.desktop"
      ];
    };

    # --- Mirror the macOS interface prefs from modules/macos/default.nix ---
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark"; # ≈ AppleInterfaceStyle = "Dark"
      enable-hot-corners = false; # ≈ mac hot corners disabled
    };
    "org/gnome/desktop/peripherals/mouse".natural-scroll = false; # ≈ swipescrolldirection = false
    "org/gnome/desktop/peripherals/touchpad" = {
      natural-scroll = false;
      tap-to-click = false; # ≈ mac trackpad Clicking = false
    };
    "org/gnome/desktop/peripherals/keyboard" = {
      repeat = true;
      repeat-interval = mkUint32 20; # fast key repeat (≈ mac KeyRepeat)
      delay = mkUint32 250; # short initial delay (≈ mac InitialKeyRepeat)
    };

    # Workspace switching aligned with aerospace/paneru on the macs: Alt+1-6 to
    # switch, Shift+Alt+1-6 to send the window there.
    "org/gnome/desktop/wm/keybindings" = {
      switch-to-workspace-1 = [ "<Alt>1" ];
      switch-to-workspace-2 = [ "<Alt>2" ];
      switch-to-workspace-3 = [ "<Alt>3" ];
      switch-to-workspace-4 = [ "<Alt>4" ];
      switch-to-workspace-5 = [ "<Alt>5" ];
      switch-to-workspace-6 = [ "<Alt>6" ];
      move-to-workspace-1 = [ "<Shift><Alt>1" ];
      move-to-workspace-2 = [ "<Shift><Alt>2" ];
      move-to-workspace-3 = [ "<Shift><Alt>3" ];
      move-to-workspace-4 = [ "<Shift><Alt>4" ];
      move-to-workspace-5 = [ "<Shift><Alt>5" ];
      move-to-workspace-6 = [ "<Shift><Alt>6" ];
    };

    # warpd pointer control — Wayland can't grab global hotkeys, so bind GNOME
    # custom shortcuts to invoke warpd directly (mirrors the macs' Alt+Cmd as
    # Alt+Super), on the same PHYSICAL keys as QWERTY warpd: hint = x, grid =
    # QWERTY-g position = Colemak d, normal = c. In-mode keys: features/desktop/warpd.
    "org/gnome/settings-daemon/plugins/media-keys".custom-keybindings = [
      "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/warpd-hint/"
      "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/warpd-grid/"
      "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/warpd-normal/"
      "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/window-switcher/"
      "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/window-switcher-f18/"
    ];
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/warpd-hint" = {
      name = "warpd hint";
      command = "${pkgs.warpd}/bin/warpd --hint";
      binding = "<Alt><Super>x";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/warpd-grid" = {
      name = "warpd grid";
      command = "${pkgs.warpd}/bin/warpd --grid";
      binding = "<Alt><Super>d";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/warpd-normal" = {
      name = "warpd normal";
      command = "${pkgs.warpd}/bin/warpd --normal";
      binding = "<Alt><Super>c";
    };
    # Window switcher = the Raycast "Switch Windows" analog (flat fuzzy list).
    # keyd maps a Super tap to this combo (see keyd-default.conf), so tapping
    # Super pops the list. X11 only — rofi can't enumerate windows on Wayland.
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/window-switcher" = {
      name = "Window switcher";
      command = "${pkgs.rofi}/bin/rofi -show window";
      binding = "<Control><Alt>w";
    };
    # Same switcher on bare F18: the Bridge75 sends F18 on tap-Cmd (it's excluded
    # from keyd, so the firmware's tap reaches GNOME directly as F18).
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/window-switcher-f18" = {
      name = "Window switcher (F18)";
      command = "${pkgs.rofi}/bin/rofi -show window";
      binding = "F18";
    };

    # Forge general settings live under .../forge (NOT .../forge/keybindings) —
    # otherwise the gap settings are written to the wrong path and ignored.
    "org/gnome/shell/extensions/forge" = {
      window-gap-hidden-on-single = true;
      window-gap-size = mkUint32 6;
    };

    "org/gnome/shell/extensions/forge/keybindings" = {
      window-focus-up = [ "<Alt>e" ];
      window-focus-left = [ "<Alt>h" ];
      window-focus-right = [ "<Alt>i" ];
      window-focus-down = [ "<Alt>n" ];

      window-move-up = [ "<Shift><Alt>e" ];
      window-move-left = [ "<Shift><Alt>h" ];
      window-move-right = [ "<Shift><Alt>i" ];
      window-move-down = [ "<Shift><Alt>n" ];

      window-swap-up = [ "<Control><Alt>e" ];
      window-swap-left = [ "<Control><Alt>h" ];
      window-swap-right = [ "<Control><Alt>i" ];
      window-swap-down = [ "<Control><Alt>n" ];

      window-swap-last-active = [ "<Alt>Return" ];

      con-split-horizontal = [ "<Alt>z" ];
      con-split-layout-toggle = [ "<Alt>g" ];
      con-split-vertical = [ "<Alt>v" ];
      con-stacked-layout-toggle = [ "<Shift><Alt>s" ];
      con-tabbed-layout-toggle = [ "<Shift><Alt>t" ];
      con-tabbed-showtab-decoration-toggle = [ "<Control><Alt>y" ];
      focus-border-toggle = [ "<Alt>x" ];
      prefs-tiling-toggle = [ "<Alt>w" ];
      window-gap-size-decrease = [ "<Control><Alt>minus" ];
      window-gap-size-increase = [ "<Control><Alt>plus" ];
      window-resize-bottom-decrease = [ "<Shift><Control><Alt>i" ];
      window-resize-bottom-increase = [ "<Control><Alt>u" ];
      window-resize-left-decrease = [ "<Shift><Control><Alt>o" ];
      window-resize-left-increase = [ "<Control><Alt>y" ];
      window-resize-right-decrease = [ "<Shift><Control><Alt>y" ];
      window-resize-right-increase = [ "<Control><Alt>o" ];
      window-resize-top-decrease = [ "<Shift><Control><Alt>u" ];
      window-resize-top-increase = [ "<Control><Alt>i" ];
      window-snap-center = [ "<Control><Alt>c" ];
      window-snap-one-third-left = [ "<Control><Alt>d" ];
      window-snap-one-third-right = [ "<Control><Alt>g" ];
      window-snap-two-third-left = [ "<Control><Alt>k" ];
      window-snap-two-third-right = [ "<Control><Alt>t" ];
      window-toggle-always-float = [ "<Shift><Alt>c" ];
      window-toggle-float = [ "<Alt>c" ];
      workspace-active-tile-toggle = [ "<Shift><Alt>w" ];
    };

    "org/gnome/shell/extensions/sp-tray" = {
      album-max-length = 35;
      artist-max-length = 35;
      display-format = ''
        {artist} | {track}
      '';
      display-mode = 1;
      hidden-when-inactive = true;
      hidden-when-paused = false;
      hidden-when-stopped = true;
      logo-position = 0;
      loop-playlist = "🔂";
      loop-track = "🔁";
      marquee-interval = 1000;
      marquee-length = 50;
      marquee-tail = " --- ";
      metadata-when-paused = true;
      off = "💤️";
      paused = "⏸️";
      podcast-format = ''
        {album} | {track}
      '';
      position = 2;
      shuffle = "🔀";
      stopped = "⏹️";
      title-max-length = 35;
    };

    "extensions/tiling-assistant" = {
      single-screen-gap = 16;
      window-gap = 12;
    };
  };
}
