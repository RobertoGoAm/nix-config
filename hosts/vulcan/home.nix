{ ... }:
{
  home = {
    stateVersion = "24.05";
  };

  programs = {
    home-manager = {
      enable = true;
    };

    vim = {
      enable = true;
      defaultEditor = true;
    };

    zsh = {
      enable = true;
      enableCompletion = true;
      enableFastSyntaxHighlighting = true;
      enableSyntaxHighlighting = true;
      oh-my-zsh = {
        enable = true;
      };
    };
  };
}
