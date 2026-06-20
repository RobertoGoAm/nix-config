{
  imports = [
    ./alacritty.nix
    ./claude.nix
    ./cli-tools.nix
    ./devforge.nix
    ./gh.nix
    ./gpg.nix
    ./hammerspoon.nix # macOS quake terminal (Alacritty drop-down); no-op off darwin
    ./opencode.nix
    ./ripgrep.nix
    ./ssh.nix
    ./starship.nix
    ./tmux.nix
    ./wifi.nix
    ./zsh.nix
  ];
}
