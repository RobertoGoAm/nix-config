#!/usr/bin/env bash
# One-shot bootstrap for this nix-config. Idempotent — safe to re-run.
#
# Fresh machine, one line (it clones itself):
#   curl -fsSL https://raw.githubusercontent.com/RobertoGoAm/nix-config/master/bootstrap.sh | bash -s -- <host>
# From an existing checkout:
#   ./bootstrap.sh <host>                 # host = prometheus | vulcan | perseus
#
# SECRETS — two ways to provide them:
#   a) Place them yourself beforehand:
#        ~/.config/sops/age/system_keys.txt   your age key
#        ~/.config/nix-secrets/secrets.yaml   your encrypted secrets
#   b) Pull them from Bitwarden — add `--bw`:
#        curl -fsSL .../bootstrap.sh | bash -s -- <host> --bw
#      On one item named "nix-config" (override via BW_ITEM) provide:
#        - age key : attachment "system_keys.txt", or a custom field of that name
#        - secrets : attachment "secrets.yaml",    or the item's Note
#        - optional: attachments "sops-secrets.nix" / "work-extras.nix"
#      (Attachments need Bitwarden Premium; the field+note path works on free.)
#      Self-hosted vault? export BW_SERVER=https://your.vault.
set -euo pipefail

REPO_URL="https://github.com/RobertoGoAm/nix-config.git"
AGE_KEY="$HOME/.config/sops/age/system_keys.txt"
SECRETS="$HOME/.config/nix-secrets/secrets.yaml"
BW_ITEM="${BW_ITEM:-nix-config}"
AGE_KEY_ATTACHMENT="${AGE_KEY_ATTACHMENT:-system_keys.txt}"
SECRETS_ATTACHMENT="${SECRETS_ATTACHMENT:-secrets.yaml}"

bold() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

install_nix() {
  command -v nix >/dev/null 2>&1 || \
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
  # shellcheck disable=SC1091
  [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ] && \
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
}

# Pull the age key + secrets.yaml from Bitwarden (attachments on one item).
fetch_from_bitwarden() {
  bold "Restoring secrets from Bitwarden (item: $BW_ITEM)"
  install_nix
  local BW JQ status session item itemid ageatt secatt
  BW="$(nix build --no-link --print-out-paths nixpkgs#bitwarden-cli)/bin/bw"
  JQ="$(nix build --no-link --print-out-paths nixpkgs#jq)/bin/jq"
  [ -n "${BW_SERVER:-}" ] && "$BW" config server "$BW_SERVER" >/dev/null

  status="$("$BW" status 2>/dev/null | "$JQ" -r '.status' 2>/dev/null || echo unauthenticated)"
  if [ "$status" = "unauthenticated" ]; then
    bold "Log in to Bitwarden"
    session="$("$BW" login --raw </dev/tty)"
  else
    bold "Unlock Bitwarden"
    session="$("$BW" unlock --raw </dev/tty)"
  fi
  [ -n "$session" ] || die "Bitwarden login/unlock failed"
  export BW_SESSION="$session"
  "$BW" sync >/dev/null

  item="$("$BW" get item "$BW_ITEM")" || die "Bitwarden item '$BW_ITEM' not found"
  itemid="$(printf '%s' "$item" | "$JQ" -r '.id')"
  mkdir -p "$(dirname "$AGE_KEY")" "$(dirname "$SECRETS")"

  # age key: file attachment if present, else a custom field of the same name.
  ageatt="$(printf '%s' "$item" | "$JQ" -r --arg n "$AGE_KEY_ATTACHMENT" '[.attachments[]? | select(.fileName==$n) | .id][0] // ""')"
  if [ -n "$ageatt" ]; then
    "$BW" get attachment "$ageatt" --itemid "$itemid" --output "$AGE_KEY" >/dev/null
  else
    ageval="$(printf '%s' "$item" | "$JQ" -r --arg n "$AGE_KEY_ATTACHMENT" '[.fields[]? | select(.name==$n) | .value][0] // ""')"
    [ -n "$ageval" ] || die "item '$BW_ITEM' has no attachment or field named '$AGE_KEY_ATTACHMENT'"
    printf '%s\n' "$ageval" > "$AGE_KEY"
  fi

  # secrets.yaml: file attachment if present, else the item's Note.
  secatt="$(printf '%s' "$item" | "$JQ" -r --arg n "$SECRETS_ATTACHMENT" '[.attachments[]? | select(.fileName==$n) | .id][0] // ""')"
  if [ -n "$secatt" ]; then
    "$BW" get attachment "$secatt" --itemid "$itemid" --output "$SECRETS" >/dev/null
  else
    "$BW" get notes "$BW_ITEM" > "$SECRETS" 2>/dev/null || true
    [ -s "$SECRETS" ] || die "item '$BW_ITEM' has no attachment '$SECRETS_ATTACHMENT' and no note to use"
  fi

  # Optional machine-local nix files (read at eval via --impure). Fetched only if
  # attached to the item; harmless to omit on a public-only setup.
  for f in sops-secrets.nix work-extras.nix; do
    att="$(printf '%s' "$item" | "$JQ" -r --arg n "$f" '[.attachments[]? | select(.fileName==$n) | .id][0] // ""')"
    if [ -n "$att" ]; then
      "$BW" get attachment "$att" --itemid "$itemid" --output "$HOME/.config/nix-secrets/$f" >/dev/null
      bold "  fetched $f"
    fi
  done
  chmod 600 "$AGE_KEY" "$SECRETS" 2>/dev/null || true

  "$BW" lock >/dev/null 2>&1 || true
  unset BW_SESSION
  bold "Secrets restored from Bitwarden"
}

