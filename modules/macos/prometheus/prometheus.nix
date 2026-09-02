# macos prometheus prometheus

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

  # And LocalHostName, or macOS renames it behind your back

  # hostName and computerName were pinned; LocalHostName -- the Bonjour name, the
  # one behind prometheus.local -- was not, so macOS was free to change it and
  # did: it became "prometheus-2" after a name collision on the network. A Mac
  # that sees its own advertisement on a second interface is enough to trigger
  # that, and once renamed it stays renamed.

  # Nothing broke, because `hostname -s' reads hostName and that is what selects
  # the darwinConfiguration. But prometheus.local stopped resolving to this
  # machine, and the rename is silent.

  # Pinned here so activation restores it, and any future collision is undone by
  # the next rebuild rather than persisting.

  networking.localHostName = "prometheus";

  # Tailscale registers a node under the machine's ComputerName, not...

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

    # Chrome is the work browser and comes from the homebrew cask, so it...

    # Chrome is the work browser and comes from the homebrew cask, so it lives in
    # /Applications rather than the home-manager tree.

    "/Applications/Google Chrome.app"

    # "Zen Browser (Beta).app" is the bundle name the package ships -- the

    # darwin build is the beta channel, and the name carries that. It changes
    # if the channel does, and a dock entry pointing at a missing path just
    # silently shows nothing.

    "/Users/${user}/Applications/Home Manager Apps/Zen Browser (Beta).app"
    "/Users/${user}/Applications/Home Manager Apps/Chrome Dev.app"
    "/System/Applications/Mail.app"
    "/Users/${user}/Applications/Home Manager Apps/Spotify.app"

    # Emacs.app, not Emacs Client.app

    # The entry has to be the bundle the daemon itself runs from. Emacs Client.app
    # is a launcher: it runs emacsclient and exits, so there is no process for the
    # Dock to mark as running, and the frame it opens belongs to the daemon -- a
    # different app, under its own icon. Pinning the launcher gives an icon with no
    # running indicator that appears to open something else.

    # One consequence to know: clicking this icon while the daemon has no frames
    # open does nothing. Emacs does not implement applicationShouldHandleReopen --
    # the symbol does not appear in the binary at all -- so AppKit has nothing to
    # call. Emacs Client.app stays installed, unpinned, for exactly that case.

    "/Users/${user}/Applications/Home Manager Apps/Emacs.app"
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
