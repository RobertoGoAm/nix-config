# Jellyfin, for the courses that live on vulcan

# The reading stack next door already established the shape: a launchd agent on
# vulcan, bound to every interface, reached from the LAN by name and from
# anywhere else over the tailnet. This is the same arrangement for video.

# Video courses are the case that earns a media server rather than a file share.
# They are watched in order over weeks, so the thing that matters is that
# something remembers where you stopped -- which a folder mounted over SMB
# cannot do, and which the web player does on any machine you open it from.

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.features.services.media;
in
{
  options.features.services.media = {
    enable = lib.mkEnableOption "the self-hosted media server (jellyfin)";

    host = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = ''
        Interface to bind. Every one, as with the reading stack: the point is
        reaching it from the other machine and the phone, not from vulcan.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8096;
      description = "Jellyfin's HTTP port, its own default.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Library/Application Support/jellyfin";
      description = ''
        Database, metadata and the transcode cache. Deliberately not under the
        library: the library is 30GB of video that can be downloaded again,
        and this is the small part that cannot.
      '';
    };

    filesPort = lib.mkOption {
      type = lib.types.port;
      default = 8097;
      description = ''
        Port for the plain file listing of the same tree. Next to Jellyfin's
        8096 on purpose: it is the other half of the same service.
      '';
    };

    libraryDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Media";
      description = ''
        Where the video lives. Jellyfin is pointed at this from its own setup
        wizard on first run rather than from here -- libraries are rows in its
        database, not configuration it reads from a file.
      '';
    };
  };

  # The agent

  # ffmpeg is the one thing Jellyfin cannot do without and does not ship: it is
  # what reads the container, and what re-encodes when a client cannot play the
  # file as it stands. =jellyfin-ffmpeg= is the build Jellyfin expects, so it goes
  # on PATH rather than leaving it to find whatever is installed.

  # The web UI is a separate package from the server, and =--webdir= is how the
  # server is told where it went. Without it Jellyfin serves the API and an empty
  # page, which looks like a broken install rather than a missing flag.

  # KeepAlive on unsuccessful exit only, matching calibre-web: a server that
  # crashes should come back, and one told to quit should stay down.

  config = lib.mkIf cfg.enable {
    home.activation.jellyfinDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p ${lib.escapeShellArg cfg.dataDir} ${lib.escapeShellArg cfg.libraryDir}
    '';

    launchd.agents.jellyfin = {
      enable = true;
      config = {
        ProgramArguments = [
          "${lib.getExe pkgs.jellyfin}"
          "--service"
          "--datadir"
          cfg.dataDir
          "--configdir"
          "${cfg.dataDir}/config"
          "--cachedir"
          "${cfg.dataDir}/cache"
          "--webdir"
          "${pkgs.jellyfin-web}/share/jellyfin-web"
        ];
        RunAtLoad = true;
        KeepAlive = {
          SuccessfulExit = false;
        };
        WorkingDirectory = cfg.dataDir;
        EnvironmentVariables = {
          JELLYFIN_PublishedServerUrl = cfg.host;
          PATH = "${pkgs.jellyfin-ffmpeg}/bin:/usr/bin:/bin";
        };
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/jellyfin.out.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/jellyfin.err.log";
      };
    };

    # And the same tree as plain files

    # Jellyfin indexes media and ignores everything else, which for a course is
    # most of it: the exercise repository, the slides, the PDFs, the starter
    # projects. Those need to be reachable too, and the way to reach them from
    # an office is HTTP rather than a mounted share.

    # SMB is the obvious alternative and the wrong one here. It is a chatty
    # protocol -- a directory listing is several round trips -- built for a LAN.
    # The tailnet has a direct path between these two machines today, but a
    # corporate network is where that fails over to a DERP relay, and SMB over a
    # relay is where a mount hangs and the Finder stops answering. HTTP is
    # stateless: nothing to mount, nothing to go stale when the laptop lid
    # closes or the connection moves from wifi to cellular, and a dropped
    # request costs a retry rather than a wedged mount.

    # Read-only, which is the trade being made. Writing to the tree still means
    # ssh or rsync; if dragging files onto vulcan becomes the common case, a
    # share is the honest answer and this is not.

    # The same caveat as the rest of the stack applies: bound to every
    # interface, this is readable by anything on the LAN, and over the tailnet
    # it is Tailscale's ACLs doing the gating.

    launchd.agents.media-files = {
      enable = true;
      config = {
        ProgramArguments = [
          "${lib.getExe pkgs.caddy}"
          "run"
          "--adapter"
          "caddyfile"
          "--config"
          "${pkgs.writeText "media-files.Caddyfile" ''
            {
              admin off
              auto_https off
            }

            :${toString cfg.filesPort} {
              root * ${cfg.libraryDir}
              file_server browse
            }
          ''}"
        ];
        RunAtLoad = true;
        KeepAlive = {
          SuccessfulExit = false;
        };
        WorkingDirectory = cfg.dataDir;
        EnvironmentVariables = {
          # Caddy writes a certificate store and its own state; with no
          # https to manage it is empty, but it still wants somewhere to put
          # it, and that somewhere should not be a surprise.
          XDG_DATA_HOME = "${cfg.dataDir}/caddy";
          XDG_CONFIG_HOME = "${cfg.dataDir}/caddy";
        };
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/media-files.out.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/media-files.err.log";
      };
    };
  };
}
