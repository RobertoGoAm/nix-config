# pin-prefs: regenerates the targets.darwin.defaults modules from...

# pin-prefs: regenerates the targets.darwin.defaults modules from live prefs.

final: _prev: {
  pin-prefs = final.callPackage ../pkgs/pin-prefs.nix { };
}
