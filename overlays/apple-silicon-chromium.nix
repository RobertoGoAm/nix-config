self: super: {
  chromium = super.stdenv.mkDerivation rec {
    version = "M126.0.6478.231";

    name = "Thorium-${version}";
    buildInputs = [ super.undmg super.unzip ];
    sourceRoot = ".";
    phases = [ "unpackPhase" "installPhase" ];
    installPhase = ''
      mkdir -p "$out/Applications"
      cp -r Chromium.app "$out/Applications/Chromium.app"
    '';

    src = super.fetchurl {
      name = "Thorium_MacOS_ARM64.dmg";
      url = "https://github.com/Alex313031/Thorium-MacOS/releases/download/${version}/Thorium_MacOS_ARM64.dmg";
      sha256 = "041aa435b43b42308c7d4f32424891a95de0f62a63728d572b147b5585568628";
    };

    meta = with super.stdenv.lib; {
      description = "Thorium - The fastest browser on Earth.";
      homepage = "https://thorium.rocks/";
      maintainers = with super.maintainers; [ robertogoam ];
      platforms = [ "aarch64-darwin" ];
    };
  };
}
