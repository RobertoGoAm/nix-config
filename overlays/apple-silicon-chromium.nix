self: super: {
  chromium = super.stdenv.mkDerivation rec {
    version = "1585201";

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
      url = "https://www.googleapis.com/download/storage/v1/b/chromium-browser-snapshots/o/Mac_Arm%2F${version}%2Fchrome-mac.zip?generation=1771134849659379&alt=media";
      sha256 = "0kzswr5qij69i5gfxy72cqfly5j50xa1cw8nhxsmbfbdgizyxfnl";
    };

    meta = with super.stdenv.lib; {
      description = "Chromium";
      homepage = "http://www.chromium.org";
      maintainers = with super.maintainers; [ robertogoam ];
      platforms = [ "aarch64-darwin" ];
    };
  };
}
