# checkov on nixpkgs-unstable currently fails to build for two unrelated reasons.
# Both are upstream packaging lag, so drop this overlay once nixpkgs catches up.
#
#   1. pycep-parser: the derivation declares version "0.7.0" while the wheel's
#      .dist-info/METADATA says "0.7.0.dev9", which aborts
#      pythonMetadataCheckPhase. Patched through pythonPackagesExtensions rather
#      than python3Packages so it also reaches the private python set checkov
#      builds itself with (pkgs/by-name/ch/checkov/package.nix overrides
#      packageOverrides, which would otherwise drop our change).
#
#   2. checkov pins aiohttp<3.14.0 but nixpkgs ships 3.14.3, so
#      pythonRuntimeDepsCheck fails. Relaxed the same way nixpkgs already
#      relaxes several of checkov's other pins.
final: prev: {
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (
      _pyFinal: pyPrev: {
        pycep-parser = pyPrev.pycep-parser.overrideAttrs (_: {
          dontCheckPythonMetadata = true;
        });
      }
    )
  ];

  checkov = prev.checkov.overrideAttrs (oldAttrs: {
    pythonRelaxDeps = (oldAttrs.pythonRelaxDeps or [ ]) ++ [ "aiohttp" ];
  });
}
