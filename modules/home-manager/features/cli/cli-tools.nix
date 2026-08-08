{ pkgs, ... }:
{
  # Reports the version pins nothing updates for us; the nix-build/nix-update
  # functions in zsh.nix call it after every rebuild.
  home.packages = [ pkgs.check-pins ];

  programs.bat = {
    enable = true;
    config = {
      theme = "TwoDark";
    };
  };

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    mise.enable = true;
    nix-direnv.enable = true;
  };

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    icons = "auto";
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.jq.enable = true;

  programs.mise = {
    enable = true;
    enableZshIntegration = true;

    # Host-level mise is global-only: per-project tool versions live inside dev
    # containers, not on the host, so there's no `mise use -g` to preserve and
    # the read-only config.toml is fine.
    globalConfig = {
      tools = {
        usage = "latest";
        node = "lts";
      };
    };
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
}
