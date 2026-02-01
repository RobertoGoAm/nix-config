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

    # Media
    spotify

    # Tool
    ansible
    coreutils
    cyberduck
    nerd-fonts.jetbrains-mono
    procps
    ripgrep
    the-unarchiver
    vlc-bin

    # Work

    # Work

    # Work

    # Work
    git-credential-manager
    openfortivpn
  ];
}
