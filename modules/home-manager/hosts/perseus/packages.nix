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
    nixd
    nixfmt-rfc-style

    # Internet
    google-chrome

    # Media
    spotify
    vlc

    # Productivity
    gnome-calendar
    remnote

    # Security
    bitwarden

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
    git-credential-manager
    postman
    teams-for-linux
    vmware-horizon-client
  ];
}
