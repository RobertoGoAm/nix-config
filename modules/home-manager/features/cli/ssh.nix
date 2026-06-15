{
  pkgs,
  config,
  ...
}:
let
  # ─── Client/work-specific SSH hosts (machine-local) ──────────────────────
  # Loaded from ~/.config/nix-secrets/ssh-hosts.nix if present (kept out of
  # the public nix-config repo). When missing, ssh.nix configures only the
  # generic personal hosts below.
  clientHostsPath = "${config.home.homeDirectory}/.config/nix-secrets/ssh-hosts.nix";
  clientHosts = if builtins.pathExists clientHostsPath then import clientHostsPath else { };
in
{
  programs.ssh = {
    enable = true;

    # Disable the deprecated default config to suppress warning
    # and manually define what we need in settings.
    enableDefaultConfig = false;

    settings = {
      "*" = {
        AddKeysToAgent = "yes";

        # ─── Bitwarden SSH agent (opt-in) ──────────────────────────────────
        # Uncomment when Bitwarden's desktop SSH agent is enabled. The agent
        # then holds your Ed25519 keys (biometric-gated) and serves them to
        # every SSH operation, including git commit signing.
        #
        # Exact socket path varies by Bitwarden version; confirm in
        # Settings → SSH agent. The symlink form below is the most common.
        #
        # NOTE: this conflicts with services.gpg-agent.enableSshSupport = true
        # in features/cli/gpg.nix. Pick ONE agent to serve SSH_AUTH_SOCK:
        #   - Bitwarden: set IdentityAgent here, set enableSshSupport = false
        #   - gpg-agent: leave IdentityAgent commented, keep enableSshSupport = true
        #
        # identityAgent = "~/.bitwarden-ssh-agent.sock";
      };

      # ─── Generic public hosts ──────────────────────────────────────────
      "github.com" = {
        IdentityFile = "~/.ssh/id_ed25519";
        IdentitiesOnly = true;
      };

      "gitlab.com" = {
        IdentityFile = "~/.ssh/id_ed25519";
      };

      # ─── Personal infra (Hetzner cluster nodes) ────────────────────────
      "hetzner-host" = {
        HostName = "*.hetzner.com";
        IdentityFile = "~/.ssh/hetzner";
      };
      # Direct connections to the snippets cluster by Tailscale name.
      # IP-based and Tailscale-name-based access both go through this key.
      "snippets-*" = {
        IdentityFile = "~/.ssh/hetzner";
        User = "root";
      };
    }
    // clientHosts;

    extraConfig = ''
      # Use macOS keychain for SSH key passphrases
      UseKeychain yes
    '';
  };
}
