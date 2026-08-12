{ config, lib, pkgs, ... }:
let
  pluginDir = "${config.home.homeDirectory}/.config/swiftbar/plugins";

  # SwiftBar reads the interval out of the filename (name.INTERVAL.ext), so the
  # schedule lives there rather than in this module.
  plugins = [
    "backup.5m.sh"
    "net.1m.sh"
    "nix.15m.sh"
    "pins.6h.sh"
    "spotify.10s.sh"
    "system.10s.sh"
    "tailscale.1m.sh"
  ];
in
lib.mkIf pkgs.stdenv.isDarwin {
  # macmon reads Apple Silicon's counters through IOReport, so the system plugin
  # gets CPU/GPU temperature and power without sudo — powermetrics would have
  # needed root, which a menu bar plugin must never have.
  home.packages = [ pkgs.macmon ];

  # Plugins run detached from a login shell, so each one sets its own PATH.
  # Two traps worth knowing if you write more: this profile's `date` is GNU
  # coreutils and has no BSD `-j`, and `route` lives in /sbin, which is not on
  # a default PATH.
  home.file = lib.listToAttrs (
    map (name: {
      name = ".config/swiftbar/plugins/${name}";
      value = {
        source = ./plugins/${name};
        executable = true;
      };
    }) plugins
  );

  # Point SwiftBar at the managed directory so the plugins are whatever this
  # module says they are, not whatever got dragged in.
  targets.darwin.defaults."com.ameba.SwiftBar" = {
    PluginDirectory = pluginDir;
    SwiftBarLaunchAtLogin = true;
    MakePluginExecutable = true;
  };
}
