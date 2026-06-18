#!/usr/bin/env bash
# One-shot bootstrap for this nix-config. Idempotent — safe to re-run.
#
# Fresh machine, one line (it clones itself) — curl, or wget if that's what you have:
#   curl -fsSL https://raw.githubusercontent.com/RobertoGoAm/nix-config/master/bootstrap.sh | bash
#   wget -qO-  https://raw.githubusercontent.com/RobertoGoAm/nix-config/master/bootstrap.sh | bash
# With no host argument you get an interactive menu: pick an existing host, or
# "Create a new host" (choose a base to duplicate + a name). Pass a host to skip it:
#   ./bootstrap.sh <host>                 # e.g. prometheus | vulcan | perseus
#
# SECRETS — Bitwarden is the DEFAULT source. Two ways:
#   a) DEFAULT — pull from Bitwarden (no flag needed):
#        curl -fsSL .../bootstrap.sh | bash -s -- <host>
#      On one item named "nix-config" (override via BW_ITEM) provide:
#        - age key : attachment "system_keys.txt", or a custom field of that name
#        - secrets : attachment "secrets.yaml",    or the item's Note
#        - optional: attachments "sops-secrets.nix" / "work-extras.nix"
#      (Attachments need Bitwarden Premium; the field+note path works on free.)
#      Vaultwarden / self-hosted? add `--bw-server https://your.vault` (or export BW_SERVER).
#   b) No password manager — place them yourself + add `--no-bw`:
#        ~/.config/sops/age/system_keys.txt   your age key
#        ~/.config/nix-secrets/secrets.yaml   your encrypted secrets (sops-encrypted,
#                                             so safe in a private repo / cloud)
#      (If both files already exist they're used even without --no-bw.)
set -euo pipefail

REPO_URL="https://github.com/RobertoGoAm/nix-config.git"
AGE_KEY="$HOME/.config/sops/age/system_keys.txt"
SECRETS="$HOME/.config/nix-secrets/secrets.yaml"
BW_ITEM="${BW_ITEM:-nix-config}"
AGE_KEY_ATTACHMENT="${AGE_KEY_ATTACHMENT:-system_keys.txt}"
SECRETS_ATTACHMENT="${SECRETS_ATTACHMENT:-secrets.yaml}"

bold() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

# Fetch a URL to stdout with whatever downloader is present (curl or wget), so a
# minimal Linux box that ships only one of them still works end to end.
fetch() {
  if command -v curl >/dev/null 2>&1; then
    curl --proto '=https' --tlsv1.2 -sSf -L "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$1"
  else
    die "need 'curl' or 'wget' to download $1 — install one (e.g. sudo apt install -y curl) and re-run"
  fi
}

install_nix() {
  command -v nix >/dev/null 2>&1 || \
    fetch https://install.determinate.systems/nix | sh -s -- install --no-confirm
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

CREATED_HOST=0

# --- interactive host selection / duplication ---
list_hosts() { ls -1 "$REPO/modules/home-manager/hosts" 2>/dev/null | sort; }
is_darwin_host() { [ -d "$REPO/modules/macos/$1" ]; }

# Platform string for a host, read from the flake `hosts` map (fallback by OS dir).
host_system() {
  local h="$1" s=""
  s="$(sed -n "s/.*${h} = \"\([a-z0-9_-]*\)\".*/\1/p" "$REPO/flake.nix" 2>/dev/null | head -1 || true)"
  if [ -z "$s" ]; then
    if is_darwin_host "$h"; then s="aarch64-darwin"; else s="x86_64-linux"; fi
  fi
  printf '%s' "$s"
}

