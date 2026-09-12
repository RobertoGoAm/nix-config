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

  # Copied, not linked

  # =programs.omniwm.settings= would take this path and symlink it in, which is
  # what it did until now -- and OmniWM could then never save anything of its own.
  # Renaming a workspace in its GUI appeared to work and was gone on the next
  # look: the store file is read-only, so the write failed, and nothing said so.
  # Adding a rule with =omniwmctl= behaves the same way; the rule takes effect in
  # memory and the file is untouched.

  # A copy makes the GUI work again and leaves this file the source of truth on
  # the same terms as every other app's preferences here: change it in the app, and
  # the next activation puts this back. Anything worth keeping gets folded in here
  # first.

  home.activation.omniwmSettings = lib.mkIf (config.programs.omniwm.enable) (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p "${config.xdg.configHome}/omniwm"
      run cp -f ${./omniwm-settings.toml} "${config.xdg.configHome}/omniwm/settings.toml"
      run chmod u+w "${config.xdg.configHome}/omniwm/settings.toml"
    ''
  );
}
