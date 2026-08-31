# check-pins: reports (and with --update, fixes) the version pins...

# check-pins: reports (and with --update, fixes) the version pins nothing in
# this repo updates automatically. An overlay rather than a flake package so
# every host gets it through pkgs, including the standalone Linux one.

final: _prev: {
  check-pins = final.callPackage ../pkgs/check-pins.nix { };
}
