{ user, ... }:
{
  imports = [
    ../default.nix
    ./casks.nix
  ];

  networking.hostName = "vulcan";

  system.defaults.dock.persistent-apps = [
    "/System/Applications/Calendar.app"
    "/System/Applications/System Settings.app"
    "/Users/${user}/Applications/Home Manager Apps/Firefox.app"
    "/Users/${user}/Applications/Home Manager Apps/Chromium.app"
    "/System/Applications/Mail.app"
    "/Users/${user}/Applications/Home Manager Apps/Spotify.app"
    "/Users/${user}/Applications/Home Manager Apps/Visual Studio Code.app"
    "/Users/${user}/Applications/Home Manager Apps/Antigravity.app"
    "/Users/${user}/Applications/Home Manager Apps/Cursor.app"
    "/Users/${user}/Applications/Home Manager Apps/Alacritty.app"
    "/Users/${user}/Applications/iTerm2.app"
    "/Users/${user}/Applications/Home Manager Apps/Telegram.app"
    "/Applications/Obsidian.app"
    "/Applications/Omnissa Horizon Client.app"
  ];

  home-manager.users.${user} = import ../../home-manager/hosts/vulcan/vulcan.nix;
}
