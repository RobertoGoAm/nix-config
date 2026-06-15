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
        ssh_id_ed25519_pub = {
          owner = user;
          path = "/Users/${user}/.ssh/id_ed25519.pub";
        };
        ssh_id_ed25519_robertogoam = {
          owner = user;
          path = "/Users/${user}/.ssh/id_ed25519_robertogoam";
        };
        ssh_id_ed25519_robertogoam_pub = {
          owner = user;
          path = "/Users/${user}/.ssh/id_ed25519_robertogoam.pub";
        };
        ssh_id_rsa = {
          owner = user;
          path = "/Users/${user}/.ssh/id_rsa";
        };
        ssh_id_rsa_pub = {
          owner = user;
          path = "/Users/${user}/.ssh/id_rsa.pub";
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
