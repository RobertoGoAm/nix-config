self: super: {
  chromium = super.stdenv.mkDerivation rec {
    version = "1368521";

    name = "Chromium-${version}";
    buildInputs = [ super.unzip ];
    sourceRoot = ".";
    phases = [ "unpackPhase" "installPhase" ];
    installPhase = ''
      mkdir -p "$out/Applications"
      cp -r chrome-mac/Chromium.app "$out/Applications/Chromium.app"
    '';

    src = super.fetchurl {
      name = "Mac_Arm_${version}_chrome-mac.zip";
      url = "https://www.googleapis.com/download/storage/v1/b/chromium-browser-snapshots/o/Mac_Arm%2F${version}%2Fchrome-mac.zip?generation=1728953032008580&alt=media";
      sha256 = "86ed1b3b90886c3ba0666b8e330681f77fe5240aa49da1375059029e9b58f12b";
    };

    meta = with super.stdenv.lib; {
      description = "Chromium";
      homepage = "http://www.chromium.org";
      maintainers = with super.maintainers; [ robertogoam ];
      platforms = [ "aarch64-darwin" ];
    };
  };
}