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
  ]
  ++ (
    # Machine-local private module (kept out of the public repo). Absent ⇒ no-op,
    # so this file never reveals what it loads. Same pattern as work-extras.nix.
    let
      privateModule = "/Users/${user}/.config/nix-secrets/vulcan-services/default.nix";
    in
    if builtins.pathExists privateModule then [ privateModule ] else [ ]
  );

  networking.hostName = "vulcan";

  system.defaults.dock.persistent-apps = [
    "/System/Applications/Calendar.app"
    "/System/Applications/System Settings.app"
    # Chrome is the work browser and comes from the homebrew cask, so it lives in
    # /Applications rather than the home-manager tree.
    "/Applications/Google Chrome.app"
    # "Zen Browser (Beta).app" is the bundle name the package ships -- the
    # darwin build is the beta channel, and the name carries that. It changes
    # if the channel does, and a dock entry pointing at a missing path just
    # silently shows nothing.
    "/Users/${user}/Applications/Home Manager Apps/Zen Browser (Beta).app"
    "/System/Applications/Mail.app"
    "/Users/${user}/Applications/Home Manager Apps/Spotify.app"
    "/Users/${user}/Applications/Home Manager Apps/Visual Studio Code.app"
    "/Users/${user}/Applications/Home Manager Apps/Antigravity IDE.app"
    "/Users/${user}/Applications/Home Manager Apps/Cursor.app"
    "/Users/${user}/Applications/Home Manager Apps/Alacritty.app"
    "/Users/${user}/Applications/Home Manager Apps/iTerm2.app"
    "/Applications/Telegram.app"
    "/Users/${user}/Applications/Home Manager Apps/Obsidian.app"
  ]
  ++ private.macDockApps;

  home-manager.users.${user} = import ../../home-manager/hosts/vulcan/vulcan.nix;
}
