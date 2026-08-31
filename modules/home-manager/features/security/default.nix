# security

{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ./pubkey-setup.nix ];

  options.features.security.sops.enable = lib.mkOption {
    type = lib.types.bool;

    # On when the age key exists, so a no-secrets adopter still builds....

    # On when the age key exists, so a no-secrets adopter still builds. --impure.

    default = builtins.pathExists "${config.home.homeDirectory}/.config/sops/age/system_keys.txt";
    description = "Enable SOPS secret management (auto-detected from the age key).";
  };

  config = lib.mkIf config.features.security.sops.enable {

    # The age keys decrypt everything in secrets.yaml, and two of the...

    # The age keys decrypt everything in secrets.yaml, and two of the three
    # were mode 644 -- world-readable private keys. Anything that could read
    # this home directory could decrypt the npm and GitLab tokens, the user
    # password, and the mail passwords.

    # The filenames say YubiKey and age-plugin-yubikey is installed, but all
    # three hold software AGE-SECRET-KEY material: decryption needs no touch,
    # so the file mode is the only thing standing in front of them. Worth
    # knowing, because the naming suggests a protection that is not in force.

    # Enforced on every activation rather than fixed once, since a key
    # regenerated or restored from a backup comes back at the umask default.
    # nix-darwin's own sops activation reads system_keys.txt as root, which
    # 600 does not obstruct.

    home.activation.tightenAgeKeys = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      for k in keys.txt machine_key.txt system_keys.txt; do
        f="$HOME/.config/sops/age/$k"
        if [ -f "$f" ]; then
          run chmod 600 "$f"
        fi
      done
    '';

    # Export secrets in zsh from the system-managed paths

    # On nix-darwin, sops-nix places secrets in /var/run/secrets/

    programs.zsh.initContent = lib.mkAfter ''
      [ -f "/var/run/secrets/npm_token" ] && export NPM_TOKEN="$(cat /var/run/secrets/npm_token)"
      [ -f "/var/run/secrets/gitlab_access_token" ] && export GITLAB_ACCESS_TOKEN="$(cat /var/run/secrets/gitlab_access_token)"
      [ -f "/var/run/secrets/ntfy_topic_id" ] && export NTFY_TOPIC_ID="$(cat /var/run/secrets/ntfy_topic_id)"
    '';
  };
}
