{ config, lib, pkgs, ... }:
let
  # Dev Forge lives inside a work project whose directory name identifies the
  # client/project, so its location is kept in the gitignored private secrets
  # dir rather than committed here. On machines without that file (or non-work
  # hosts) the df() helper is simply not defined.
  privatePath = "${config.home.homeDirectory}/.config/nix-secrets/devforge.nix";
  devForgeDir = if builtins.pathExists privatePath then (import privatePath).dir else null;
  enabled = devForgeDir != null;
in
{
  # envsubst (Dev Forge prompt templates)
  home.packages = lib.optional enabled pkgs.gettext;

  # Function (not shellAliases): macOS /bin/df shadows a plain alias for many users.
  programs.zsh.initContent = lib.mkIf enabled (lib.mkAfter ''
    df() {
      "${devForgeDir}/bin/devforge" "$@"
    }
  '');
}
