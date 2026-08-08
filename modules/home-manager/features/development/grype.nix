{
  # Same reasoning as uv.nix: the module owns the package so grype's scanning
  # config can be declared later without moving the dependency around. Trivy
  # already carries the local scanner config (see trivy.nix).
  programs.grype.enable = true;
}
