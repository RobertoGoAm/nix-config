# services reading

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.features.services.reading;

  # Readeck keeps everything -- SQLite, extracted article bodies,...

  # Readeck keeps everything -- SQLite, extracted article bodies, images -- under
  # one data directory, so the config is small and the whole service is one
  # directory to back up. The secret is generated on first run into the data dir
  # rather than declared here, which is what keeps this file safe for a public
  # repo (see features/backup/restic for the same reasoning).

  readeckConfig = pkgs.writeText "readeck.toml" ''
    [main]
    log_level = "warn"
    data_directory = "${cfg.dataDir}/readeck"

    [server]
    host = "${cfg.host}"
    port = ${toString cfg.readeckPort}
    # Behind tailscale, not the public internet: allowed_hosts stays permissive
    # so reaching it as vulcan.<tailnet> works without listing every name.
    prefix = "/"
  '';
in
{
  options.features.services.reading = {
    enable = lib.mkEnableOption "the self-hosted reading stack (readeck + calibre-web)";

    host = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = ''
        Interface to bind. Defaults to all, which on this machine means the
        tailnet address as well as localhost -- the point is reaching it from
        the phone and the e-reader, not just from vulcan itself.
      '';
    };

    readeckPort = lib.mkOption {
      type = lib.types.port;
      default = 8085;
      description = "Readeck's HTTP port. Not its 8000 default, which collides with too much.";
    };

    calibreWebPort = lib.mkOption {
      type = lib.types.port;
      default = 8083;
      description = "calibre-web's HTTP port (its own default).";
    };

    kosyncPort = lib.mkOption {
      type = lib.types.port;
      default = 8087;
      description = "The KOReader progress-sync server's HTTP port.";
    };

    kosyncAllowRegistration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether POST /users/create is accepted. It has to be on to create the
        first account from a reader, and there is no reason to leave it on
        afterwards -- anything that reaches the tailnet can otherwise register.
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Library/Application Support/reading";
      description = "Where both services keep their state.";
    };

    libraryDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/books/Calibre Library";
      description = ''
        The Calibre library calibre-web serves. calibre-web does not create one;
        it needs a metadata.db that Calibre itself made, so the agent stays down
        until this exists rather than looping on a missing file.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && pkgs.stdenv.hostPlatform.isDarwin) {
    home.packages = [
      pkgs.readeck
      pkgs.calibre-web
    ];

    # The secret key is generated once, here, rather than left to readeck

    # readeck writes a generated key back into its config file on first run --
    # but the config is a nix store path, so the write silently fails and a new
    # key is minted on every start, invalidating every session each time the
    # agent restarts. READECK_SECRET_KEY overrides the file, so the key lives in
    # the data directory (0600, never in the store or this repo) and the config
    # stays declarative.

    home.activation.readingDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p "${cfg.dataDir}/readeck" "${cfg.dataDir}/calibre-web" \
        "${cfg.dataDir}/kosync"
      if [ ! -s "${cfg.dataDir}/readeck/secret_key" ]; then
        run ${lib.getExe' pkgs.openssl "openssl"} rand -base64 48 \
          | tr -d '\n' > "${cfg.dataDir}/readeck/secret_key"
        run chmod 600 "${cfg.dataDir}/readeck/secret_key"
      fi
    '';

    launchd.agents.readeck = {
      enable = true;
      config = {

        # Wrapped so the key can be read at start time. launchd's

        # EnvironmentVariables are fixed at build time and cannot hold a value
        # generated on the machine.

        ProgramArguments = [
          "${pkgs.writeShellScript "readeck-start" ''
            export READECK_SECRET_KEY="$(cat "${cfg.dataDir}/readeck/secret_key")"
            exec ${lib.getExe' pkgs.readeck "readeck"} serve -config ${readeckConfig}
          ''}"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        WorkingDirectory = cfg.dataDir;
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/readeck.out.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/readeck.err.log";
      };
    };

    # calibre-web is wrapped rather than run directly: it needs the...

    # calibre-web is wrapped rather than run directly: it needs the library path
    # and its settings db passed as flags, and it must not start at all without a
    # library -- launchd would otherwise restart it forever against a metadata.db
    # that is never going to appear on its own.

    launchd.agents.calibre-web = {
      enable = true;
      config = {
        ProgramArguments = [
          "${pkgs.writeShellScript "calibre-web-start" ''
            if [ ! -f "${cfg.libraryDir}/metadata.db" ]; then
              echo "calibre-web: no Calibre library at ${cfg.libraryDir}; create one in Calibre first."
              exit 0
            fi
            exec ${lib.getExe' pkgs.calibre-web "calibre-web"} \
              -p "${cfg.dataDir}/calibre-web/app.db" \
              -i "${cfg.host}" \
              -o "${cfg.dataDir}/calibre-web/access.log"
          ''}"
        ];
        RunAtLoad = true;
        KeepAlive = {
          SuccessfulExit = false;
        };
        WorkingDirectory = cfg.dataDir;
        EnvironmentVariables = {
          CALIBRE_DBPATH = cfg.dataDir + "/calibre-web";
          CALIBRE_PORT = toString cfg.calibreWebPort;
        };
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/calibre-web.out.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/calibre-web.err.log";
      };
    };

    # Where the reading position lives

    # calibre-web hands out the books and readeck holds the articles; neither knows
    # how far through anything you are. KOReader syncs that itself, against a
    # kosync server -- five endpoints and one row per book -- and the point of
    # running our own is that the public instance is somebody else's record of what
    # you read and how fast.

    # Written here rather than packaged: nixpkgs has neither the official Lua
    # server nor any of the reimplementations, and the official one wants OpenResty
    # and Redis to store an integer per book. This is stdlib Python against SQLite,
    # so it needs no interpreter beyond the one already in the closure and the
    # database sits next to the other reading state, inside the same backup.

    # The X4 Pro's own reader does not speak this protocol -- CrossPoint keeps
    # bookmarks as JSON under .crosspoint and syncs with nothing. It is an Android
    # device, so KOReader installs on it as an APK, and that is what talks here.

    # It is off. This server lives on the tailnet and the X4 Pro is not on the
    # tailnet, so KOReader there and Emacs here both point at the public CrossPoint
    # server, which sees document hashes and percentages but not the books. The X4
    # Pro is Android and Tailscale installs on Android; on the day it does, `enable'
    # comes back and `my/kosync-url' points here.

    launchd.agents.kosync = {
      enable = false;
      config = {
        ProgramArguments = [
          "${lib.getExe pkgs.python3}"
          "${./kosync.py}"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        WorkingDirectory = cfg.dataDir;
        EnvironmentVariables = {
          KOSYNC_DB = "${cfg.dataDir}/kosync/kosync.db";
          KOSYNC_HOST = cfg.host;
          KOSYNC_PORT = toString cfg.kosyncPort;
          KOSYNC_ALLOW_REGISTER = if cfg.kosyncAllowRegistration then "1" else "0";
        };
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/kosync.out.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/kosync.err.log";
      };
    };
  };
}
