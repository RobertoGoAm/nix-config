# Automatic restic backup of this machine (prometheus, the work laptop) -> vulcan,
# over Tailscale, every 30 min. Incremental + client-side encrypted; then a
# rewind-friendly prune. vulcan separately copies the repo OFFSITE to Backblaze
# B2 (that half lives in the private vulcan-services layer, since it holds the B2
# credentials).
#
# There are ZERO secrets in this file, so it's safe in the public repo. All
# instance data lives in two runtime files the user drops in (Bitwarden-synced),
# and the agent NO-OPS until they exist — so importing/rebuilding never breaks:
#
#   ~/.config/restic/repository  — e.g. sftp:USER@vulcan.<tailnet>:Backups/restic/prometheus
#   ~/.config/restic/password    — the repo password (chmod 600). LOSE THIS = the
#                                  backups are unrecoverable, so store it in Bitwarden.
#
# First-time setup (once):
#   1. On vulcan: `mkdir -p ~/Backups/restic`
#   2. `ssh USER@vulcan.<tailnet>` once so its host key is trusted (the agent runs
#      non-interactively and can't accept it).
#   3. Create the two files above.
#   4. Seed on the LAN by running the agent's script by hand once (it auto-inits
#      the repo). After that the 30-min agent just does incrementals.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  enable = pkgs.stdenv.hostPlatform.isDarwin;

  # The reproducible bulk — dependencies, build output, bytecode, caches. `.git`
  # is deliberately KEPT (that's your uncommitted work). Mostly base-name patterns
  # so they match at any depth; we verify real coverage with `--dry-run` at seed.
  excludes = pkgs.writeText "restic-excludes.txt" ''
    # dependencies / vendored
    node_modules
    .venv
    venv
    vendor
    Pods
    .terraform
    .direnv
    # build output / bytecode
    target
    __pycache__
    *.pyc
    *.class
    DerivedData
    CoreSimulator
    *.xcarchive
    # tool caches (whole dirs — reproducible)
    .gradle
    .m2
    .cargo
    .rustup
    .npm
    .pnpm-store
    .cache
    Caches
    .pytest_cache
    .mypy_cache
    # macOS / orbstack junk
    .DS_Store
    .Trash
    .orbstack
  '';

  backup = pkgs.writeShellScript "restic-backup" ''
    set -u
    export PATH=${lib.makeBinPath [ pkgs.restic pkgs.openssh ]}:/usr/bin:/bin
    REPO_FILE="$HOME/.config/restic/repository"
    export RESTIC_PASSWORD_FILE="$HOME/.config/restic/password"

    # Not configured yet -> no-op, so importing this feature never breaks a rebuild.
    if [ ! -r "$REPO_FILE" ] || [ ! -r "$RESTIC_PASSWORD_FILE" ]; then
      echo "restic-backup: ~/.config/restic/{repository,password} missing; skipping"
      exit 0
    fi
    export RESTIC_REPOSITORY="$(cat "$REPO_FILE")"

    # The launchd agent has no ssh-agent, so an sftp repo must be reached with an
    # on-disk key (e.g. a sops-decrypted one) — the default identity search in the
    # background otherwise hits the (approval-gated) Bitwarden agent and fails. If
    # ~/.config/restic/ssh_key names a private key, force it for the transport;
    # otherwise fall back to default ssh (non-sftp repos ignore this entirely).
    SFTP_CMD=""
    SSHKEY_FILE="$HOME/.config/restic/ssh_key"
    case "$RESTIC_REPOSITORY" in
      sftp:*)
        if [ -r "$SSHKEY_FILE" ]; then
          KEY="$(cat "$SSHKEY_FILE")"
          TGT="''${RESTIC_REPOSITORY#sftp:}"; TGT="''${TGT%%:*}"   # user@host
          SFTP_CMD="ssh -i $KEY -o IdentitiesOnly=yes -o BatchMode=yes $TGT -s sftp"
        fi ;;
    esac
    # restic wrapper that injects the forced-key sftp.command when one is set.
    rr() { if [ -n "$SFTP_CMD" ]; then restic -o "sftp.command=$SFTP_CMD" "$@"; else restic "$@"; fi; }

    # Only the paths that actually exist (a missing ~/.aws etc. must not be fatal).
    PATHS=""
    for p in Development Documents Desktop Pictures .config .ssh .gnupg .aws .kube; do
      [ -e "$HOME/$p" ] && PATHS="$PATHS $HOME/$p"
    done
    [ -n "$PATHS" ] || { echo "restic-backup: nothing to back up"; exit 0; }

    # First ever run: init the repo (harmless if it already exists). A failure
    # here means the repo is unreachable (vulcan down / off Tailscale) -> skip
    # quietly and try again next interval.
    if ! rr cat config >/dev/null 2>&1; then
      rr init >/dev/null 2>&1 || { echo "restic-backup: repo unreachable; skipping"; exit 0; }
    fi

    # --skip-if-unchanged (restic >=0.17) avoids identical 30-min snapshots; probe
    # for it so an older restic doesn't hard-fail on an unknown flag.
    SKIP=""; restic backup --help 2>&1 | grep -q -- --skip-if-unchanged && SKIP="--skip-if-unchanged"

    # shellcheck disable=SC2086
    rr backup $PATHS $SKIP --exclude-file=${excludes} --tag auto 2>&1 \
      || { echo "restic-backup: backup failed (repo locked/unreachable?)"; exit 0; }

    # Fast: trim the snapshot list to the rewind-friendly policy (no repack here).
    # --tag auto so any manual pre-refactor snapshots you make are left untouched.
    rr forget --tag auto \
      --keep-within 3d --keep-daily 14 --keep-weekly 8 --keep-monthly 12 --keep-yearly 2 \
      2>&1 || true

    # Expensive repack at most ~once/day.
    STAMP="$HOME/.config/restic/.last-prune"
    if [ ! -f "$STAMP" ] || find "$STAMP" -mmin +1200 2>/dev/null | grep -q .; then
      rr prune 2>&1 && : > "$STAMP" || true
    fi
  '';
in
lib.mkIf enable {
  home.packages = [ pkgs.restic ];

  # Every 30 min, at login, background + low-IO so it never gets in your way.
  launchd.agents.restic-backup = {
    enable = true;
    config = {
      ProgramArguments = [ "${backup}" ];
      RunAtLoad = true;
      StartInterval = 1800;
      ProcessType = "Background";
      LowPriorityIO = true;
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/restic-backup.out.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/restic-backup.err.log";
    };
  };
}
