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
  home = {
    homeDirectory = "/Users/${user}";
    stateVersion = "25.11";
    username = user;
  };

  programs.home-manager = {
    enable = true;
  };

  imports = [
    inputs.nixvim.homeModules.nixvim
    inputs.sops-nix.homeManagerModules.sops
    ../../modules/iterm2.nix
    ./packages.nix
    ../../features/cli
    ../../features/security
    ../../features/cli/iterm2.nix
    ../../features/development
    ../../features/internet/chromium.nix
    ../../features/internet/chromium-dev.nix
    ../../features/internet/discord.nix
    ../../features/internet/firefox.nix
    ../../features/media/yt-dlp.nix
  ];
}
