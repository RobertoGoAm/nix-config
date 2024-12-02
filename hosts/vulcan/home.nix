{ ... }:
{
  home = {
    stateVersion = "24.05";
  };

  programs = {
    home-manager = {
      enable = true;
    };

    java = {
      enable = true;
    };

    starship = {
      enable = true;
    };

    zsh = {
      enable = true;
      enableCompletion = true;
      syntaxHighlighting = {
        enable = true;
      };
      oh-my-zsh = {
        enable = true;
      };
    };
  };

  # App settings
  imports = [
    ../../programs/chromium.nix
    ../../programs/vscode.nix
  ];
}
