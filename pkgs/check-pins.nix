# Reports drift on the two things in this repo that nothing updates for you.
#
# flake.lock covers every nixpkgs package, and warpd rides prev.warpd.src, so
# both move on `nix-update`. These do not:
#
#   - the Chromium snapshot pinned in overlays/apple-silicon-chromium.nix
#   - the marketplace extensions pinned by version + sha256 in the vscode module
#
# Read-only: it prints what has fallen behind and exits 1 so it can gate a
# check, but never edits anything.
{
  lib,
  writeShellApplication,
  curl,
  python3,
}:
writeShellApplication {
  name = "check-pins";

  runtimeInputs = [
    curl
    python3
  ];

  text = ''
    root="''${1:-.}"
    exec python3 "${./check-pins.py}" "$root"
  '';

  meta = {
    description = "Report drift on the version pins nothing updates automatically";
    mainProgram = "check-pins";
    platforms = lib.platforms.all;
  };
}
