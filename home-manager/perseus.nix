{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  system,
  ...
}: {
  nixpkgs = {
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };

  fonts.fontconfig.enable = true;

  home = {
    username = "robertogoam";
    homeDirectory = "/home/robertogoam";
    stateVersion = "24.11";

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
  };

  programs.home-manager.enable = true;

  imports = [
    inputs.nixvim.homeManagerModules.nixvim
    ./features/cli
    ./features/development/git.nix
    ./features/development/java.nix
    ./features/development/nvim
    ./features/development/vscode
    ./features/internet/chromium.nix
    ./features/internet/firefox.nix
    ./services/productivity
  ];
}
