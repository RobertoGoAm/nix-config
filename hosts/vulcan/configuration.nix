{ ... }:
{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
  };

  services.nix-daemon.enable = true;

  networking.hostName = "vulcan";

  nixpkgs.config.allowUnfree = true;
  
  system.activationScripts.extraActivation.text = ''
    softwareupdate --install-rosetta --agree-to-license
  '';

  system.stateVersion = 5;
}
