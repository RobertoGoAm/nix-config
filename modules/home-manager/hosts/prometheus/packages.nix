{
  pkgs,
  ...
}:
{

  home.packages = with pkgs; [
    # Development
    antigravity
    cabal-install
    claude-code
    chatgpt
    code-cursor
    cursor-cli
    fnm
    ghc
    gemini-cli
    glab
    haskell-language-server
    jq
    karabiner-elements
    nixd
    nixfmt-rfc-style
    stack

    # Productivity
    raycast

    # Tool
    ansible
    coreutils
    nerd-fonts.jetbrains-mono
    procps
    ripgrep

    # Work
    git-credential-manager
    openfortivpn
  ];
}
