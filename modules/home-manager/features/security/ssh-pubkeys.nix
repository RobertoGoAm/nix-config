{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Regenerate ~/.ssh/*.pub from the private keys at activation — the
  # non-Darwin counterpart to the macOS derive in modules/macos/default.nix.
  #
  # Public keys aren't secrets, so they're derived (and therefore always valid)
  # rather than stored. macOS does this in system.activationScripts.postActivation,
  # which runs late and as root, *after* the system-level sops module has installed
  # the private keys. Standalone home-manager (e.g. Linux) has no system activation,
  # so home-manager's own activation is the correct hook here.
  #
  # Gated to non-Darwin so macOS keeps using its proven postActivation path and the
  # derive doesn't run twice there. Iterates every private-key file (no hardcoded
  # names); non-key files fail `ssh-keygen -y` and are skipped.
  home.activation.deriveSshPubkeys = lib.mkIf (!pkgs.stdenv.hostPlatform.isDarwin) (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      sshdir="${config.home.homeDirectory}/.ssh"
      if [ -d "$sshdir" ]; then
        for k in "$sshdir"/*; do
          case "$k" in
            *.pub | */config | */config_clients | */known_hosts* | */authorized_keys | */agent) continue ;;
          esac
          [ -e "$k" ] || continue
          if ${pkgs.openssh}/bin/ssh-keygen -y -f "$k" > "$k.pub.tmp" 2>/dev/null; then
            run mv -f "$k.pub.tmp" "$k.pub"
            run chmod 644 "$k.pub"
          else
            rm -f "$k.pub.tmp"
          fi
        done
      fi
    ''
  );
}
