{ ... }:
{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
  };

  services.nix-daemon.enable = true;

  networking.hostName = "vulcan";

  nixpkgs.config.allowUnfree = true;

  system = {
    activationScripts.extraActivation.text = ''
      softwareupdate --install-rosetta --agree-to-license
    '';

    defaults.CustomUserPreferences = {
      NSGlobalDomain = {
        "com.apple.swipescrolldirection" = false;
      };
    };

    stateVersion = 5;
  };
}
