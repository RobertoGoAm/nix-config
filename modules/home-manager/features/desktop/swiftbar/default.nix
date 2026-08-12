{ config, lib, pkgs, ... }:
let
  pluginDir = "${config.home.homeDirectory}/.config/swiftbar/plugins";

  # SwiftBar reads the interval out of the filename (name.INTERVAL.ext), so the
  # schedule lives there rather than in this module.
  # One item, not seven. SwiftBar gives each plugin its own menu bar slot, and
  # five of the old seven read green almost always — width spent to say nothing.
  # The single item rotates vitals, health and the current track through one
  # slot, and the renderer puts the detail in submenus.
  plugins = [
    "status.30s.sh"
    "status-render.py"
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
