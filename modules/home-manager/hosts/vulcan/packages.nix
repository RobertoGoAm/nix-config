{
  pkgs,
  ...
}:
{

  home.packages = with pkgs; [
    # Development
    cabal-install
    ghc
    haskell-language-server
    nixd
    nixfmt-rfc-style
    stack

    # Tool
    nerd-fonts.jetbrains-mono

    # Work
    git-credential-manager
  ];
}
