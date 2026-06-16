{ lib, pkgs, ... }:
{
  # envsubst (Dev Forge prompt templates)
  home.packages = [ pkgs.gettext ];

  # The Dev Forge location is a sops secret (its path names a work project),
  # read at runtime. df() no-ops cleanly when the secret isn't present
  # (non-work hosts, or before it materializes). Function (not alias) because
  # macOS /bin/df shadows a plain alias for many users.
  programs.zsh.initContent = lib.mkAfter ''
    df() {
      local _dir
      _dir=$(cat /var/run/secrets/devforge_dir 2>/dev/null) || {
        echo "df: devforge_dir secret not available on this host" >&2
        return 1
      }
      "$_dir/bin/devforge" "$@"
    }
  '';
}
