self: super: {
  chromium = super.stdenv.mkDerivation rec {
    version = "131.0.6778.85-1.1";

    name = "Ungoogled-chromium-${version}";
    buildInputs = [ super.undmg super.unzip ];
    sourceRoot = ".";
    phases = [ "unpackPhase" "installPhase" ];
    installPhase = ''
      mkdir -p "$out/Applications/Chromium.app"
      cp -pR * "$out/Applications/Chromium.app"
    '';

    src = super.fetchurl {
      name = "ungoogled-chromium_${version}_arm64-macos.dmg";
      url = "https://github.com/ungoogled-software/ungoogled-chromium-macos/releases/download/${version}/ungoogled-chromium_${version}_arm64-macos.dmg";
      sha256 = "b84e27affc40ce2999c1990b231552e4f9c45f6f09f5255879127e99d3a4aebd";
    };

    meta = with super.stdenv.lib; {
      description = "The chromium browser, ungoogled";
      homepage = "https://github.com/ungoogled-software/ungoogled-chromium-macos";
      maintainers = with super.maintainers; [ robertogoam ];
      platforms = [ "aarch64-darwin" ];
    };
  };
}
