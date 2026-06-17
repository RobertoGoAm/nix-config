{ lib, pkgs, ... }:
let
  image = ./wallpaper.jpg;
  uri = "file://${image}";
in
lib.mkMerge [
  # macOS has no clean declarative wallpaper API, so set it on activation via
  # osascript, pointed at the vendored image's store path. Runs in your GUI
  # session (applies when you rebuild from a logged-in terminal; a fresh/headless
  # boot has no session to talk to, hence best-effort). First run prompts for
  # Automation permission to control "System Events" — grant it and rebuild once.
  (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    home.activation.setWallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run /usr/bin/osascript -e 'tell application "System Events" to tell every desktop to set picture to "${image}"' || true
    '';
  })

  # GNOME/Linux: fully declarative via dconf (desktop + lock screen, light/dark).
  # picture-options = "zoom" fills a single screen (crops the ultrawide); switch
  # to "spanned" if perseus drives two monitors.
  (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    dconf.settings = {
      "org/gnome/desktop/background" = {
        picture-uri = uri;
        picture-uri-dark = uri;
        picture-options = "zoom";
      };
      "org/gnome/desktop/screensaver" = {
        picture-uri = uri;
        picture-options = "zoom";
      };
    };
  })
]
