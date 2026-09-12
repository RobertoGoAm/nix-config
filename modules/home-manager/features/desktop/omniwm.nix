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

  # The settings file is deliberately not set yet

  # =programs.omniwm.settings= takes either an attrset or a path to a TOML file,
  # and writing one from scratch would be guesswork. OmniWM's README documents the
  # behaviour and the GUI rather than the key names, and says the canonical file is
  # the one OmniWM itself writes to =~/.config/omniwm/settings.toml=, live-reloaded
  # when it changes. The binary carries the section names -- =general=, =gaps=,
  # =layout=, =niri=, =dwindle=, =hotkeys=, =appRules=, =workspaces=,
  # =workspaceBar=, =mouse= -- but not a schema anyone should be inventing keys
  # against: a wrong key does not fail, it is ignored, and the setting silently
  # does not apply.

  # So the order is: run it once, let it write its own file, then track that file
  # here and set =settings = ./omniwm-settings.toml=. Upstream's own documentation
  # recommends the path form for exactly this reason, and the module forces the
  # link on every switch because OmniWM replaces it with a regular file whenever
  # the GUI saves.

  # Until then the app keeps its own settings, which costs nothing except that
  # they are not yet in this repo.

}
