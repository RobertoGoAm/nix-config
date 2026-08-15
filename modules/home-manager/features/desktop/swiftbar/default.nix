{ config, lib, pkgs, ... }:
let
  pluginDir = "${config.home.homeDirectory}/.config/swiftbar/plugins";

  # One item, not seven. SwiftBar gives each plugin its own menu bar slot, and
  # most of them read green almost always — width spent to say nothing. The
  # single item rotates vitals, health and the current track through one slot,
  # and the renderer puts the detail in submenus. The 30s in the filename is
  # SwiftBar's refresh interval; the rotation speed itself is fixed and not
  # configurable.
in
lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  # macmon reads Apple Silicon's counters through IOReport, so the system plugin
  # gets CPU/GPU temperature and power without sudo — powermetrics would have
  # needed root, which a menu bar plugin must never have.
  home.packages = [ pkgs.macmon ];

  # Plugins run detached from a login shell, so each one sets its own PATH.
  # Two traps worth knowing if you write more: this profile's `date` is GNU
  # coreutils and has no BSD `-j`, and `route` lives in /sbin, which is not on
  # a default PATH.
  # The renderer lives outside the plugin directory on purpose. SwiftBar
  # executes everything it finds in there, and a .py file with no shebang gets
  # handed to the shell — which then tries to run the docstring as a command
  # and litters the bar with a broken item.
  home.file = {
    ".config/swiftbar/lib/status-render.py".source = ./plugins/status-render.py;
    ".config/swiftbar/lib/status.sh" = {
      source = ./plugins/status.30s.sh;
      executable = true;
    };
  };

  # The plugin itself is a real file, copied rather than symlinked, because
  # SwiftBar identifies a menu bar item by its *resolved* path. A store symlink
  # changes hash whenever the script does, so every rebuild would look like a
  # brand-new item: it loses its position in the bar, gets re-hidden by a menu
  # bar manager, and leaves a stale NSStatusItem preference behind each time.
  # A two-line shim at a fixed path never changes, so the identity is stable and
  # the logic still lives in the store.
  home.activation.swiftbarPlugin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "${pluginDir}"
    # Written with cat, not `install /dev/stdin`: this profile's install is GNU
    # coreutils, which refuses that with "replaced while being copied". It failed
    # silently and left no plugin at all, so SwiftBar showed its own icon.
    cat > "${pluginDir}/status.30s.sh" <<'SHIM'
#!/bin/sh
exec "$HOME/.config/swiftbar/lib/status.sh"
SHIM
    run chmod 755 "${pluginDir}/status.30s.sh"
  '';

  # Point SwiftBar at the managed directory so the plugins are whatever this
  # module says they are, not whatever got dragged in.
  targets.darwin.defaults."com.ameba.SwiftBar" = {
    PluginDirectory = pluginDir;
    SwiftBarLaunchAtLogin = true;
    MakePluginExecutable = true;
  };
}
