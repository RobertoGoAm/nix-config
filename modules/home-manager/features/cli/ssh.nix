{ pkgs, ... }:
{
  programs.ssh = {
    enable = true;
    
    # Disable the deprecated default config to suppress warning
    # and manually define what we need in matchBlocks.
    enableDefaultConfig = false;

    matchBlocks."*" = {
      addKeysToAgent = "yes";
    };

    extraConfig = ''
      # Use macOS keychain for SSH key passphrases
      UseKeychain yes
    '';
  };
}
