{ pkgs, ... }:
{
  programs.git = {
    enable = true;
    package = pkgs.gitFull;
    extraConfig = {
      pull = {
        rebase = false;
      };
    } // (if pkgs.stdenv.isLinux then {
      credential.helper = "libsecret";
    } else {});
  };
}