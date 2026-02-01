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
      "REDACTED-host" = {
        hostname = "*.REDACTED.com";
        identityFile = "~/.ssh/REDACTED_ed25519";
      };
      "REDACTED-host" = {
        hostname = "*.REDACTED.com";
        identityFile = "~/.ssh/REDACTED";
      };
    };

    extraConfig = ''
      # Use macOS keychain for SSH key passphrases
      UseKeychain yes
    '';
  };
}
