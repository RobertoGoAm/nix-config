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
    overlays = [
      outputs.overlays.apple-silicon
    ];

    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };

  home = {
    homeDirectory = "/Users/${user}";
    stateVersion = "24.11";
    username = user;
  };

  programs.home-manager.enable = true;

  imports = [
    inputs.nixvim.homeManagerModules.nixvim
    ./packages.nix
    ../../features/cli
    ../../features/development
    ../../features/internet/chromium.nix
    ../../features/internet/firefox.nix
    ../../features/media/yt-dlp.nix
  ];
}
