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

      alias = {
        co = "checkout";
        st = "status";
        br = "branch";
        last = "log -1 HEAD";
        unstage = "reset HEAD --";
        dc = "diff --cached";
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
