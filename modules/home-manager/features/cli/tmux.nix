{ pkgs, ... }:
{
  programs.tmux = {
    enable = true;
    mouse = true;
    shell = "${pkgs.zsh}/bin/zsh";
    baseIndex = 1;
    historyLimit = 10000;
    
    # Change prefix to Ctrl-Space to avoid conflicts and match "Space" leader vibes
    prefix = "C-Space";
    
    keyMode = "vi";
    customPaneNavigationAndResize = true;

    extraConfig = ''
      # Split panes using | and -
      bind | split-window -h
      bind - split-window -v
      unbind '"'
      unbind %

      # Reload config
      bind r source-file ~/.config/tmux/tmux.conf \; display "Reloaded!"

      # Colemak-DH / Aerospace / Vim consistent navigation
      # h - Left
      # n - Down
      # e - Up
      # i - Right
      
      bind -r h select-pane -L
      bind -r n select-pane -D
      bind -r e select-pane -U
      bind -r i select-pane -R

      # Resize panes with same keys (capitalized)
      bind -r H resize-pane -L 5
      bind -r N resize-pane -D 5
      bind -r E resize-pane -U 5
      bind -r I resize-pane -R 5

      # No delay for escape key press (essential for Vim)
      set -s escape-time 0
    '';
  };
}