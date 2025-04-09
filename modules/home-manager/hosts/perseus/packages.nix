{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    # Desktop
    gnomeExtensions.forge
    gnomeExtensions.space-bar
    gnomeExtensions.spotify-tray

    # Development
    ghc
    gcc
    gnumake
    haskell-language-server
    nixd
    nixfmt-rfc-style

    # Internet
    google-chrome

    # Media
    spotify
    vlc

    # Productivity
    gnome-calendar
    obsidian
    remnote

    # Security
    bitwarden
    libsecret

    # Social
    discord
    telegram-desktop

    # Tool
    fasd
    gnutar
    nanum
    nerd-fonts.jetbrains-mono
    qbittorrent
    xclip

    # Work
    code-cursor
    git-credential-manager
    lmstudio
    postman
    teams-for-linux
    vmware-horizon-client
  ];
}
