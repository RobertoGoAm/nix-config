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
    # On when the age key exists, so a no-secrets adopter still builds. --impure.
    default = builtins.pathExists "${config.home.homeDirectory}/.config/sops/age/system_keys.txt";
    description = "Enable SOPS secret management (auto-detected from the age key).";
  };

  config = lib.mkIf config.features.security.sops.enable {
    # Export secrets in zsh from the system-managed paths
    # On nix-darwin, sops-nix places secrets in /var/run/secrets/
    programs.zsh.initContent = lib.mkAfter ''
      [ -f "/var/run/secrets/npm_token" ] && export NPM_TOKEN="$(cat /var/run/secrets/npm_token)"
      [ -f "/var/run/secrets/gitlab_access_token" ] && export GITLAB_ACCESS_TOKEN="$(cat /var/run/secrets/gitlab_access_token)"
      [ -f "/var/run/secrets/ntfy_topic_id" ] && export NTFY_TOPIC_ID="$(cat /var/run/secrets/ntfy_topic_id)"
    '';
  };
}
