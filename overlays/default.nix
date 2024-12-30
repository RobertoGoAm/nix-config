# This file defines overlays
{inputs, ...}: {
  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  # modifications = final: prev: {
  #   example = prev.example.overrideAttrs (oldAttrs: rec {
  #     ...
  #   });
  # };

  # Import all apple silicon overlays in the folder
  apple-silicon = final: prev:
    let
      files = builtins.filter
        (n: builtins.match "apple-silicon-.*\\.nix" n != null)
        (builtins.attrNames (builtins.readDir ./.));
        
      importOverlay = name: import (./. + "/${name}") final prev;
    in
    builtins.foldl' (acc: name: acc // (importOverlay name)) {} files;

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  # unstable-packages = final: _prev: {
  #   unstable = import inputs.nixpkgs-unstable {
  #     system = final.system;
  #     config.allowUnfree = true;
  #   };
  # };
}
