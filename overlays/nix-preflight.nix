# nix-preflight: what the next nix-update would build locally

final: _prev: {
  nix-preflight = final.callPackage ../pkgs/nix-preflight.nix { };
}
