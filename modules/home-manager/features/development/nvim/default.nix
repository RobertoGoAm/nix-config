# development nvim

{ config, lib, ... }:
let
  colemak = config.features.productivity.keyboard.layout == "colemak";
in
{
  imports = [ ../../productivity/keyboard-layout.nix ];

  programs.nixvim = {
    enable = true;
    defaultEditor = true;

    # Nixvim evaluates plugins against its own nixpkgs instance (not the

    # host's), so system-level allowUnfree does not apply to cmp-spell etc.

    nixpkgs.config.allowUnfree = true;

    imports = [
      ./colorscheme.nix
      (import ./keybinds.nix { inherit colemak lib; })
      ./options.nix
      ./plugins
    ];
  };
}
