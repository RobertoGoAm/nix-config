# lit-tangle: tangles the literate org sources into this repo's .nix files.
final: _prev: {
  lit-tangle = final.callPackage ../pkgs/lit-tangle.nix { };
}
