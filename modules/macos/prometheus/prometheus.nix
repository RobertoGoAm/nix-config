{ lib, user, ... }:
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
  # Tailscale registers a node under the machine's ComputerName, not hostName;
  # without this the standalone client came up as "robertos-macbook-pro".
  networking.computerName = "prometheus";

  # Tailscale comes from the tailscale-app cask here, which runs its own
  # tailscaled and installs a matching CLI at /usr/local/bin/tailscale. The nix
  # client that services.tailscale puts on PATH is a different build of the same
  # version, so every command warned about a client/server mismatch against a
  # daemon it does not even manage. Scoped to this host: vulcan configures
  # tailscale from the private nix-secrets tree, not from the shared default.
  services.tailscale.enable = lib.mkForce false;

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
    "/Applications/Telegram.app"
    "/Users/${user}/Applications/Home Manager Apps/Obsidian.app"
  ]
  ++ private.macDockApps;

  home-manager.users.${user} = import ../../home-manager/hosts/prometheus/prometheus.nix;
}
