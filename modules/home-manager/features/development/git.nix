{
  pkgs,
  ...
}:
{
  programs.git = {
    enable = true;
    package = pkgs.gitFull;

    settings = {
      # Fallback identity only. The real default (personal) identity and the
      # per-client identities live encrypted in secrets.yaml, rendered to
      # ~/.config/git/config_clients at activation and Include'd below. If that
      # file is ever absent (decryption unavailable), git falls back to this so
      # it never errors — it just commits as "Anonymous" until secrets resolve.
      user = {
        name = "Anonymous";
        email = "anonymous@example.com";
      };

      alias = {
        co = "checkout";
        st = "status";
        br = "branch";
        last = "log -1 HEAD";
        unstage = "reset HEAD --";
        dc = "diff --cached";

        # `git nb <type> <ticket> <description...>` creates a branch like
        # feature/PROJ-1234_new_feature_description. The type and ticket are used
        # verbatim (so no project keys are baked in here); the description is
        # lowercased and snake-cased — runs of non-alphanumerics collapse to a
        # single "_", with leading/trailing separators trimmed.
        nb = ''!f() { t="$1"; k="$2"; shift 2; d=$(printf %s "$*" | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9' _ | sed 's/^_//;s/_$//'); git switch -c "$t/$k""_""$d"; }; f'';
      };

      pull.rebase = true;
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      fetch.prune = true;

      # SSH commit signing — generic plumbing only. The per-identity signingkey
      # and commit.gpgsign / tag.gpgsign live in the sops-rendered config_clients,
      # so client keys/emails stay out of this public repo and signing is coupled
      # with a key (commits never fail for lack of one).
      gpg.format = "ssh";
      gpg.ssh.allowedSignersFile = "~/.config/git/allowed_signers";
    }
    // (
      if pkgs.stdenv.hostPlatform.isLinux then
        {
          credential = {
            credentialStore = "secretservice";
            helper = [
              "manager"
              "cache --timeout 21600"
            ];
          };
        }
      else
        {
          credential.helper = "osxkeychain";
        }
    );

    # Real identities (the personal default + per-client gitdir includes, whose
    # directory names and emails are work-sensitive) are rendered
    # into ~/.config/git/config_clients by sops at activation. This unconditional
    # include sits after the fallback above, so its values win; git silently
    # ignores it if the file isn't present.
    includes = [ { path = "~/.config/git/config_clients"; } ];
  };
}
