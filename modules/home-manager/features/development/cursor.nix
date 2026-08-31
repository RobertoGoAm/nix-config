# development cursor

{ config, pkgs, ... }:
{
  home.packages = [
    pkgs.code-cursor
    pkgs.cursor-cli
  ];

  # Cursor is a VS Code fork, and programs.cursor is the VS Code module

  # instantiated against ~/.cursor, so it takes the same settings verbatim.
  # Reading them off programs.vscode keeps one source of truth instead of a
  # second copy that drifts.

  # extensions is deliberately not shared: the module would then own
  # ~/.cursor/extensions as a read-only store path, and the symlink below
  # already points it at the VS Code extension directory while keeping it
  # writable so Cursor can install its own.
  # package = null keeps the module to settings only. Left at its default it
  # also drops a .extensions-immutable.json marker inside ~/.cursor/extensions,
  # which is the symlink below — so home-manager would write that file straight
  # into the real VS Code extension directory. Cursor itself is installed above.

  programs.cursor = {
    enable = true;
    package = null;
    profiles.default = {
      inherit (config.programs.vscode.profiles.default) userSettings keybindings;
    };
  };

  home.file.".cursor/extensions" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.vscode/extensions";
    force = true;
  };
}
