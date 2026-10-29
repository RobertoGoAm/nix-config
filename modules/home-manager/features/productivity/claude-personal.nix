# A second Claude Desktop, signed into a different account

# Claude Desktop holds one login per data folder, and the app is signed into
# the Mindden organisation. A personal account has to sit beside it -- both
# windows open at once -- rather than take turns behind a sign-out.

# The release build ignores =CLAUDE_USER_DATA_DIR=, but it honours Electron's
# =--user-data-dir= switch. A second instance launched with its own folder gets
# its own login, history, settings and lock, and runs next to the default one
# on the same =/Applications/Claude.app=, so the cask's updates reach both.

{
  config,
  lib,
  pkgs,
  ...
}:
let

  # Where Claude lives, and where the second profile goes

  # =/Applications=, not the nix store: Claude is a homebrew cask.

  # The profile sits under Application Support next to the default
  # =~/Library/Application Support/Claude=, so the two are easy to find, back up or
  # throw away together. It must never be the default folder itself: two instances
  # on one folder leave the second one signed out.

  claudePath = "/Applications/Claude.app";
  profile = "$HOME/Library/Application Support/Claude Personal";

  # Launched through =open=, not exec'd

  # =chrome-dev= execs Chrome's binary from inside its own wrapper bundle. That
  # does not carry over: Electron finds its frameworks and resources through the
  # main bundle, which would then be this wrapper rather than =Claude.app=.

  # =open -n= starts a fresh instance of the real bundle instead, with the switch
  # passed through =--args=. The wrapper exits as soon as it has handed over, so
  # the Dock shows the running Claude rather than the launcher.

  launcher = ''
    if [ ! -d "${claudePath}" ]; then
      echo "Claude is not installed at ${claudePath} (it comes from the homebrew cask)." >&2
      exit 1
    fi
    mkdir -p "${profile}"
    exec open -n -a "${claudePath}" --args --user-data-dir="${profile}"
  '';

  # The app bundle

  # A wrapper .app so the second account is reachable from Spotlight and the Dock,
  # not only from a shell. It borrows Claude's icon.

  darwinApp = pkgs.runCommand "claude-personal" { } ''
    app="$out/Applications/Claude Personal.app"
    mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

    cat > "$app/Contents/MacOS/Claude Personal" <<'SCRIPT'
    #!/bin/bash
    ${launcher}
    SCRIPT
    chmod +x "$app/Contents/MacOS/Claude Personal"

    cat > "$app/Contents/Info.plist" <<'PLIST'
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleExecutable</key>
      <string>Claude Personal</string>
      <key>CFBundleIconFile</key>
      <string>app</string>
      <key>CFBundleIdentifier</key>
      <string>com.anthropic.claudefordesktop.Personal</string>
      <key>CFBundleName</key>
      <string>Claude Personal</string>
      <key>CFBundlePackageType</key>
      <string>APPL</string>
      <key>CFBundleVersion</key>
      <string>1.0</string>
      <key>LSUIElement</key>
      <true/>
      <key>NSHighResolutionCapable</key>
      <true/>
    </dict>
    </plist>
    PLIST

    if [ -f "${claudePath}/Contents/Resources/electron.icns" ]; then
      cp "${claudePath}/Contents/Resources/electron.icns" "$app/Contents/Resources/app.icns"
    fi
  '';

  # The same account on the command line

  # The CLI keeps its login, history and settings in one folder too, =~/.claude=,
  # and that one is signed into the Mindden organisation. =CLAUDE_CONFIG_DIR= moves
  # the whole of it, credentials included: the keychain item the CLI stores its
  # token in is named after the folder, so a second folder is a second login rather
  # than a shared one.

  # =claude-personal= is =claude= pointed at its own folder. Anything the CLI does
  # takes the same arguments behind it -- =claude-personal auth login= to sign in,
  # =claude-personal= to open a session.

  cliHome = "${config.home.homeDirectory}/.claude-personal";

  cli = pkgs.writeShellScriptBin "claude-personal" ''
    export CLAUDE_CONFIG_DIR="${cliHome}"
    exec claude "$@"
  '';

  # Personal sessions reachable from the phone without the desktop app

  # =claude remote-control= is a server that registers this machine with the
  # account it is signed into, and from then on claude.ai/code and the Claude app on
  # the phone list it and can open sessions on it. It is what the desktop app's
  # Remote Control does for one of its own sessions, without the window around it --
  # the same split as =codex remote-control= in =features/cli/codex.nix=.

  # It runs as the personal account because of =CLAUDE_CONFIG_DIR=, and it serves
  # the home folder: every session it starts begins there, and the phone has no way
  # to pick another folder at the point of starting one.

  remoteControl =
    let
      start = pkgs.writeShellScript "claude-personal-remote-control-start" ''
        export CLAUDE_CONFIG_DIR="${cliHome}"
        command -v claude >/dev/null || exit 0
        claude auth status >/dev/null 2>&1 || exit 0
        cd "${config.home.homeDirectory}"
        exec claude remote-control
      '';
    in
    {
      enable = true;
      config = {
        ProgramArguments = [ "${start}" ];

        # Run at load, retried on a timer, never kept alive

        # Unlike codex's =start=, =claude remote-control= stays in the foreground for as
        # long as it serves, so launchd owns the process directly.

        # Not ~KeepAlive~ all the same. Until =claude-personal auth login= has run, the
        # script finds no login and exits; ~KeepAlive~ would relaunch that every ten
        # seconds for as long as nobody signs in. A ~StartInterval~ is quieter and gets
        # the same result: launchd does not start a job that is still running, so while
        # the server is up the timer does nothing, and if it died, or the login came
        # after the agent loaded, it is up again within fifteen minutes. =launchctl
        # kickstart gui/$UID/org.nix-community.home.claude-personal-remote-control= does
        # it now rather than at the next tick.

        # The first time the server is asked to work in the home folder it wants that
        # folder trusted, and with no terminal it cannot ask. Running =claude-personal=
        # once from =~= answers it.

        # No ~ProcessType = "Background"~ and the PATH spelled out, for the reasons given
        # beside the codex agent: the sessions it runs inherit both.

        RunAtLoad = true;
        StartInterval = 900;

        EnvironmentVariables = {
          PATH = lib.concatStringsSep ":" [
            "${config.home.homeDirectory}/.nix-profile/bin"
            "/etc/profiles/per-user/${config.home.username}/bin"
            "/run/current-system/sw/bin"
            "/nix/var/nix/profiles/default/bin"
            "/opt/homebrew/bin"
            "/usr/local/bin"
            "/usr/bin"
            "/bin"
            "/usr/sbin"
            "/sbin"
          ];
        };

        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/claude-personal-remote-control.out.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/claude-personal-remote-control.err.log";
      };
    };

  # What the module installs

  # The app and the agent are darwin only: Linux has no Claude Desktop, and launchd
  # is macOS's. The CLI wrapper works anywhere.

in
{
  home.packages = [ cli ] ++ lib.optional pkgs.stdenv.hostPlatform.isDarwin darwinApp;

  launchd.agents.claude-personal-remote-control = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin remoteControl;
}
