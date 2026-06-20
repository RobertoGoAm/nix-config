{ lib, pkgs, ... }:

let
  # ── kanata: built, validated, and DISABLED ──────────────────────────────────
  # A single cross-platform config (kanata-colemak.kbd) that mirrors the macOS
  # Karabiner (../karabiner.nix) and Linux keyd (../keyd/keyd-default.conf) setups,
  # kept in sync here as a ready-to-flip replacement for both. It is OFF because
  # kanata on macOS needs manual, non-nix-automatable setup.
  #
  # To enable:
  #   1. macOS: install the Karabiner-DriverKit-VirtualHIDDevice driver v6.2.0,
  #      grant the kanata binary Input Monitoring + Accessibility, and turn off
  #      Karabiner-Elements' own modifications so it doesn't double-remap. (Re-grant
  #      the permissions after each kanata update — macOS TCC is keyed to the
  #      binary's path, which changes with the Nix store hash.)
  #   2. Put the Bridge75's real device name (from `kanata --list`) into the
  #      *-dev-names-exclude lists in kanata-colemak.kbd.
  #   3. Flip `enable` below to true and rebuild. Then retire Karabiner/keyd.
  #   4. Linux: run `kanata-setup` once (installs the service + loads uinput), and
  #      again after any edit to kanata-colemak.kbd (its store path changes).
  #
  # KEEP ALIGNED: edits to the Colemak map / nav / sym / tap behaviours must also
  # land in ../karabiner.nix and ../keyd/keyd-default.conf (and the Bridge75 keymap
  # where relevant) — all are meant to behave identically.
  enable = false;

  cfg = ./kanata-colemak.kbd;

  # Linux: kanata runs as a root systemd service (needs /dev/input + /dev/uinput).
  # A standalone home-manager setup can't own that unit, so a sudo helper installs
  # it — same approach as keyd-setup.
  unit = pkgs.writeText "kanata.service" ''
    [Unit]
    Description=kanata keyboard remapper
    After=multi-user.target

    [Service]
    ExecStartPre=-${pkgs.kmod}/bin/modprobe uinput
    ExecStart=${pkgs.kanata}/bin/kanata --cfg ${cfg}
    Restart=always

    [Install]
    WantedBy=multi-user.target
  '';
in
lib.mkIf enable (lib.mkMerge [
  {
    home.packages = [ pkgs.kanata ];
    xdg.configFile."kanata/kanata.kbd".source = cfg;
  }

  (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    home.packages = [
      (pkgs.writeShellScriptBin "kanata-setup" ''
        set -euo pipefail
        if [ "$(id -u)" -ne 0 ]; then exec sudo "$0" "$@"; fi
        install -Dm644 "${unit}" /etc/systemd/system/kanata.service
        systemctl daemon-reload
        systemctl enable --now kanata
        systemctl restart kanata 2>/dev/null || true
        echo "kanata configured: ${cfg} -> systemd service (started)."
        echo "Tip: 'kanata --list' shows device names if the Bridge75 needs excluding."
      '')
    ];
  })

  (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    # User launchd agent. Needs the manual driver + permission grants above; the
    # exact invocation may want tuning when this is actually switched on.
    launchd.agents.kanata = {
      enable = true;
      config = {
        ProgramArguments = [ "${pkgs.kanata}/bin/kanata" "--cfg" "${cfg}" ];
        RunAtLoad = true;
        KeepAlive = true;
        StandardErrorPath = "/tmp/kanata.err.log";
        StandardOutPath = "/tmp/kanata.out.log";
      };
    };
  })
])
