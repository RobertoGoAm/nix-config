# home-manager hosts vulcan vulcan

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

  # vulcan is the always-on machine, so the reading stack lives here:...

  # vulcan is the always-on machine, so the reading stack lives here: readeck
  # for read-it-later and calibre-web for the library and its OPDS feed, which
  # is what the e-reader browses.

  features.services.reading.enable = true;

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
    ../../features/internet/chrome-dev.nix
    ../../features/internet/cyberduck.nix
    ../../features/internet/discord.nix
    ../../features/internet/zen.nix
    ../../features/media/iina.nix
    ../../features/media/yt-dlp.nix
    ../../features/productivity
    ../../features/productivity/keyboard
    ../../features/productivity/wallpaper
    ../../features/desktop/warpd
    ../../features/services/reading.nix
  ];
}
