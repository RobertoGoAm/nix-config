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
    ngrok
    nixd
    nixfmt-rfc-style
    postman
    stack

    # Productivity
    anki-bin
    raycast

    # Social
    telegram-desktop

    # Media
    iina
    spotify

    # Tool
    ansible
    coreutils
    cyberduck
    nerd-fonts.jetbrains-mono
    procps
    qbittorrent
    the-unarchiver
    vlc-bin

    # Work
    git-credential-manager
    openfortivpn
  ];
}