# Copy an existing host's modules under a new name + register it in the flake.
# Idempotent: an already-existing host is reused untouched.
duplicate_host() {
  local base="$1" new="$2" system f
  if [ -d "$REPO/modules/home-manager/hosts/$new" ]; then
    bold "Host '$new' already exists — reusing it"
    return 0
  fi
  system="$(host_system "$base")"
  bold "Duplicating '$base' -> '$new' ($system)"
  cp -R "$REPO/modules/home-manager/hosts/$base" "$REPO/modules/home-manager/hosts/$new"
  if [ -f "$REPO/modules/home-manager/hosts/$new/$base.nix" ]; then
    mv "$REPO/modules/home-manager/hosts/$new/$base.nix" "$REPO/modules/home-manager/hosts/$new/$new.nix"
  fi
  if is_darwin_host "$base"; then
    cp -R "$REPO/modules/macos/$base" "$REPO/modules/macos/$new"
    if [ -f "$REPO/modules/macos/$new/$base.nix" ]; then
      mv "$REPO/modules/macos/$new/$base.nix" "$REPO/modules/macos/$new/$new.nix"
    fi
    f="$REPO/modules/macos/$new/$new.nix"
    if sed --version >/dev/null 2>&1; then
      sed -i -e "s|networking.hostName = \"$base\"|networking.hostName = \"$new\"|" \
             -e "s|home-manager/hosts/$base/$base.nix|home-manager/hosts/$new/$new.nix|" "$f"
    else
      sed -i '' -e "s|networking.hostName = \"$base\"|networking.hostName = \"$new\"|" \
                -e "s|home-manager/hosts/$base/$base.nix|home-manager/hosts/$new/$new.nix|" "$f"
    fi
  fi
  if ! grep -qE "^[[:space:]]*${new} = \"" "$REPO/flake.nix"; then
    awk -v line="        ${new} = \"${system}\";" \
      '/# bootstrap-hosts-marker/ && !d { print line; d=1 } { print }' \
      "$REPO/flake.nix" > "$REPO/flake.nix.tmp" && mv "$REPO/flake.nix.tmp" "$REPO/flake.nix"
  fi
  CREATED_HOST=1
  bold "Scaffolded host '$new' — review + commit it after the run"
}

new_host_flow() {
  local bases=() h base new
  while IFS= read -r h; do
    [ -n "$h" ] || continue
    if [ "$OS" = "Darwin" ]; then
      if is_darwin_host "$h"; then bases+=("$h"); fi
    else
      if ! is_darwin_host "$h"; then bases+=("$h"); fi
    fi
  done < <(list_hosts)
  [ "${#bases[@]}" -gt 0 ] || die "no $OS host available to duplicate"
  bold "Pick a host to duplicate as the base:"
  PS3="> "
  select base in "${bases[@]}"; do
    if [ -n "${base:-}" ]; then break; else echo "Pick a number." >/dev/tty; fi
  done < /dev/tty
  while :; do
    printf 'New host name (lowercase, e.g. atlas): ' >/dev/tty
    IFS= read -r new < /dev/tty || die "no input on /dev/tty"
    new="$(printf '%s' "$new" | tr -d '[:space:]')"
    if [ -z "$new" ]; then echo "Empty name." >/dev/tty; continue; fi
    if ! printf '%s' "$new" | grep -qE '^[a-z][a-z0-9-]*$'; then
      echo "Lowercase letters, digits, dashes only." >/dev/tty; continue
    fi
    if list_hosts | grep -qx "$new"; then
      echo "'$new' already exists — pick it from the menu instead." >/dev/tty; continue
    fi
    break
  done
  duplicate_host "$base" "$new"
  HOST="$new"
}

# Resolve HOST: keep a given arg, else show the menu (needs a terminal).
choose_host() {
  if [ -n "$HOST" ]; then return 0; fi
  [ -e /dev/tty ] || die "no host given and no terminal for the menu — pass one, e.g. ./bootstrap.sh prometheus"
  local existing=() h choice
  while IFS= read -r h; do
    if [ -n "$h" ]; then existing+=("$h"); fi
  done < <(list_hosts)
  bold "Which host is this machine?"
  PS3="> "
  select choice in "${existing[@]}" "Create a new host"; do
    if [ "${choice:-}" = "Create a new host" ]; then
      new_host_flow; break
    elif [ -n "${choice:-}" ]; then
      HOST="$choice"; break
    else
      echo "Pick a number." >/dev/tty
    fi
  done < /dev/tty
}

