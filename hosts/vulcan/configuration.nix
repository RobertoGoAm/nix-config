{ ... }:
{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
  };

  services.nix-daemon.enable = true;

  networking.hostName = "vulcan";

  nixpkgs.config.allowUnfree = true;

  system = {
    activationScripts = {
      extraActivation.text = ''
        softwareupdate --install-rosetta --agree-to-license
      '';

      postUserActivation.text = ''
        # Following line should allow us to avoid a logout/login cycle
        /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
      '';
    };

    defaults = {
      # Disable mouse acceleration
      ".GlobalPreferences"."com.apple.mouse.scaling" = -1.0;

      alf = {
        # Enable Firewall
        globalstate = 1;
      };

      CustomUserPreferences = {
        NSGlobalDomain = {
          # Dark theme for OS
          AppleInterfaceStyle = "Dark";

          # Disable natural scrolling
          "com.apple.swipescrolldirection" = false;

          # 120, 90, 60, 30, 12, 6, 2
          KeyRepeat = 2;

          # 120, 94, 68, 35, 25, 15
          InitialKeyRepeat = 25;
        };
      };
    };

    dock = {
      # Rearrange Spaces based on most recent use
      mru-spaces = false;

      # Dock position
      orientation = "left";

      # Permanent apps on dock
      persistent-apps = [
        "/System/Library/CoreServices/Finder.app"
        "/System/Applications/Calendar.app"
        "/Applications/Safari.app"
        "/Applications/Chromium.app"
        "/Applications/Google Chrome.app"
        "/System/Applications/Mail.app"
        "/Applications/Spotify.app"
        "/Applications/Visual Studio Code.app"
        "/Applications/iTerm.app"
        "/Applications/Telegram.app"
      ];

      # Permanent folders on dock
      persistent-others = [
        "~/Downloads"
        "~/Development"
      ];

      # Don't show recent apps
      show-recents = false;

      # Icon size
      tilesize = 42;

      # Hot corners https://daiderd.com/nix-darwin/manual/index.html#opt-system.defaults.dock.wvous-bl-corner
      wvous-bl-corner = 1;
      wvous-br-corner = 1;
      wvous-tl-corner = 1;
      wvous-tr-corner = 1;
    };

    stateVersion = 5;
  };
}
