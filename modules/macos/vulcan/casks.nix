{
  homebrew = {
    enable = true;
    casks = [
      # Development
      "docker"
      "imageoptim"
      "rancher"

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
      "omnidisksweeper"
      "qmk-toolbox"
      "via"

      # Work
      "omnissa-horizon-client"
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
