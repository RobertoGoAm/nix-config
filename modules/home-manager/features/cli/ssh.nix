{
  ...
}:
{
  programs.ssh = {
    enable = true;

    # Disable the deprecated default config to suppress warning
    # and manually define what we need in settings.
    enableDefaultConfig = false;

    # Client/work hosts are rendered to ~/.ssh/config_clients by sops at
    # activation (kept out of plaintext Nix); definitions live in secrets.yaml.
    includes = [ "config_clients" ];

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
    };

    extraConfig = ''
      # Use macOS keychain for SSH key passphrases
      UseKeychain yes
    '';
  };
}
