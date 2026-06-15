# Helm 4.x: nixpkgs checkPhase still patches v3 test paths that no longer exist.
final: prev: {
  kubernetes-helm = prev.kubernetes-helm.overrideAttrs (_: {
    doCheck = false;
  });
}
