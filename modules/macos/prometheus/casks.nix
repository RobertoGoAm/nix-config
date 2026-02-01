{
  homebrew = {
    enable = true;
    casks = [
      # Development
      "imageoptim"
      "postman"
      "rancher"
      "springtoolsforeclipse"

      # Internet
      "google-chrome"

      # Media
      "macmediakeyforwarder"

      # Office
      "pdf-expert"

      # Productivity
      "notion"
      "remnote"

      # Security
      "bitwarden"
      "blockblock"
      "gpg-suite"
      "oversight"
      "ransomwhere"

      # Tool
      "calibre"
      "filen"
      "multipass"
      "omnidisksweeper"
      "qmk-toolbox"
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
