{ pkgs, ... }:
{
  programs.git = {
    enable = true;
    package = pkgs.gitFull;
    userEmail = "RobertoGoAm@disroot.org";
    userName = "Roberto Gomez Amores";

    extraConfig =
      {
        pull = {
          rebase = false;
        };
      }
      // (
        if pkgs.stdenv.hostPlatform.isLinux then
          {
            credential = {
              credentialStore = "secretservice";
              helper = [
                "manager"
                "cache --timeout 21600"
              ];
            };
          }
        else
          { }
      );
  };
}
