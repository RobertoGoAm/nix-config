{ pkgs, ... }:
{
  programs.ssh = {
    enable = true;

    # Disable the deprecated default config to suppress warning
    # and manually define what we need in matchBlocks.
    enableDefaultConfig = false;

    matchBlocks = {
      "*" = {
        addKeysToAgent = "yes";
      };
      "github.com" = {
        identityFile = "~/.ssh/id_ed25519";
      };
      "gitlab.com" = {
        identityFile = "~/.ssh/id_ed25519";
      };
      # Example for work-related hosts if they use specific keys
      "idrica-host" = {
        hostname = "*.idrica.com";
        identityFile = "~/.ssh/idrica_ed25519";
      };
      "typsa-host" = {
        hostname = "*.typsa.com";
        identityFile = "~/.ssh/typsa";
      };
    };

    extraConfig = ''
      # Use macOS keychain for SSH key passphrases
      UseKeychain yes
    '';
  };
}
