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
}
