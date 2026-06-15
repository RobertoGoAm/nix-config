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

      # Update nix packages and show diff between generations
      nix-update() {
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

          echo "🔄 Updating flake inputs..."
          nix flake update || exit 1

          echo "⚙️ Rebuilding nix-darwin..."
          sudo nix run nix-darwin -- switch --flake . --impure || exit 1
        )

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
