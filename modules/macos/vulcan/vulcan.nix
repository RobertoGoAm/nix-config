{
  config,
  inputs,
  lib,
  outputs,
  pkgs,
  user,
  ...
}:
{
  imports = [
    inputs.mac-app-util.darwinModules.default
    inputs.home-manager.darwinModules.home-manager
    inputs.nix-homebrew.darwinModules.nix-homebrew
    ../../homebrew/homebrew.nix
    ../services/aerospace
    ./casks.nix
  ];

  networking.hostName = "vulcan";

  nix =
    let
      flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
    in
    {
      channel.enable = false;

      gc = {
        automatic = true;
        interval = {
          Weekday = 0;
          Hour = 2;
          Minute = 0;
        };
        options = "--delete-older-than 7d";
      };

      nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;

      optimise.automatic = true;

      registry = lib.mapAttrs (_: flake: { inherit flake; }) flakeInputs;

      settings = {
        experimental-features = "nix-command flakes";
        flake-registry = "";
        nix-path = config.nix.nixPath;
      };
    };

  nixpkgs = {
    overlays = [
      outputs.overlays.apple-silicon
    ];

    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };

    hostPlatform = "aarch64-darwin";
  };

  system = {
    activationScripts = {
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
          # Disable press and hold for keyboard keys
          ApplePressAndHoldEnabled = false;

          # Dark theme for OS
          AppleInterfaceStyle = "Dark";

          # Disable natural scrolling
          "com.apple.swipescrolldirection" = false;

          # 120, 90, 60, 30, 12, 6, 2
          KeyRepeat = 2;

          # 120, 94, 68, 35, 25, 15
          InitialKeyRepeat = 25;

          # Add a context menu item for showing the Web Inspector in web views
          WebKitDeveloperExtras = true;
        };

        "com.apple.AdLib" = {
          allowApplePersonalizedAdvertising = false;
        };

        # Turn on app auto-update
        "com.apple.commerce".AutoUpdate = true;

        "com.apple.finder" = {
          FXDefaultSearchScope = "SCcf";
          FXPreferredViewStyle = "Nlsv";
          NewWindowTarget = "Home";
        };

        # Prevent Photos from opening automatically when devices are plugged in
        "com.apple.ImageCapture".disableHotPlug = true;

        "com.apple.screensaver" = {
          # Require password immediately after sleep or screen saver begins
          askForPassword = 1;
          askForPasswordDelay = 0;
        };

        "com.apple.SoftwareUpdate" = {
          AutomaticCheckEnabled = true;
          # Check for software updates daily, not just once per week
          ScheduleFrequency = 1;
          # Download newly available updates in background
          AutomaticDownload = 1;
          # Install System data files & security updates
          CriticalUpdateInstall = 1;
        };

        "com.apple.TimeMachine".DoNotOfferNewDisksForBackup = true;
      };

      dock = {
        # Rearrange Spaces based on most recent use
        mru-spaces = false;

        # Dock position
        orientation = "left";

        # Permanent apps on dock
        persistent-apps = [
          "/System/Applications/Calendar.app"
          "/System/Applications/System Settings.app"
          "/Users/${user}/Applications/Home Manager Apps/Firefox.app"
          "/Users/${user}/Applications/Home Manager Apps/Chromium.app"
          "/Applications/Google Chrome.app"
          "/System/Applications/Mail.app"
          "/Applications/Spotify.app"
          "/Applications/Visual Studio Code.app"
          "/Users/${user}/Applications/Home Manager Apps/Alacritty.app"
          "/Applications/Telegram.app"
          "/Applications/VLC.app"
          "/Applications/Obsidian.app"
          "/Applications/Remnote.app"
          "/Applications/Omnissa Horizon Client.app"
        ];

        # Permanent folders on dock
        persistent-others = [
          "/Users/${user}/Downloads"
          "/Users/${user}/Development"
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
    };

    stateVersion = 5;
  };

  users.users.${user} = {
    packages = [ pkgs.home-manager ];
    home = "/Users/${user}";
  };

  home-manager.extraSpecialArgs = {
    inherit inputs outputs user;

    system = "aarch64-darwin";
  };

  home-manager.users.${user} = import ../../home-manager/hosts/vulcan/vulcan.nix;
}
