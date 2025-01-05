{
  config,
  inputs,
  lib,
  outputs,
  pkgs,
  system,
  user,
  ...
}:
{
  nixpkgs = {
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };

  fonts.fontconfig.enable = true;

  home = {
    homeDirectory = "/home/${user}";
    stateVersion = "24.11";
    username = user;

    activation = {
      linkDesktopApplications = {
        after = [
          "writeBoundary"
          "createXdgUserDirectories"
        ];
        before = [ ];
        data = ''
          rm -rf $HOME/.home-manager-share
          mkdir -p $HOME/.home-manager-share
          cp -Lr --no-preserve=mode,ownership $HOME/.nix-profile/share/* $HOME/.home-manager-share
        '';
      };
    };

    # Fix for gnome apps not openning due to vulcan driver issues
    sessionVariables = {
      GDK_DISABLE = "gles-api";
    };
  };

  programs.home-manager.enable = true;

  imports = [
    inputs.nixvim.homeManagerModules.nixvim
    ./packages.nix
    ../../features/cli
    ../../features/desktop/gnome
    ../../features/development
    ../../features/internet/chromium.nix
    ../../features/internet/firefox.nix
    ../../features/media/yt-dlp.nix
    ../../features/productivity/ulauncher.nix
  ];
}
