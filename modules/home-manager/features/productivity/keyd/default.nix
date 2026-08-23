{ config, lib, pkgs, ... }:

# Linux keyboard remapping (Colemak + nav/sym layers) — the counterpart to the
# macOS Karabiner config. keyd is a root daemon that owns /etc/keyd and a systemd
# unit, which a standalone home-manager setup can't manage. So this ships a
# `keyd-setup` helper that (re-execs with sudo to) install keyd, drop the config
# into /etc/keyd/default.conf, and enable + reload the service. Run `keyd-setup`
# once after a rebuild, and again whenever you edit the config fragments.
let
  colemak = config.features.productivity.keyboard.layout == "colemak";

  # Assembled from fragments rather than shipped whole, so the base letter remap
  # can be dropped without touching the layers. The split follows the file's own
  # structure: the Colemak block was already the last thing in [main], and [nav]
  # and [sym] are keyed to physical positions, so they are identical either way.
  #
  #   keyd-main.conf     [ids] + [main]: caps/alt/esc/super/shift behaviour
  #   keyd-colemak.conf  the 17 QWERTY-to-Colemak letter mappings (conditional)
  #   keyd-layers.conf   [nav] + [sym]
  conf = pkgs.concatTextFile {
    name = "keyd-default.conf";
    files = [ ./keyd-main.conf ] ++ lib.optional colemak ./keyd-colemak.conf ++ [ ./keyd-layers.conf ];
  };
in
{
  imports = [ ../keyboard-layout.nix ];

  config = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    home.packages = [
      (pkgs.writeShellScriptBin "keyd-setup" ''
        set -euo pipefail
        if [ "$(id -u)" -ne 0 ]; then exec sudo "$0" "$@"; fi
        conf="${conf}"
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
        echo "keyd configured (${config.features.productivity.keyboard.layout}): $conf -> /etc/keyd/default.conf (reloaded)."
        echo "Tip: 'sudo keyd monitor' shows device ids if the Bridge75 needs excluding over BT."
      '')
    ];
  };
}
