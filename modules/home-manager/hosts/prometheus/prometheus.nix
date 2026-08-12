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

  # Tried and not kept. The workspace pills were the only real draw, and they
  # did not outweigh rebuilding a menu bar that already worked — app menus alone
  # would have needed a helper that is not packaged. The module stays in the
  # tree so turning it back on is this one line.
  features.desktop.sketchybar.enable = false;

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
    ../../features/cli/k9s.nix
    ../../features/development
    ../../features/development/cursor.nix
    ../../features/development/antigravity.nix
    ../../features/internet/chromium.nix
    ../../features/internet/chromium-dev.nix
    ../../features/internet/cyberduck.nix
    ../../features/internet/discord.nix
    ../../features/internet/firefox.nix
    ../../features/media/iina.nix
    ../../features/media/yt-dlp.nix
    ../../features/productivity/karabiner.nix
    ../../features/productivity/keyboard
    ../../features/productivity/obsidian
    ../../features/productivity/wallpaper
    ../../features/desktop/vorssaint.nix
    ../../features/desktop/swiftbar
    ../../features/desktop/sketchybar
    ../../features/desktop/warpd
    ../../features/backup/restic
  ];
}
