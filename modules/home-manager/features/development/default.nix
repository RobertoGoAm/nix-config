{
  config,
  lib,
  ...
}:
{
  imports = [
    ./emacs
    ./git.nix
    ./grype.nix
    ./java.nix
    ./nvim
    ./trivy.nix
    ./uv.nix
    ./vscode
  ];

  # Ensure the dev workspace root exists so the dock's Development stack and the
  # per-client git gitdir includes have a directory to point at on fresh machines.
  home.activation.developmentDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "${config.home.homeDirectory}/Development"
  '';
}
