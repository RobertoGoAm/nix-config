{ config, pkgs, ... }:
{
  home.packages = [
    pkgs.code-cursor
    pkgs.cursor-cli
  ];

  # Cursor is a VS Code fork; share the HM-managed VS Code extensions with it
  # instead of maintaining a separate extension set. mkOutOfStoreSymlink keeps
  # the target writable so Cursor can still install/update extensions itself.
  home.file.".cursor/extensions" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.vscode/extensions";
    force = true;
  };
}
