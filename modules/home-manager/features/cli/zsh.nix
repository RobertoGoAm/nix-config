{
  programs.zsh = {
    enable = true;

    autosuggestion = {
      enable = true;
    };

    enableCompletion = true;

    syntaxHighlighting = {
      enable = true;
    };

    oh-my-zsh = {
      enable = true;
    };
  };

  home.file.".hushlogin" = {
    text = "";
  };
}
