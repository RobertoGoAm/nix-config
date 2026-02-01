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
    ngrok
    nixd
    nixfmt-rfc-style
    stack
    zulu

    # Productivity
    anki-bin
    obsidian
    raycast

    # Social
    discord
    telegram-desktop

    # Tool
    ansible
    coreutils
    nerd-fonts.jetbrains-mono
    procps
    ripgrep
    vlc-bin

    # Work

    # Work
    git-credential-manager
    openfortivpn
  ];
}
