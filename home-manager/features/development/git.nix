{ pkgs, ... }:
{
  programs.git = {
    enable = true;
    package = pkgs.gitFull;
    extraConfig = {
      pull = {
        rebase = false;
      };
    } // (if pkgs.stdenv.hostPlatform.isLinux then {
      credential.helper = "libsecret";
    } else { });
  };
}
