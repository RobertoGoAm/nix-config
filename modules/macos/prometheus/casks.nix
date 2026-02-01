{
  homebrew = {
    enable = true;
    casks = [
      # Development
      "cursor"
      "imageoptim"
      "postman"
      "rancher"
      "springtoolsforeclipse"

      # Internet
      "google-chrome"
      "qbittorrent"

      # Media
      "iina"
      "macmediakeyforwarder"
      "spotify"

      # Office
      "pdf-expert"

      # Productivity
      "notion"
      "raycast"
      "remnote"

      # Security
      "bitwarden"
      "blockblock"
      "gpg-suite"
      "oversight"
      "ransomwhere"

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
