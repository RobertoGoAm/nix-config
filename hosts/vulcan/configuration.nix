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
      CustomUserPreferences = {
        alf = {
          # Enable Firewall
          globalstate = 1;
        };

        NSGlobalDomain = {
          # Disable natural scrolling
          "com.apple.swipescrolldirection" = false;
        };
      };
    };

    stateVersion = 5;
  };
}
