{ pkgs, ... }: {
  environment = {
    systemPackages = with pkgs; [
    ];
  };

  homebrew = {
    enable = true;
    caskArgs.no_quarantine = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
      extraFlags = [ "--verbose" ];
    };

    taps = [
      "d12frosted/emacs-plus"
      "homebrew/services"
    ];

    # `brew list <>` can help pinpoint package name
    # for both ordinary packages and casks
    brews = [
      "go"
      "curl"
      "mas"
      "postgresql"
      "tmux"
    ];

    casks = [
      # Development
      "docker"
      "mongodb-compass"
      "ngrok"
      "postman"
      "robo-3t"
      "sequel-pro"
      "visual-studio-code"

      # Fonts
      "font-jetbrains-mono-nerd-font"

      # Internet
      # "brave-browser"
      # "chromium"
      "firefox"
      "google-chrome"

      # Media
      "background-music"
      "calibre"
      "iina"
      "pdf-expert"
      "spotify"
      "vlc"

      # Productivity
      "anki"
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
      "steam"
      "telegram"

      # Tools
      "amethyst"
      "appcleaner"
      "cyberduck"
      "dozer"
      "filen"
      "imageoptim"
      "iterm2"
      "karabiner-elements"
      "macmediakeyforwarder"
      "omnidisksweeper"
      "qbittorrent"
      "qmk-toolbox"
      "raycast"
      "the-unarchiver"
      "via"

      # Work
      "vmware-horizon-client"
    ];

    # `mas search <>` can help pinpoint package name
    masApps = {
      # "Bandwidth+" = 490461369;
    };
  };
}
