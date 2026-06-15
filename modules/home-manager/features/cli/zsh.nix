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

      # Claude wrapper to ensure persistence
      claude() {
        local current_dir="$PWD"
        if [[ -n "$TMUX" ]]; then
          command claude "$@"
        else
          # Check if session exists
          if tmux has-session -t remote 2>/dev/null; then
            # Create a new window for the task to avoid interrupting existing work
            # and ensure we are in the correct directory
            tmux new-window -t remote -n "claude" -c "$current_dir"
            tmux send-keys -t remote "claude $*" C-m
            tmux attach-session -t remote
          else
            # Create new session starting in the current directory
            tmux new-session -s remote -c "$current_dir" "claude $*; zsh -i"
          fi
        fi
      }

      # Rebuild from the committed flake.lock (reproducible, no input bumps) and
      # show the generation diff. Everyday command. Builds as the invoking user
      # with --impure so the private files in ~/.config/nix-secrets are read at
      # eval (running the whole rebuild under sudo evaluates as root, whose $HOME
      # falls back to /var/root and silently drops them); only activation is
      # escalated.
      nix-build() {
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
        CONFIG_DIR="$HOME/nix-config"

        if [[ ! -d "$CONFIG_DIR" ]]; then
          echo "Config directory not found: $CONFIG_DIR"
          return 1
        fi

        echo "🔄 Updating flake inputs..."
        ( cd "$CONFIG_DIR" && nix flake update ) || return 1

        nix-build
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
