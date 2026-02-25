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
  fonts.fontconfig.enable = true;

  home = {
    homeDirectory = "/home/${user}";
    stateVersion = "25.11";
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
    inputs.nixvim.homeModules.nixvim
    inputs.sops-nix.homeManagerModules.sops
    ./packages.nix
    ../../features/cli
    ../../features/security
    ../../features/desktop/gnome
    ../../features/development
    ../../features/internet/chromium.nix
    ../../features/internet/firefox.nix
    ../../features/media/yt-dlp.nix
    ../../features/productivity
  ];
}
