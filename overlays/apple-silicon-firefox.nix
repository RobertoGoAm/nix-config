self: super: {
  firefox = super.stdenv.mkDerivation rec {
    version = "133.0";

    name = "Firefox";
    buildInputs = [ super.undmg super.unzip ];
    sourceRoot = ".";
    phases = [ "unpackPhase" "installPhase" ];
    installPhase = ''
      mkdir -p "$out/Applications"
      cp -r Firefox.app "$out/Applications/Firefox.app"
    '';

    src = super.fetchurl {
      name = "Firefox-${version}.dmg";
      url = "https://download-installer.cdn.mozilla.net/pub/firefox/releases/${version}/mac/en-US/Firefox%20${version}.dmg";
      sha256 = "02c76e21d64f21d4e45b1205717ccd0736a75f2a50b01c74b25b17e374447a76";
    };

    meta = with super.stdenv.lib; {
      description = "Firefox";
      homepage = "https://www.mozilla.org/es-ES/firefox/";
      maintainers = with super.maintainers; [ robertogoam ];
      platforms = [ "aarch64-darwin" ];
    };
  };
}
