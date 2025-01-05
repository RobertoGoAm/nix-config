{ lib, ... }:

with lib.hm.gvariant;

{
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
        "sp-tray@sp-tray.esenliyim.github.com"
      ];

      favorite-apps = [
        "org.gnome.Nautilus.desktop"
        "org.gnome.Calendar.desktop"
        "firefox.desktop"
        "chromium-browser.desktop"
        "google-chrome.desktop"
        "spotify.desktop"
        "Alacritty.desktop"
        "code.desktop"
        "org.telegram.desktop.desktop"
        "vmware-view.desktop"
      ];
    };

    "org/gnome/shell/extensions/forge/keybindings" = {
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
      loop-playlist = "\128257";
      loop-track = "\128258";
      marquee-interval = 1000;
      marquee-length = 50;
      marquee-tail = " --- ";
      metadata-when-paused = true;
      off = "\128164\65039";
      paused = "\9208\65039";
      podcast-format = ''
        {album} | {track}
      '';
      position = 2;
      shuffle = "\128256\65039";
      stopped = "\9209\65039";
      title-max-length = 35;
    };

    "extensions/tiling-assistant" = {
      single-screen-gap = 16;
      window-gap = 12;
    };
  };
}
