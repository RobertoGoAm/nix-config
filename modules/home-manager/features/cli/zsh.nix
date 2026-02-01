{
  programs.zsh = {
    enable = true;

    autosuggestion = {
      enable = true;
    };

    enableCompletion = true;

    initContent = ''
      eval "$(fnm env --use-on-cd)"

      export PATH="$HOME/.rd/bin:$PATH"
      export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"

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
    '';

    oh-my-zsh = {
      enable = true;
    };

    syntaxHighlighting = {
      enable = true;
    };
  };

  home.file.".hushlogin" = {
    text = "";
  };
}
