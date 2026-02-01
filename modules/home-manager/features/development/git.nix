{ pkgs, ... }:
{
  programs.git = {
    enable = true;
    package = pkgs.gitFull;

    settings = {
      user = {
        email = "RobertoGoAm@disroot.org";
        name = "Roberto Gomez Amores";
      };

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
        {
          credential = {
            helper = "osxkeychain";
          };
        }
    );
  };
}
