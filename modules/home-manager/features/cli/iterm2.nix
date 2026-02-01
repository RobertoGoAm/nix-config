# Example iTerm2 configuration based on the provided plist
{ config, pkgs, ... }:

{
  programs.iterm2 = {
    enable = true;
    copyApplications = false;

    settings = {
      appearance.theme = "minimal";

      general = {
        hapticFeedbackForEsc = false;
        soundForEsc = false;
        visualIndicatorForEsc = false;
        ignoreSystemWindowRestoration = true;
        windowRestoresWorkspaceAtLaunch = false;
        hotkeyMigratedFromSingleToMulti = true;
        confirmQuit = false;
        hideMenuBarInFullscreen = false; # Show menu bar in fullscreen
        showFullScreenTabBar = true; # Show tabs in fullscreen
        flashTabBarInFullscreen = false;
        tabViewType = "bottom"; # Tabs at bottom
        launchAtLogin = true; # Launch at login
      };

    };

    profiles = [
      {
        name = "nix managed quake";
        default = true;

        window = {
          columns = 80;
          rows = 25;
        };

        font = {
          normal = "JetBrainsMonoNFM-Regular 14";
          useNonAsciiFont = false;
          antiAlias = true;
          brightenBold = true;
        };

        terminal = {
          mouseReporting = true;
          showBellIcon = true;
          visualBell = true;
          closeSessionsOnEnd = true;
          warnShortLivedSessions = false;
        };

        transparency = 0.35;

        hotkey = {
          enabled = true;
          characters = "'";
          modifierFlags = 1048576; # Command key
          keyCode = 50; # Single quote key (correct key code)
          modifierActivation = 0;
          dockClickAction = 0;
          windowType = "quake";
          autoHides = true;
          floats = true;
          animates = true;
          reopensOnActivation = false;
        };

        scrollback = {
          lines = 1000;
          unlimited = false;
        };

        jobs = {
          toIgnore = [
            "rlogin"
            "ssh"
            "slogin"
            "telnet"
          ];
        };

        tags = [
          "nix"
          "managed"
        ];

        spacing = {
          horizontal = 1.0;
          vertical = 1.0;
        };

        blend = 0.5;
        blur = false;
        disableWindowResizing = true;

        colors = {
          background = "#1a1a25";
          foreground = "#c1c9f1";

          black = {
            normal = "#15151d";
            bright = "#424765";
          };

          red = {
            normal = "#e67d8f";
            bright = "#e67d8f";
          };

          green = {
            normal = "#a7cc76";
            bright = "#a7cc76";
          };

          yellow = {
            normal = "#d8b072";
            bright = "#d8b072";
          };

          blue = {
            normal = "#82a0f0";
            bright = "#82a0f0";
          };

          magenta = {
            normal = "#b59bf0";
            bright = "#b59bf0";
          };

          cyan = {
            normal = "#90ccfa";
            bright = "#90ccfa";
          };

          white = {
            normal = "#aab0d2";
            bright = "#aab0d2";
          };
        };
      }
    ];
  };
}
