{ lib, pkgs, ... }:

# Linux keyboard remapping (Colemak + nav/sym layers) — the counterpart to the
# macOS Karabiner config. keyd is a root daemon that owns /etc/keyd and a systemd
# unit, which a standalone home-manager setup can't manage. So this ships a
# `keyd-setup` helper that (re-execs with sudo to) install keyd, drop the config
# into /etc/keyd/default.conf, and enable + reload the service. Run `keyd-setup`
# once after a rebuild, and again whenever you edit keyd-default.conf.
lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
  home.packages = [
    (pkgs.writeShellScriptBin "keyd-setup" ''
      set -euo pipefail
      if [ "$(id -u)" -ne 0 ]; then exec sudo "$0" "$@"; fi
      conf="${./keyd-default.conf}"
      if ! command -v keyd >/dev/null 2>&1; then
        echo "Installing keyd..."
        if   command -v apt-get >/dev/null 2>&1; then apt-get update -y && apt-get install -y keyd
        elif command -v dnf     >/dev/null 2>&1; then dnf install -y keyd
        elif command -v pacman  >/dev/null 2>&1; then pacman -S --noconfirm keyd
        elif command -v zypper  >/dev/null 2>&1; then zypper --non-interactive install keyd
        else echo "No known package manager — install keyd manually, then re-run." >&2; exit 1; fi
      fi
      install -Dm644 "$conf" /etc/keyd/default.conf
      systemctl enable --now keyd 2>/dev/null || true
      keyd reload 2>/dev/null || systemctl restart keyd 2>/dev/null || true
      echo "keyd configured: $conf -> /etc/keyd/default.conf (reloaded)."
      echo "Tip: 'sudo keyd monitor' shows device ids if the Bridge75 needs excluding over BT."
    '')
  ];
}
