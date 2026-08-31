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
      run mkdir -p "${cfg.dataDir}/readeck" "${cfg.dataDir}/calibre-web"
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
        KeepAlive = false;
        WorkingDirectory = cfg.dataDir;
        EnvironmentVariables = {
          CALIBRE_DBPATH = cfg.dataDir + "/calibre-web";
          CALIBRE_PORT = toString cfg.calibreWebPort;
        };
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/calibre-web.out.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/calibre-web.err.log";
      };
    };
  };
}
