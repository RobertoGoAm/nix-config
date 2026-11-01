# opengrep: semgrep's rules without a Python to run them

final: _prev: {
  opengrep = final.callPackage ../pkgs/opengrep.nix { };
}
