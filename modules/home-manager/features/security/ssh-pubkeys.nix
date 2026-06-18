{ pkgs, ... }:
let
  # Manual command to (re)generate ~/.ssh/*.pub from the private keys. Public
  # keys aren't secrets, so they're derived rather than stored in sops.
  #
  # This is a manual step (a sibling to `wifi-setup`), NOT an activation hook,
  # because `ssh-keygen -y` prompts for the passphrase on encrypted keys and
  # would otherwise block the non-interactive nix-build / home-manager switch.
  # Unencrypted keys (e.g. the sops-rendered ones on the macs) derive silently;
  # passphrase-protected keys prompt only when you run this by hand.
  #
  # Cross-platform: iterates $HOME/.ssh on macOS and Linux alike. Run it once on
  # a fresh machine (bootstrap.sh does this for you) and after adding/rotating a
  # key whose .pub is missing or stale.
  ssh-pubkeys = pkgs.writeShellScriptBin "ssh-pubkeys" ''
    set -uo pipefail
    sshdir="$HOME/.ssh"
    keygen="${pkgs.openssh}/bin/ssh-keygen"
    [ -d "$sshdir" ] || { echo "ssh-pubkeys: $sshdir not found — nothing to do." >&2; exit 0; }

    echo "ssh-pubkeys: regenerating *.pub from private keys in $sshdir"
    for k in "$sshdir"/*; do
      case "$k" in
        *.pub | */config | */config_clients | */known_hosts* | */authorized_keys | */allowed_signers | */agent) continue ;;
      esac
      [ -e "$k" ] || continue
      base="$(basename "$k")"

      # Non-interactive first: unencrypted keys derive silently; encrypted keys
      # fail here (instead of hanging) thanks to the forced no-op askpass + no tty.
      if SSH_ASKPASS_REQUIRE=force SSH_ASKPASS=${pkgs.coreutils}/bin/false \
           "$keygen" -y -f "$k" </dev/null > "$k.pub.tmp" 2>/dev/null; then
        mv -f "$k.pub.tmp" "$k.pub"; chmod 644 "$k.pub"
        echo "  ok    $base.pub"
        continue
      fi
      rm -f "$k.pub.tmp"

      # Encrypted private key → prompt for its passphrase (fine in a manual run).
      if head -n1 "$k" 2>/dev/null | grep -q "PRIVATE KEY"; then
        echo "  $base is passphrase-protected — enter its passphrase (or Ctrl-C to skip):"
        if "$keygen" -y -f "$k" > "$k.pub.tmp" 2>/dev/null; then
          mv -f "$k.pub.tmp" "$k.pub"; chmod 644 "$k.pub"
          echo "  ok    $base.pub"
        else
          rm -f "$k.pub.tmp"
          echo "  skip  $base (no / incorrect passphrase)"
        fi
      fi
    done
    echo "ssh-pubkeys: done"
  '';
in
{
  home.packages = [ ssh-pubkeys ];
}