# --- arguments ---
HOST=""
USE_BW=1   # Bitwarden is the default secret source; --no-bw opts out (place files yourself)
while [ $# -gt 0 ]; do
  case "$1" in
    --bw|--bitwarden) USE_BW=1; shift ;;
    --no-bw|--local)  USE_BW=0; shift ;;
    # Vaultwarden / any self-hosted Bitwarden server (implies --bw). Both forms work.
    --bw-server) USE_BW=1; BW_SERVER="${2:-}"; [ -n "$BW_SERVER" ] || die "--bw-server needs a URL"; shift 2 ;;
    --bw-server=*) USE_BW=1; BW_SERVER="${1#*=}"; shift ;;
    -*) die "unknown flag: $1" ;;
    *) if [ -z "$HOST" ]; then HOST="$1"; else die "unexpected argument: $1"; fi; shift ;;
  esac
done
# HOST may be empty here — resolved interactively after the repo is available.

# 1. Secrets: already present, or pull from Bitwarden, or fail fast.
if [ -f "$AGE_KEY" ] && [ -f "$SECRETS" ]; then
  :
elif [ "$USE_BW" = 1 ]; then
  fetch_from_bitwarden
else
  die "missing $AGE_KEY and/or $SECRETS — place them first (README 'Secrets Setup'), or drop --no-bw to pull from Bitwarden"
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
  # Re-run from the clone, preserving the original choices (empty host -> menu).
  reexec=()
  if [ -n "$HOST" ]; then reexec+=("$HOST"); fi
  if [ "$USE_BW" = 0 ]; then reexec+=("--no-bw"); fi
  if [ -n "${BW_SERVER:-}" ]; then reexec+=("--bw-server=$BW_SERVER"); fi
  if [ "${#reexec[@]}" -gt 0 ]; then
    exec bash "$CLONE_DIR/bootstrap.sh" "${reexec[@]}"
  else
    exec bash "$CLONE_DIR/bootstrap.sh"
  fi
fi
cd "$REPO"
OS="$(uname)"

# Pick the host: a given arg, an existing host from the menu, or a new host
# duplicated from one you choose. Sets HOST (and may scaffold new module files).
choose_host

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
if [ "$CREATED_HOST" = 1 ]; then
  # Stage the scaffolded host so the (dirty) flake includes it — flakes ignore
  # untracked files. You review + commit it yourself afterwards.
  git -C "$REPO" add -A 2>/dev/null || true
fi
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

# 7. Post-activation user commands: SSH public keys + Wi-Fi.
export PATH="/etc/profiles/per-user/$USER/bin:$HOME/.nix-profile/bin:$PATH"
hash -r 2>/dev/null || true
if command -v pubkey-setup >/dev/null 2>&1; then
  bold "Deriving ~/.ssh/*.pub from your private keys"
  pubkey-setup || true
fi
if command -v wifi-setup >/dev/null 2>&1; then
  bold "Seeding Wi-Fi from secrets"
  wifi-setup || true
fi

bold "Done."
if [ "$CREATED_HOST" = 1 ]; then
  printf '\nNew host "%s" was scaffolded from your chosen base and built.\nReview and commit it:\n  git -C "%s" add -A && git -C "%s" commit -m "feat(hosts): add %s"\n' \
    "$HOST" "$REPO" "$REPO" "$HOST"
fi
cat <<EOF

Almost there — the bits macOS won't let a script do:
  • Grant any permission prompts, then re-run the same command if it stopped:
      App Management → your terminal   (activation)
      Accessibility  → warpd + your WM (pointer control, window manager)
      Automation     → "System Events" (wallpaper)
  • Re-pair Bluetooth devices by hand.
  • If 'wifi-setup' or 'pubkey-setup' didn't run above, open a new shell and run them
    ('pubkey-setup' prompts for any passphrase-protected key — that's expected).
EOF
