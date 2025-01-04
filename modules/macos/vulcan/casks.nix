{
  homebrew = {
    enable = true;
    casks = [
      # Development Tools
      "homebrew/cask/docker"

      # Communication Tools
      "discord"
      "notion"
      "slack"
      "zoom"

      # Utility Tools
      "syncthing"

      # Entertainment Tools
      "vlc"

      # Productivity Tools
      "raycast"

      # Browsers
      "google-chrome"
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
