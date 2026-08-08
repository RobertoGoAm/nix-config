# nixpkgs refuses to evaluate chromium on aarch64-darwin, so pull Google's
# official Mac ARM snapshot build instead.
#
# The revision is a hand-pinned snapshot number and nothing updates it
# automatically — neither flake.lock nor nix-update can move it. `nix run
# .#check-pins` reports when it has fallen behind; bump `version` and refresh
# the hash with:
#
#   nix-prefetch-url --type sha256 \
#     https://storage.googleapis.com/chromium-browser-snapshots/Mac_Arm/<rev>/chrome-mac.zip
self: super: {
  chromium = super.stdenv.mkDerivation rec {
    version = "1676167";

    name = "Chromium-${version}";
    buildInputs = [ super.unzip ];
    sourceRoot = ".";
    phases = [
      "unpackPhase"
      "installPhase"
    ];
    installPhase = ''
      mkdir -p "$out/Applications"
      cp -r chrome-mac/Chromium.app "$out/Applications/Chromium.app"
    '';

    src = super.fetchurl {
      name = "Mac_Arm_${version}_chrome-mac.zip";
      url = "https://storage.googleapis.com/chromium-browser-snapshots/Mac_Arm/${version}/chrome-mac.zip";
      sha256 = "16ry8d57c2hs3yagrnq39iq3chjn6zrz3dgw8qgnzhl56kvh5qwg";
    };

    meta = {
      description = "Chromium";
      homepage = "https://www.chromium.org";
      platforms = [ "aarch64-darwin" ];
    };
  };
}
