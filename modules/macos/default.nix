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
    inputs.sops-nix.darwinModules.sops
    ../homebrew/homebrew.nix
  ]
  ++ (
    # Machine-local sops secrets (client/work SSH keys). Kept out of the
    # public nix-config repo because the secret KEY NAMES leak client
    # identities. The file declares additional `config.sops.secrets.*`
    # entries that merge into the set defined below.
    let
      privateSopsPath = "/Users/${user}/.config/nix-secrets/sops-secrets.nix";
    in
    if builtins.pathExists privateSopsPath then [ privateSopsPath ] else [ ]
  );

  options.features.security.sops.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to enable SOPS secret management.";
  };

  config = {
    sops = lib.mkIf config.features.security.sops.enable {
      defaultSopsFile = "/Users/${user}/.config/nix-secrets/secrets.yaml";
      validateSopsFiles = false;
      age = {
        keyFile = "/Users/${user}/.config/sops/age/system_keys.txt";
        sshKeyPaths = [ ];
      };
      # System-level secrets. Generic ones (your own personal keys + env
      # tokens) live here; anything that names a client lives in the
      # machine-local sops-secrets.nix that's conditionally imported above.
      secrets = {
        user_password = {
          owner = user;
        };
        npm_token = {
          owner = user;
        };
        gitlab_access_token = {
          owner = user;
        };
        ntfy_topic_id = {
          owner = user;
        };
        ssh_id_ed25519 = {
          owner = user;
          path = "/Users/${user}/.ssh/id_ed25519";
        };
        ssh_id_ed25519_robertogoam = {
          owner = user;
          path = "/Users/${user}/.ssh/id_ed25519_robertogoam";
        };
        ssh_id_rsa = {
          owner = user;
          path = "/Users/${user}/.ssh/id_rsa";
        };
        # *.pub files are not stored in sops — derive them from the private
        # keys above with the `pubkey-setup` command (see features/security).
      };
    };

    services.tailscale.enable = true;
    # Application firewall — currently on; lock it on (the old system.defaults.alf
    # was removed upstream in favour of this option).
    networking.applicationFirewall.enable = true;
    services.openssh = {
      enable = true;
      extraConfig = ''
        PasswordAuthentication no
        PermitRootLogin no
      '';
    };

    security.pam.services.sudo_local = {
      touchIdAuth = true;
      watchIdAuth = true;
      reattach = true;
    };

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
        outputs.overlays.direnv
        outputs.overlays.kubernetes-helm
      ];
      config = {
        allowUnfree = true;
        allowUnfreePredicate = (_: true);
        # checkov pulls in python-ecdsa, marked insecure in nixpkgs (CVE-2024-23342).
        permittedInsecurePackages = [
          "python3.13-ecdsa-0.19.2"
        ];
      };
      hostPlatform = "aarch64-darwin";
    };

    system = {
      primaryUser = user;
      activationScripts.postActivation.text = ''
        sudo -u ${user} /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
        killall SystemUIServer || true
        killall Finder || true
        killall Dock || true
      '';

      defaults = {
        NSGlobalDomain = {
          ApplePressAndHoldEnabled = false;
          AppleInterfaceStyle = "Dark";
          "com.apple.swipescrolldirection" = false;
          KeyRepeat = 2;
          InitialKeyRepeat = 25;
          AppleShowAllExtensions = true;
          NSNavPanelExpandedStateForSaveMode = true;
          NSNavPanelExpandedStateForSaveMode2 = true;
          AppleShowScrollBars = "Always";
          NSAutomaticCapitalizationEnabled = false;
          NSAutomaticDashSubstitutionEnabled = false;
          NSAutomaticPeriodSubstitutionEnabled = false;
          NSAutomaticQuoteSubstitutionEnabled = false;
          NSAutomaticSpellingCorrectionEnabled = false;
          AppleKeyboardUIMode = 3;
          # Pinned to documented macOS defaults (were unset) for full reproducibility.
          # NOT pinned, deliberately: AppleFontSmoothing (harms Retina text),
          # Apple{ICUForce24HourTime,MeasurementUnits,MetricUnits,TemperatureUnit}
          # (locale-driven), com.apple.mouse.tapBehavior (no clean off value).
          AppleEnableMouseSwipeNavigateWithScrolls = true;
          AppleEnableSwipeNavigateWithScrolls = true;
          AppleScrollerPagingBehavior = false;
          AppleSpacesSwitchOnActivate = true;
          AppleWindowTabbingMode = "fullscreen";
          NSAutomaticInlinePredictionEnabled = true;
          NSAutomaticWindowAnimationsEnabled = true;
          NSDisableAutomaticTermination = false;
          NSDocumentSaveNewDocumentsToCloud = true;
          NSScrollAnimationEnabled = true;
          NSTableViewDefaultSizeMode = 2;
          NSTextShowsControlCharacters = false;
          NSUseAnimatedFocusRing = true;
          NSWindowResizeTime = 0.2;
          _HIHideMenuBar = false;
          "com.apple.keyboard.fnState" = false;
          "com.apple.sound.beep.feedback" = 1;
          "com.apple.sound.beep.volume" = 0.6784667;
          "com.apple.springing.delay" = 0.5;
          "com.apple.springing.enabled" = true;
          "com.apple.trackpad.enableSecondaryClick" = true;
          "com.apple.trackpad.forceClick" = true;
          "com.apple.trackpad.scaling" = 0.875;
        };
        finder = {
          FXDefaultSearchScope = "SCcf";
          FXPreferredViewStyle = "Nlsv";
          NewWindowTarget = "Home";
          ShowPathbar = true;
          ShowStatusBar = true;
          QuitMenuItem = true;
          FXEnableExtensionChangeWarning = false;
          # Desktop icons — locked to current state.
          ShowExternalHardDrivesOnDesktop = true;
          ShowHardDrivesOnDesktop = false;
          ShowRemovableMediaOnDesktop = true;
          ShowMountedServersOnDesktop = false;
          _FXShowPosixPathInTitle = false;
          # Pinned to macOS defaults (were unset).
          AppleShowAllFiles = false;
          CreateDesktop = true;
          FXRemoveOldTrashItems = false;
          _FXSortFoldersFirst = false;
        };
        dock = {
          autohide = false;
          tilesize = 38;
          orientation = "left";
          mru-spaces = false; # don't auto-rearrange Spaces by most-recent use
          show-recents = false;
          # Hot corners all disabled (1 = no action).
          wvous-tl-corner = 1;
          wvous-tr-corner = 1;
          wvous-bl-corner = 1;
          wvous-br-corner = 1;
          # Right-side folder stacks. Downloads sorted most-recent-first; the
          # ~/Development stack is created by features/development on activation.
          persistent-others = [
            {
              folder = {
                path = "/Users/${user}/Downloads";
                arrangement = "date-modified";
              };
            }
            { folder = "/Users/${user}/Development"; }
          ];
          # Pinned to macOS defaults (were unset).
          appswitcher-all-displays = false;
          autohide-delay = 0.24;
          autohide-time-modifier = 1.0;
          expose-group-apps = false;
          launchanim = true;
          magnification = false;
          mineffect = "genie";
          minimize-to-application = false;
          mouse-over-hilite-stack = false;
          scroll-to-open = false;
          show-process-indicators = true;
          showhidden = false;
          static-only = false;
        };
        loginwindow.GuestEnabled = false;
        loginwindow.SHOWFULLNAME = true;
        screensaver = {
          askForPassword = true;
          askForPasswordDelay = 0;
        };
        SoftwareUpdate.AutomaticallyInstallMacOSUpdates = true;

        # Control Center / menu-bar items. true = show icon in the menu bar,
        # false = hide it. Bluetooth + Focus hidden per preference.
        controlcenter = {
          AirDrop = false;
          BatteryShowPercentage = false;
          Bluetooth = false;
          Display = false;
          FocusModes = false;
          NowPlaying = true;
          Sound = true;
        };

        # Stage Manager off (current); standard edge-tiling on (macOS defaults).
        WindowManager = {
          GloballyEnabled = false;
          AutoHide = false;
          AppWindowGroupingBehavior = true;
          EnableTiledWindowMargins = false;
          HideDesktop = true;
          EnableStandardClickToShowDesktop = true;
          EnableTilingByEdgeDrag = true;
          EnableTopTilingByEdgeDrag = true;
          StandardHideDesktopIcons = false;
        };

        # Screenshots — PNG to Desktop (current behaviour, now explicit).
        screencapture = {
          target = "file";
          type = "png";
          disable-shadow = false;
          show-thumbnail = true;
          location = "~/Desktop";
        };

        spaces.spans-displays = false; # displays keep separate Spaces (default)
        magicmouse.MouseButtonMode = "OneButton";

        # Trackpad — locked to current state (tap-to-click off, two-finger right-click).
        trackpad = {
          Clicking = false;
          Dragging = false;
          TrackpadRightClick = true;
          TrackpadThreeFingerDrag = false;
          ActuationStrength = 1;
          FirstClickThreshold = 1;
          SecondClickThreshold = 1;
          TrackpadMomentumScroll = true;
        };
      };
      keyboard.enableKeyMapping = true;
      stateVersion = 5;
    };

    environment.systemPackages = [
      pkgs.age-plugin-yubikey
    ];

    users.users.${user} = {
      packages = [
        pkgs.home-manager
      ];
      home = "/Users/${user}";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDdHwSIjtrWvblappuu12T8lavKLPrhbLRMbNiHTCWuq mobile-ssh-1"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMOwqeO12WNRNFxGNZKBG+VHJKLkc6JvOvRUdQkius4S mobile-ssh-2"
      ];
    };

    home-manager = {
      backupFileExtension = "backup";
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = {
        inherit inputs outputs user;
        system = "aarch64-darwin";
      };
    };
  };
}
