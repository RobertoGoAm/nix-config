{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    # Internet
    google-chrome

    # Development
    nixd
    nixfmt-rfc-style

    # Media
    spotify
    vlc

    # Productivity
    gnome-calendar
    gnome-extension-manager
    gnomeExtensions.forge
    gnomeExtensions.spotify-tray
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
