# cli zsh

{
  programs.zsh = {
    enable = true;

    autocd = true;

    autosuggestion = {
      enable = true;
    };

    enableCompletion = true;

    initContent = ''
      export PATH="$HOME/.rd/bin:$PATH"
      export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
      export KUBECONFIG="$HOME/.kube/config:$HOME/.kube/clusters/snippets-hetzner"
      export DOCKERHUB_USERNAME=robertogoam

      # Wrapper to notify when a long-running Claude task finishes

      # Auto-attach tmux on SSH login
      if [[ -n "$SSH_CONNECTION" && -z "$TMUX" ]]; then
        tmux attach-session -t remote || tmux new-session -s remote
      fi

      # Quick tmux remote session access
      alias tm='tmux attach-session -t remote || tmux new-session -s remote'

      # Run an interactive agent CLI inside the persistent `remote' tmux session.
      #
      # Each invocation gets its own tmux window, so starting a second agent
      # never interrupts a conversation already in flight, and closing the
      # terminal detaches instead of killing it. Already inside tmux there is
      # nothing to arrange, so the binary runs directly -- which is also what
      # stops the window we just created from re-entering this function.
      _agent_in_tmux() {
        local cmd="$1"; shift
        local current_dir="$PWD"
        if [[ -n "$TMUX" ]]; then
          command "$cmd" "$@"
        elif tmux has-session -t remote 2>/dev/null; then
          tmux new-window -t remote -n "$cmd" -c "$current_dir"
          tmux send-keys -t remote "$cmd $*" C-m
          tmux attach-session -t remote
        else
          tmux new-session -s remote -c "$current_dir" "$cmd $*; zsh -i"
        fi
      }

      # Resuming a conversation is the same idea in both CLIs, but spelled
      # differently: `claude --resume' / `-c', against `codex resume' with
      # `--last'. Both open a picker with no argument.
      claude() { _agent_in_tmux claude "$@" }
      codex()  { _agent_in_tmux codex "$@" }

      # The rebuild's copyApps step rsyncs into ~/Applications/Home Manager Apps,
      # which macOS gates behind the App Management privilege. That grant is tied
      # to the calling app's code signature — and Alacritty and iTerm2 both come
      # from nix, so every rebuild rewrites the very binary whose grant it needs
      # and the next one fails with "Operation not permitted". Terminal.app is a
      # system app whose signature never changes, so grant it once and it holds.
      #
      # Set NIX_REBUILD_HERE=1 to stay in the current terminal.
      _nix_rebuild_in_terminal() {
        local fn="$1"
        local script
        script="$(mktemp -t nix-rebuild-XXXXXX)"
        {
          echo '#!/bin/zsh'
          echo 'source "$HOME/.zshrc" >/dev/null 2>&1'
          echo "NIX_REBUILD_HERE=1 $fn"
          # `rc`, not `status`: zsh reserves `status` as a read-only alias for
          # `$?`, so assigning to it aborts the script with "read-only variable"
          # before the exit code is ever captured.
          echo 'rc=$?'
          echo "rm -f '$script'"
          # Close this window on success only. Terminal exists here purely to own
          # the App Management grant, so a clean run should leave nothing behind
          # — but a failed one has to stay readable. Matching on tty closes this
          # window and never one you were working in.
          echo 'if [ $rc -eq 0 ]; then'
          echo '  osascript -e "tell application \"Terminal\" to close (every window whose tty is \"$(tty)\")" >/dev/null 2>&1'
          echo 'else'
          echo '  echo; echo "Rebuild failed (exit $rc) — window kept open."'
          echo 'fi'
        } > "$script"
        chmod +x "$script"
        echo "↗️  Running $fn in Terminal.app (App Management grant lives there)..."
        open -a Terminal "$script"
      }

      # Pull e-reader highlights into the vault. Driven by hand rather than on a
      # timer: there is nothing to sync until the reader actually produces a
      # clippings file, and the format is still unverified against hardware.
      #
      # Defaults to the reader mounted over USB, so the common case is a bare
      # `clippings`; any other path can be passed instead. Extra flags
      # (--dry-run, --folder) pass through.
      clippings() {
        local src="''${1:-/Volumes/XTEINK/My Clippings.txt}"
        [[ $# -gt 0 ]] && shift
        if [[ ! -f "$src" ]]; then
          echo "clippings: nothing at $src (is the reader plugged in?)" >&2
          return 1
        fi
        nix run "$HOME/nix-config#clippings-import" -- \
          "$src" --vault "$HOME/Documents/robertogoam" "$@"
      }

      # Rebuild from the committed flake.lock (reproducible, no input bumps) and
      # show the generation diff. Everyday command. Builds as the invoking user
      # with --impure so the private files in ~/.config/nix-secrets are read at
      # eval (running the whole rebuild under sudo evaluates as root, whose $HOME
      # falls back to /var/root and silently drops them); only activation is
      # escalated.
      nix-build() {
        if [[ "$TERM_PROGRAM" != "Apple_Terminal" && -z "$NIX_REBUILD_HERE" ]]; then
          _nix_rebuild_in_terminal nix-build
          return $?
        fi

        CONFIG_DIR="$HOME/nix-config"

        if [[ ! -d "$CONFIG_DIR" ]]; then
          echo "Config directory not found: $CONFIG_DIR"
          return 1
        fi

        echo "🔐 Requesting sudo authentication..."
        if ! sudo -v; then
          echo "Sudo authentication failed."
          return 1
        fi

        (
          cd "$CONFIG_DIR" || exit 1

          echo "⚙️ Building system (impure, as you)..."
          sys=$(nix build --impure --no-link --print-out-paths ".#darwinConfigurations.$(hostname -s).system") || exit 1

          echo "⚙️ Activating (sudo)..."
          sudo nix-env -p /nix/var/nix/profiles/system --set "$sys" || exit 1
          sudo "$sys/sw/bin/darwin-rebuild" activate || exit 1
        ) || return 1

        echo "🔍 Calculating generation diff..."

        current="$(basename "$(readlink /nix/var/nix/profiles/system)")"

        prev="$(find /nix/var/nix/profiles \
          -maxdepth 1 \
          -type l \
          -name 'system-*-link' \
          ! -name "$current" \
          -print \
          | sort -V \
          | tail -n 1 \
          | xargs basename)"

        if [[ -z "$prev" ]]; then
          echo "No previous generation found."
          return 0
        fi

        echo
        echo "Diffing: $prev → $current"
        echo

        nix store diff-closures \
          "/nix/var/nix/profiles/$prev" \
          "/nix/var/nix/profiles/$current"
      }

      # Bump flake inputs, then rebuild. Deliberate: upstream churn can break the
      # build (an input not yet caught up to a nixpkgs change). If that happens,
      # run `git restore flake.lock` and use `nix-build` until it's resolved.
      nix-update() {
        if [[ "$TERM_PROGRAM" != "Apple_Terminal" && -z "$NIX_REBUILD_HERE" ]]; then
          _nix_rebuild_in_terminal nix-update
          return $?
        fi

        CONFIG_DIR="$HOME/nix-config"

        if [[ ! -d "$CONFIG_DIR" ]]; then
          echo "Config directory not found: $CONFIG_DIR"
          return 1
        fi

        echo "🔄 Updating flake inputs..."
        ( cd "$CONFIG_DIR" && nix flake update ) || return 1

        nix-build

        # Only here, never in nix-build: nix-build is meant to reproduce the
        # committed pins exactly, so it has nothing to say about them. Updating
        # is this function's job, and flake.lock cannot reach the marketplace
        # extensions pinned by hand — this is the one place that reports them.
        # Non-fatal: drift is not a failed rebuild.
        echo
        echo "📌 Checking the pins flake.lock cannot reach..."
        check-pins "$CONFIG_DIR" || true
      };
    '';

    oh-my-zsh = {
      enable = true;
      plugins = [
        "bgnotify"
        "colorize"
        "direnv"
        "docker"
        "docker-compose"
        "gh"
        "git"
        "git-commit"
        "kubectl"
        "mise"
        "ngrok"
        "pm2"
        "sudo"
        "tailscale"
        "terraform"
        "tmux"
      ];
    };

    syntaxHighlighting = {
      enable = true;
    };
  };

  home.file.".hushlogin" = {
    text = "";
  };
}
