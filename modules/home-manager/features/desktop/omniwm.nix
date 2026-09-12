# OmniWM, the other tiling window manager

# Upstream home-manager carries =programs.omniwm=, so this module is mostly the
# wiring: it installs the package, runs the app under a launchd agent, and is
# gated on the same option that turns aerospace off.

# Three requirements are not this file's to satisfy, and none of them fails
# loudly. OmniWM needs Apple Silicon and macOS 26 or later, which this host has;
# it needs Accessibility and Input Monitoring, which are granted by hand on
# first launch; and it needs =Displays have separate Spaces= left on in Mission
# Control settings. Without the permissions the agent starts and the window
# manager simply does not manage anything.

{
  config,
  lib,
  ...
}:
{
  imports = [ ./window-manager.nix ];

  programs.omniwm = {
    enable = config.features.desktop.windowManager == "omniwm";

    # KeepAlive, as the upstream module defaults it: a window manager that has
    # quit is a desktop with no window manager, which is worth a restart.
    launchd.enable = true;
  };

  # The CLI needs the socket

  # =ipcEnabled= ships =false=, and with it off =omniwmctl ping= answers "No such
  # file or directory" -- the IPC and CLI surface the README documents is simply
  # absent. Nothing here depends on it yet; it is on because a window manager that
  # can be driven from a script is the reason for choosing one with a CLI.

  programs.omniwm.settings = ./omniwm-settings.toml;
}
