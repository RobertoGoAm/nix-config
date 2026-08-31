# The agent

# KeepAlive rather than RunAtLoad alone: a Connect device that has quietly died
# is worse than one that never started, because the phone still lists it.

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
        "--disable-audio-cache"
        "--bitrate"
        "320"
        "--initial-volume"
        "60"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Adaptive";
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/librespot.out.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/librespot.err.log";
    };
  };
}
