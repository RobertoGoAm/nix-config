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
    ./services/aerospace
  ];

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
        keyFile = "/Users/${user}/.config/sops/age/keys.txt";
        sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      };
      # System-level secrets
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
        ssh_id_ed25519_pub = {
          owner = user;
          path = "/Users/${user}/.ssh/id_ed25519.pub";
        };
        ssh_id_rsa = {
          owner = user;
          path = "/Users/${user}/.ssh/id_rsa";
        };
        ssh_id_rsa_pub = {
          owner = user;
          path = "/Users/${user}/.ssh/id_rsa.pub";
        };
        ssh_idrica = {
          owner = user;
          path = "/Users/${user}/.ssh/idrica";
        };
        ssh_idrica_pub = {
          owner = user;
          path = "/Users/${user}/.ssh/idrica.pub";
        };
        ssh_idrica_ed25519 = {
          owner = user;
          path = "/Users/${user}/.ssh/idrica_ed25519";
        };
        ssh_idrica_ed25519_pub = {
          owner = user;
          path = "/Users/${user}/.ssh/idrica_ed25519.pub";
        };
        ssh_typsa = {
          owner = user;
          path = "/Users/${user}/.ssh/typsa";
        };
        ssh_typsa_pub = {
          owner = user;
          path = "/Users/${user}/.ssh/typsa.pub";
        };
        ssh_mindden_jose_miguel = {
          owner = user;
          path = "/Users/${user}/.ssh/mindden_jose_miguel";
        };
        ssh_mindden_jose_miguel_pub = {
          owner = user;
          path = "/Users/${user}/.ssh/mindden_jose_miguel.pub";
        };
        ssh_agbar = {
          owner = user;
          path = "/Users/${user}/.ssh/agbar";
        };
        ssh_agbar_pub = {
          owner = user;
          path = "/Users/${user}/.ssh/agbar.pub";
        };
        ssh_vpsweb = {
          owner = user;
          path = "/Users/${user}/.ssh/vpsweb";
        };
        ssh_vpsweb_pub = {
          owner = user;
          path = "/Users/${user}/.ssh/vpsweb.pub";
        };
      };
    };

    services.tailscale.enable = true;
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
      ];
      config = {
        allowUnfree = true;
        allowUnfreePredicate = (_: true);
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
        };
        finder = {
          FXDefaultSearchScope = "SCcf";
          FXPreferredViewStyle = "Nlsv";
          NewWindowTarget = "Home";
          ShowPathbar = true;
          ShowStatusBar = true;
          QuitMenuItem = true;
          FXEnableExtensionChangeWarning = false;
        };
        loginwindow.GuestEnabled = false;
        loginwindow.SHOWFULLNAME = true;
        screensaver = {
          askForPassword = true;
          askForPasswordDelay = 0;
        };
        SoftwareUpdate.AutomaticallyInstallMacOSUpdates = true;
      };
      keyboard.enableKeyMapping = true;
      stateVersion = 5;
    };

    users.users.${user} = {
      packages = [ pkgs.home-manager ];
      home = "/Users/${user}";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDdHwSIjtrWvblappuu12T8lavKLPrhbLRMbNiHTCWuq Generated By Termius"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMOwqeO12WNRNFxGNZKBG+VHJKLkc6JvOvRUdQkius4S Generated By Termius"
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
