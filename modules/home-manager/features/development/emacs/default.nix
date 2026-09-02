# development emacs

{
  config,
  lib,
  pkgs,
  ...
}:
let

  # The NS build covers both runtimes: it installs Emacs.app for GUI...

  # The NS build covers both runtimes: it installs Emacs.app for GUI frames
  # (mac-app-util links it into ~/Applications) and the same binary runs
  # `emacs -nw` inside iTerm2/Alacritty. emacs-macport renders text slightly
  # better on macOS but is a patched fork, so the standard build wins by default.
  # Linux gets the pgtk build wrapped in nixGL, like alacritty.

  # Unversioned `emacs' rather than a pinned major: nixpkgs removed emacs30 in
  # August 2026 with a throw -- "'emacs30' has been superseded by 'emacs'" --
  # so there is no Emacs 30 left in this channel to pin to. Following the
  # default means major upgrades arrive with a flake update rather than being
  # chosen, which is worth knowing when one lands: `emacs' is 31.1 as of this
  # change.

  emacsPackage =
    if pkgs.stdenv.hostPlatform.isDarwin then pkgs.emacs else config.lib.nixGL.wrap pkgs.emacs-pgtk;
in
{
  imports = [
    ./client-app.nix
    ./colorscheme.nix
    ./keybinds.nix
    ./options.nix
    ./plugins
  ];

  # TRAMP writes temp files under the XDG cache, and a root-owned

  # ~/.cache/emacs (created once by something running under sudo) made every
  # remote file unreadable: "Creating file with prefix Permission denied", then
  # "File exists, but cannot be read" for anything opened over /docker:.
  # Creating it here as the user keeps that from recurring on a fresh machine.

  home.activation.emacsCacheDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.cache/emacs/tramp"
  '';

  programs.emacs = {
    enable = true;
    package = emacsPackage;

    # The lexical-binding cookie, first line of the generated default.el.
    #
    # home-manager concatenates every extraConfig into one file and writes no
    # header, so the whole configuration ran under dynamic binding. Emacs 30
    # warns about that on every start, and the behaviour behind the warning is
    # worse than the warning: a lambda does not capture its enclosing let, so
    # any closure silently loses its variables. The async status-bar sentinel
    # died exactly that way -- "Symbol's value as variable is void: callback"
    # -- and there are thirty-nine lambdas in the file.
    #
    # mkBefore because the cookie is only honoured on the very first line.
    # mkOrder 0, not mkBefore: another module already claims mkBefore (500),
    # and the cookie is only honoured on the very first line of the file.
    extraConfig = lib.mkOrder 0 ";;; -*- lexical-binding: t; -*-\n";
  };

  # A daemon under launchd (macOS) / systemd (Linux) is what makes...

  # A daemon under launchd (macOS) / systemd (Linux) is what makes "both runtimes"
  # one editor rather than two: `emacsclient -c` opens a GUI frame and
  # `emacsclient -nw` a terminal frame, against the same buffers and LSP servers.
  # $EDITOR deliberately stays on nvim (programs.nixvim.defaultEditor), so git and
  # the shell are untouched — this is an addition, not a replacement.

  services.emacs = {
    enable = true;
    client.enable = true;
    defaultEditor = false;
  };

  # Keep the daemon up, not merely restart it when it crashes

  # The agent services.emacs generates asks for
  #   KeepAlive = { Crashed = true; SuccessfulExit = false; }
  # so a CLEAN exit leaves it down permanently -- C-x C-c in the daemon's own
  # frame, a SIGTERM, an M-x kill-emacs. Observed exactly that:

  #   launchctl print gui/501/org.nix-community.home.emacs
  #     state = not running
  #     last exit code = 0

  # With no daemon, clicking Emacs Client falls through to emacsclient's
  # --alternate-editor, which starts a fresh daemon that must load this entire
  # config before any window appears. From the outside that is a launcher that
  # does nothing for several seconds and then maybe opens a bare frame -- which
  # is what "Emacs Client won't open" turned out to be.

  # KeepAlive removed with the agent: see below.

  # * A stable path in the agent, so a rebuild does not kill the daemon

  # The generated plist runs the emacs binary by its store path:

  # #+begin_example
  # exec /nix/store/iwa41j...-emacs-with-packages-31.1/bin/emacs --fg-daemon
  # #+end_example

  # Every change to this configuration produces a new =emacs-with-packages=, so
  # that string changes, so the plist changes -- and home-manager's activation
  # reloads any agent whose plist differs. Reloading means unloading: the daemon
  # dies and every frame with it. That is why a rebuild closed Emacs, whatever the
  # change happened to be.

  # Pointing at the profile instead keeps the plist byte-identical across rebuilds,
  # so the agent is left alone and the daemon survives. =home.profileDirectory= is
  # =/etc/profiles/per-user/<user>= here and =~/.nix-profile= under standalone
  # home-manager; both are stable paths, and swapping what they point at is exactly
  # what a rebuild does.

  # The trade is that the running daemon keeps the elisp it started with until it
  # is restarted deliberately -- =emacs-restart= below -- which is the point: when
  # Emacs goes away becomes a decision rather than a side effect.

  # Just the program: home-manager wraps ProgramArguments in its own
  # `/bin/sh -c "/bin/wait4path /nix/store && exec ..."', so supplying that
  # wrapper here too nests one inside the other.
  #
  # The bundle, not bin/emacs. Launched from bin/emacs the daemon has no
  # bundle identity: macOS lists it as a bare process called "emacs", with a
  # generic icon and nothing a Dock entry can point at. Launched from inside
  # Emacs.app it is org.gnu.Emacs, which is what gives the Dock icon its
  # running indicator and makes the frames emacsclient opens belong to it.
  #
  # The path stays stable across rebuilds, which is the property this whole
  # block exists to protect -- ~/Applications/Home Manager Apps is a real
  # directory that copyApps refreshes in place, not a store path that moves.
  # No agent. Emacs is started by clicking its icon and ends when its last
  # frame closes, so nothing should be launching it at login or restarting it
  # afterwards -- a KeepAlive daemon would come straight back frameless, and a
  # frameless Emacs cannot be reopened from the Dock at all.
  #
  # The cost is a cold start each time, around fifteen seconds here, most of
  # it direnv evaluating shells for the project buffers desktop restores.
  launchd.agents.emacs.enable = lib.mkForce false;

  # early-init runs before the first frame is drawn, so killing...

  # early-init runs before the first frame is drawn, so killing package.el and
  # pre-painting the frame background here is what stops the white startup flash.
  # Its presence also makes Emacs adopt ~/.config/emacs as user-emacs-directory,
  # keeping backups/auto-saves/eln-cache out of $HOME — the same reason nvim puts
  # its undo/backup/swap dirs under $XDG_CONFIG_HOME. (If ~/.emacs.d/init.el ever
  # appears, Emacs prefers that directory and skips this file; the rest of the
  # config still loads, since it ships as default.el inside the Emacs package.)

  home.file.".config/emacs/early-init.el".text = ''
    ;;; early-init.el --- pre-frame setup -*- lexical-binding: t; -*-
    ;;; Generated by nix — edit modules/home-manager/features/development/emacs.

    ;; package-enable-at-startup is deliberately left ON. It is tempting to switch it
    ;; off since nix installs every package — but nix installs them *as an ELPA tree*,
    ;; and it is package.el's `package-activate-all' that walks it and loads each
    ;; package's autoloads. Disabling it leaves every command that is autoloaded
    ;; rather than explicitly required (git-link, forge-dispatch, the treemacs
    ;; sub-modes, diff-hl-margin-mode, ...) undefined at runtime.

    ;; Paint the frame in tokyonight storm before redisplay, so startup never
    ;; flashes the default white background.
    ;; The font was never set, so every frame ran on macOS's default Menlo --
    ;; while nerd-icons was configured for JetBrainsMono Nerd Font and the
    ;; patched font was installed. The visible symptom is Nerd Font glyphs
    ;; coming out wrong rather than missing: starship's Node.js symbol is
    ;; U+E718, in the private use area, and Menlo claims that range and draws
    ;; something else for it. An apostrophe, in the prompt inside vterm.
    ;;
    ;; The "Mono" variant, not the bare family: it renders icons single-width,
    ;; which is what keeps a terminal prompt and the modeline in column.
    ;;
    ;; Here rather than in a hook, so it applies to the daemon's client frames
    ;; too and is in place before the first redisplay -- same reason the
    ;; colours are set here.
    (push '(font . "JetBrainsMono Nerd Font Mono-12") default-frame-alist)
    (push '(background-color . "#24283b") default-frame-alist)
    (push '(foreground-color . "#c0caf5") default-frame-alist)
    (push '(ns-transparent-titlebar . t) default-frame-alist)
    (push '(vertical-scroll-bars . nil) default-frame-alist)
    (push '(tool-bar-lines . 0) default-frame-alist)
    (setq frame-inhibit-implied-resize t
          inhibit-startup-screen t
          initial-scratch-message nil)

    ;; Native compilation is on in this build; keep its warnings out of the way and
    ;; its cache inside user-emacs-directory.
    (setq native-comp-async-report-warnings-errors 'silent
          native-comp-jit-compilation t)
    (when (fboundp 'startup-redirect-eln-cache)
      (startup-redirect-eln-cache
       (expand-file-name "eln-cache/" user-emacs-directory)))
  '';

  home.packages = [

    # consult-fd shells out to this; consult-ripgrep's ripgrep already...

    # consult-fd shells out to this; consult-ripgrep's ripgrep already arrives via
    # features/cli/ripgrep.nix.

    pkgs.fd

    # The terminal entry point. Unlike nvim, which reads $COLORTERM to...

    # The terminal entry point. Unlike nvim, which reads $COLORTERM to decide it can
    # do 24-bit colour, Emacs 30 only believes the terminfo entry — so under the
    # TERM=xterm-256color that alacritty.nix sets, tokyonight would be quantised to
    # 256 colours. `em` declares xterm-direct instead, with nix's terminfo database
    # so the entry is guaranteed to exist (macOS ships an ncurses too old to have
    # it). GUI frames are `emacsclient -c`; both attach to the same daemon.

    # Restarting the daemon on purpose, now that a rebuild no longer does it.
    #
    # `kickstart -k' stops the job and starts it again in one step, which is
    # what picks up newly built elisp. Frames are not preserved: emacsclient
    # frames belong to the daemon and go down with it.
    (pkgs.writeShellScriptBin "emacs-restart" ''
      set -eu
      # No launchd agent any more, so this quits the app and opens it again.
      # `open' rather than running the executable directly: it goes through
      # LaunchServices, which is what gives the process its bundle identity
      # and therefore the right Dock icon.
      app="$HOME/Applications/Home Manager Apps/Emacs.app"
      if emacsclient -e t >/dev/null 2>&1; then
        echo "Quitting Emacs..."
        emacsclient -e "(save-buffers-kill-emacs)" >/dev/null 2>&1 || true
        for _ in $(seq 1 60); do
          emacsclient -e t >/dev/null 2>&1 || break
          sleep 0.25
        done
      fi
      echo "Starting Emacs..."
      # No frame call afterwards: launching the app is what creates the frame
      # now. The daemon needed one because it started headless; asking for
      # another here would just open a second window.
      open -a "$app"
    '')

    (pkgs.writeShellScriptBin "em" ''
      exec env TERM=xterm-direct TERMINFO=${pkgs.ncurses}/share/terminfo \
        ${config.programs.emacs.finalPackage}/bin/emacsclient \
        -nw --alternate-editor="" "$@"
    '')
  ];
}
