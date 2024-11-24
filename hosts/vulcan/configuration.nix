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

        "com.apple.Safari" = {
          # Prevent Safari from opening ‘safe’ files automatically after downloading
          AutoOpenSafeDownloads = false;
          ShowFavoritesBar = false;
          IncludeInternalDebugMenu = true;
          IncludeDevelopMenu = true;
          WebKitDeveloperExtrasEnabledPreferenceKey = true;
          WebContinuousSpellCheckingEnabled = true;
          WebAutomaticSpellingCorrectionEnabled = false;
          AutoFillFromAddressBook = false;
          AutoFillCreditCardData = false;
          AutoFillMiscellaneousForms = false;
          WarnAboutFraudulentWebsites = true;
          "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" = true;
          "com.apple.Safari.ContentPageGroupIdentifier.WebKit2BackspaceKeyNavigationEnabled" = false;
        };

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
    };

    stateVersion = 5;
  };
}
