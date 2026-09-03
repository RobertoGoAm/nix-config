# The agent

# KeepAlive rather than RunAtLoad alone: a Connect device that has quietly died
# is worse than one that never started, because the phone still lists it. Note
# that KeepAlive only notices a process that has *exited*: librespot can lose its
# websocket to Spotify and keep running, at which point the device silently
# disappears from the picker while launchd still reports it healthy. The cure is
# to kill it and let launchd restart it.

# Three settings exist to stop playback stuttering.

# ProcessType is Interactive, not Adaptive. launchd throttles CPU and I/O by
# process type, and an Adaptive job can be quietly deprioritised whenever the
# machine is busy -- a rebuild, a compile, an LSP server waking up. For anything
# feeding an audio device on a deadline that is a dropout. Interactive exempts it
# from throttling.

# The audio cache is on, bounded to 2G rather than disabled. Without it every
# second of audio is refetched from the network into a small in-memory buffer, so
# a brief stall in connectivity is audible immediately; with it, replays and
# seeks come off the disk.

# Discovery is off. Zeroconf only matters for signing in from a device on the
# same network; once credentials are cached, the connection that makes this
# device visible is the outbound websocket to Spotify. Leaving it on had libmdns
# emitting a steady stream of "no route to host" packets that made up 84% of the
# log and served no purpose.

{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  home.packages = [ pkgs.librespot ];

  launchd.agents.librespot = {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.librespot}/bin/librespot"
        "--name"
        "Emacs"
        "--cache"
        "${config.home.homeDirectory}/.cache/librespot"
        "--cache-size-limit"
        "2G"
        "--disable-discovery"
        "--bitrate"
        "320"
        "--initial-volume"
        "60"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Interactive";
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/librespot.out.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/librespot.err.log";
    };
  };
  # A watchdog, because KeepAlive cannot see this failure.
  #
  # librespot loses its websocket to Spotify and keeps running. The device
  # disappears from every picker while launchd, which only ever watches the
  # process, reports the job perfectly healthy. The log shows
  #
  #   WARN  librespot_core::dealer] Websocket peer does not respond.
  #   WARN  librespot_connect::spirc] unexpected shutdown
  #
  # and nothing recovers from it. Killing the process does: KeepAlive brings
  # it straight back and it reconnects.
  launchd.agents.librespot-watchdog = {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.writeShellScript "librespot-watchdog" ''
          pid=$(/usr/bin/pgrep -x librespot | head -1)
          # Not running is KeepAlive's problem, not this script's.
          [ -n "$pid" ] || exit 0

          # Let a fresh process announce itself before judging it. BSD ps has
          # no etimes, only the formatted etime -- asking for seconds gets a
          # dump of every valid keyword and a comparison against nonsense, so
          # the elapsed time is parsed from [[DD-]HH:]MM:SS instead.
          up=$(/bin/ps -o etime= -p "$pid" 2>/dev/null | tr -d ' ' | awk -F'[-:]' '{
            n = NF; s = 0
            if (n >= 1) s += $n
            if (n >= 2) s += $(n-1) * 60
            if (n >= 3) s += $(n-2) * 3600
            if (n >= 4) s += $(n-3) * 86400
            print s
          }')
          case "$up" in
            ""|*[!0-9]*) ;;                       # unparseable: do not guess
            *) [ "$up" -lt 120 ] && exit 0 ;;
          esac

          # Only ever act on a positive answer. spotify-ctl exits 0 whether the
          # API failed or genuinely returned nothing, so an empty list proves
          # nothing -- treating it as "device missing" would kill a working
          # daemon on every network blip.
          devices=$(${lib.getExe pkgs.spotify-ctl} devices 2>/dev/null)
          [ -n "$devices" ] || exit 0

          if ! printf '%s\n' "$devices" | cut -f2 | grep -qx 'Emacs'; then
            echo "$(date '+%Y-%m-%dT%H:%M:%S') running but not advertising; restarting"
            /usr/bin/pkill -x librespot || true
          fi
        ''}"
      ];
      RunAtLoad = false;
      StartInterval = 300;
      ProcessType = "Background";
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/librespot-watchdog.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/librespot-watchdog.log";
    };
  };
}
