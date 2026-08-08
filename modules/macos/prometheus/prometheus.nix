{ user, ... }:
let
  privatePath = "/Users/${user}/.config/nix-secrets/work-extras.nix";
  private =
    if builtins.pathExists privatePath then
      import privatePath { }
    else
      {
        macDockApps = [ ];
      };
in
{
  imports = [
    ../default.nix
    ./casks.nix
    ../services/aerospace
    ../services/warpd
  ];

  networking.hostName = "prometheus";

  system.defaults.dock.persistent-apps = [
    "/System/Applications/Calendar.app"
    "/System/Applications/System Settings.app"
    "/Users/${user}/Applications/Home Manager Apps/Firefox.app"
    "/Users/${user}/Applications/Home Manager Apps/Chromium.app"
    "/Users/${user}/Applications/Home Manager Apps/Chromium Dev.app"
    "/System/Applications/Mail.app"
    "/Users/${user}/Applications/Home Manager Apps/Spotify.app"
    "/Users/${user}/Applications/Home Manager Apps/Visual Studio Code.app"
    "/Users/${user}/Applications/Home Manager Apps/Antigravity IDE.app"
    "/Users/${user}/Applications/Home Manager Apps/Cursor.app"
    "/Users/${user}/Applications/Home Manager Apps/Alacritty.app"
    "/Users/${user}/Applications/Home Manager Apps/Telegram.app"
    "/Users/${user}/Applications/Home Manager Apps/Obsidian.app"
  ]
  ++ private.macDockApps;

  home-manager.users.${user} = import ../../home-manager/hosts/prometheus/prometheus.nix;
}
