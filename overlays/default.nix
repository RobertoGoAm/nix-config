# This file defines overlays

{ inputs, ... }:
{

  # pin-prefs: regenerates the macOS defaults modules from live prefs

  pin-prefs = import ./pin-prefs.nix;

  # check-pins: drift report for the hand-maintained version pins

  check-pins = import ./check-pins.nix;

  # warpd: nixpkgs ships it Linux-only; build it from source on darwin

  warpd = import ./warpd.nix;

  # checkov: skip one upstream-broken test that fails the build

  checkov = import ./checkov.nix;

  # lit-tangle: regenerates this repo's .nix from the literate org...

  # lit-tangle: regenerates this repo's .nix from the literate org sources.

  lit-tangle = import ./lit-tangle.nix;

  # neovim: skip one darwin-flaky treesitter test that fails the build

  neovim = import ./neovim.nix;

  # spotify-ctl: Web API now-playing and controls for the menu bar

  spotify-ctl = import ./spotify-ctl.nix;

  # When applied, the unstable nixpkgs set (declared in the flake...

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  # unstable-packages = final: _prev: {
  #   unstable = import inputs.nixpkgs-unstable {
  #     system = final.system;
  #     config.allowUnfree = true;
  #   };
  # };

}
