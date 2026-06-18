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

  programs.home-manager.enable = true;

  features.development.antigravity.appPath = "/Users/${user}/Applications/Home Manager Apps/Antigravity.app";

  imports = [
    inputs.nixvim.homeModules.nixvim
    inputs.sops-nix.homeManagerModules.sops
    ../../modules/iterm2.nix
    ./packages.nix
    ../../features/cli
    ../../features/security
    ../../features/cli/iterm2.nix
    ../../features/cli/k9s.nix
    ../../features/development
    ../../features/development/cursor.nix
    ../../features/development/antigravity.nix
    ../../features/internet/chromium.nix
    ../../features/internet/chromium-dev.nix
    ../../features/internet/discord.nix
    ../../features/internet/firefox.nix
    ../../features/media/yt-dlp.nix
    ../../features/productivity
    ../../features/productivity/keyboard
    ../../features/productivity/wallpaper
    ../../features/desktop/warpd
  ];
}
