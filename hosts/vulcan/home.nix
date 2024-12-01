{ ... }:
{
  home = {
    stateVersion = "24.05";
  };

  programs = {
    home-manager = {
      enable = true;
    };

    starship = {
      enable = true;
    };

    vim = {
      enable = true;
      defaultEditor = true;
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
