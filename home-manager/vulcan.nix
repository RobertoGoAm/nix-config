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
    overlays = [
      outputs.overlays.apple-silicon
    ];

    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };

  home = {
    username = "robertogoam";
    homeDirectory = "/Users/robertogoam";
    stateVersion = "24.11";
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
  ];
}
