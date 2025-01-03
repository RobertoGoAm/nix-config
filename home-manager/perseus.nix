{ inputs
, outputs
, lib
, config
, pkgs
, system
, ...
}: {
  nixpkgs = {
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };

  fonts.fontconfig.enable = true;

  home = {
    homeDirectory = "/home/robertogoam";
    stateVersion = "24.11";
    username = "robertogoam";

    activation = {
      linkDesktopApplications = {
        after = [ "writeBoundary" "createXdgUserDirectories" ];
        before = [ ];
        data = ''
          rm -rf $HOME/.home-manager-share
          mkdir -p $HOME/.home-manager-share
          cp -Lr --no-preserve=mode,ownership ${config.home.homeDirectory}/.nix-profile/share/* $HOME/.home-manager-share
        '';
      };
    };

    packages = with pkgs; [
      # Internet
      google-chrome

      # Development
      nixd

      # Media
      spotify
      vlc

      # Productivity
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
  };

  programs.home-manager.enable = true;

  imports = [
    inputs.nixvim.homeManagerModules.nixvim
    ./features/cli
    ./features/desktop/gnome
    ./features/development/git.nix
    ./features/development/java.nix
    ./features/development/nvim
    ./features/development/vscode
    ./features/internet/chromium.nix
    ./features/internet/firefox.nix
    ./features/media/yt-dlp.nix
    ./features/productivity/ulauncher.nix
  ];
}
