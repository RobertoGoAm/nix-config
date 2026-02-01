{
  homebrew = {
    enable = true;
    casks = [
      # Development
      "cursor"
      "imageoptim"
      "ngrok"
      "postman"
      "rancher"
      "springtoolsforeclipse"
      "zulu"

      # Internet
      "google-chrome"
      "qbittorrent"

      # Media
      "iina"
      "macmediakeyforwarder"
      "spotify"
      "vlc"

      # Office
      "pdf-expert"

      # Productivity
      "anki"
      "notion"
      "obsidian"
      "raycast"
      "remnote"

      # Security
      "bitwarden"
      "blockblock"
      "gpg-suite"
      "oversight"
      "ransomwhere"

      # Social
      "discord"
      "telegram"

      # Tool
      "calibre"
      "cyberduck"
      "filen"
      "multipass"
      "omnidisksweeper"
      "qmk-toolbox"
      "the-unarchiver"
      "via"

      # Work
      "omnissa-horizon-client"
      "microsoft-teams"
    ];

    # These app IDs are from using the mas CLI app
    # mas = mac app store
    # https://github.com/mas-cli/mas
    #
    # $ nix shell nixpkgs#mas
    # $ mas search <app name>
    #
    masApps = { };
  };
}
