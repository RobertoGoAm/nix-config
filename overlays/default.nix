# This file defines overlays
{ inputs, ... }:
{
  # pin-prefs: regenerates the macOS defaults modules from live prefs.
  pin-prefs = import ./pin-prefs.nix;

  # check-pins: drift report for the hand-maintained version pins.
  check-pins = import ./check-pins.nix;

  # warpd: nixpkgs ships it Linux-only; build it from source on darwin.
  warpd = import ./warpd.nix;

  # checkov: skip one upstream-broken test that fails the build.
  checkov = import ./checkov.nix;

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  # modifications = final: prev: {
  #   example = prev.example.overrideAttrs (oldAttrs: rec {
  #     ...
  #   });
  # };

  # Import all apple silicon overlays in the folder
  apple-silicon =
    final: prev:
    let
      files = builtins.filter (n: builtins.match "apple-silicon-.*\\.nix" n != null) (
        builtins.attrNames (builtins.readDir ./.)
      );

      importOverlay = name: import (./. + "/${name}") final prev;
    in
    builtins.foldl' (acc: name: acc // (importOverlay name)) { } files;

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  # unstable-packages = final: _prev: {
  #   unstable = import inputs.nixpkgs-unstable {
  #     system = final.system;
  #     config.allowUnfree = true;
  #   };
  # };
}
