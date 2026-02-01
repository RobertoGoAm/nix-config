{ pkgs, ... }:
{
  programs.doom-emacs = {
    enable = true;
    doomDir = ./doom; # path to your Doom config
  };
}