# --- arguments ---
HOST=""
USE_BW=0
for a in "$@"; do
  case "$a" in
    --bw|--bitwarden) USE_BW=1 ;;
    -*) die "unknown flag: $a" ;;
    *) if [ -z "$HOST" ]; then HOST="$a"; else die "unexpected argument: $a"; fi ;;
  esac
done
[ -n "$HOST" ] || die "usage: bootstrap.sh <host> [--bw]   (host: prometheus | vulcan | perseus)"

# 1. Secrets: already present, or pull from Bitwarden, or fail fast.
if [ -f "$AGE_KEY" ] && [ -f "$SECRETS" ]; then
  :
elif [ "$USE_BW" = 1 ]; then
  fetch_from_bitwarden
else
  die "missing $AGE_KEY and/or $SECRETS — place them first, or re-run with --bw to pull them from Bitwarden"
fi

# 2. Locate (or fetch) the repo. Piped via curl with no checkout? Clone it —
#    pulling git from Nix when the system has none, so no Command Line Tools are
#    needed just to clone — then re-exec from the clone.
SCRIPT_DIR=""
case "${BASH_SOURCE[0]:-}" in
  */*) SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)" ;;
esac
if [ -f "$PWD/flake.nix" ]; then
  REPO="$PWD"
elif [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/flake.nix" ]; then
  REPO="$SCRIPT_DIR"
else
  bold "Fetching the repo"
  CLONE_DIR="${BOOTSTRAP_DIR:-$HOME/nix-config}"
  if [ ! -f "$CLONE_DIR/flake.nix" ]; then
    if command -v git >/dev/null 2>&1; then
      git clone "$REPO_URL" "$CLONE_DIR"
    else
      install_nix
      nix run nixpkgs#git -- clone "$REPO_URL" "$CLONE_DIR"
    fi
  fi
  exec bash "$CLONE_DIR/bootstrap.sh" "$HOST"
fi
cd "$REPO"
OS="$(uname)"

mkdir -p "$HOME/.config/nix-secrets"
ln -sf "$REPO/.sops.yaml" "$HOME/.config/nix-secrets/.sops.yaml"

# 3. Cache sudo for the whole run.
bold "Caching sudo (enter your password once)"
sudo -v
( while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done ) 2>/dev/null &

# 4. Platform dependencies.
if [ "$OS" = "Darwin" ]; then
  bold "Rosetta + Command Line Tools"
  /usr/sbin/softwareupdate --install-rosetta --agree-to-license 2>/dev/null || true
  if ! xcode-select -p >/dev/null 2>&1; then
    # Best-effort headless CLT install (no GUI, no re-run); falls back to the
    # interactive dialog if Apple's label can't be parsed on this macOS version.
    touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    clt="$(softwareupdate -l 2>/dev/null | grep -E 'Command Line Tools' | tail -1 \
            | sed -E 's/^[[:space:]]*\*?[[:space:]]*(Label:[[:space:]]*)?//; s/[[:space:]]*$//')"
    if [ -n "$clt" ]; then sudo softwareupdate -i "$clt" 2>/dev/null || true; fi
    rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    if ! xcode-select -p >/dev/null 2>&1; then
      xcode-select --install 2>/dev/null || true
      die "couldn't install Command Line Tools headlessly — finish the dialog that opened, then re-run the same command"
    fi
  fi
  bold "Homebrew + bootstrap tools"
  command -v brew >/dev/null 2>&1 || \
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
  brew install git sops age age-plugin-yubikey 2>/dev/null || true
elif [ "$OS" = "Linux" ]; then
  bold "APT bootstrap tools"
  sudo apt-get update -y && sudo apt-get install -y git curl sops age || true
fi

# 5. Nix.
bold "Nix (Determinate installer)"
install_nix
command -v nix >/dev/null 2>&1 || die "nix not on PATH yet — open a new shell and re-run"

# 6. Build + activate. Build as your user with --impure (so the machine-local
#    files under ~/.config/nix-secrets are read); escalate only to activate.
if [ "$OS" = "Darwin" ]; then
  bold "Building darwin system for '$HOST' (the long part)"
  sys="$(nix build --impure --no-link --print-out-paths ".#darwinConfigurations.$HOST.system")"
  bold "Activating"
  sudo nix-env -p /nix/var/nix/profiles/system --set "$sys"
  sudo "$sys/sw/bin/darwin-rebuild" activate
else
  bold "Building home-manager for '$USER@$HOST' (the long part)"
  if command -v home-manager >/dev/null 2>&1; then
    home-manager switch --flake ".#$USER@$HOST" --impure
  else
    nix run home-manager/master -- switch --flake ".#$USER@$HOST" --impure
  fi
fi

# 7. Wi-Fi.
export PATH="/etc/profiles/per-user/$USER/bin:$HOME/.nix-profile/bin:$PATH"
hash -r 2>/dev/null || true
if command -v wifi-setup >/dev/null 2>&1; then
  bold "Seeding Wi-Fi from secrets"
  wifi-setup || true
fi

bold "Done."
cat <<EOF

Almost there — the bits macOS won't let a script do:
  • Grant any permission prompts, then re-run the same command if it stopped:
      App Management → your terminal   (activation)
      Accessibility  → paneru          (window manager)
      Automation     → "System Events" (wallpaper)
  • Re-pair Bluetooth devices by hand.
  • If 'wifi-setup' didn't run above, open a new shell and run it.
EOF
