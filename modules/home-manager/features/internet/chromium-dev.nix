{
  pkgs,
  config,
  ...
}:
let
  chromiumDev = pkgs.stdenv.mkDerivation {
    pname = "chromium-dev";
    version = "1.0.0";

    dontUnpack = true;

    nativeBuildInputs = [ pkgs.makeWrapper ];

    installPhase =
      let
        chromiumPath = "${config.programs.chromium.package}/Applications/Chromium.app";
      in
      ''
        mkdir -p "$out/Applications/Chromium Dev.app/Contents/MacOS"
        mkdir -p "$out/Applications/Chromium Dev.app/Contents/Resources"

        # Create the launcher script
        cat > "$out/Applications/Chromium Dev.app/Contents/MacOS/Chromium Dev" <<'SCRIPT'
#!/bin/bash
exec "${chromiumPath}/Contents/MacOS/Chromium" \
  --disable-web-security \
  --user-data-dir="/tmp/chromium_dev" \
  "$@"
SCRIPT
        chmod +x "$out/Applications/Chromium Dev.app/Contents/MacOS/Chromium Dev"

        # Create Info.plist
        cat > "$out/Applications/Chromium Dev.app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>Chromium Dev</string>
  <key>CFBundleIconFile</key>
  <string>app</string>
  <key>CFBundleIdentifier</key>
  <string>org.chromium.Chromium.Dev</string>
  <key>CFBundleName</key>
  <string>Chromium Dev</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleVersion</key>
  <string>1.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

        # Copy the icon from Chromium
        if [ -f "${chromiumPath}/Contents/Resources/app.icns" ]; then
          cp "${chromiumPath}/Contents/Resources/app.icns" \
            "$out/Applications/Chromium Dev.app/Contents/Resources/app.icns"
        fi
      '';

    meta = {
      description = "Chromium with web security disabled for local development";
      platforms = pkgs.lib.platforms.darwin;
    };
  };
in
{
  home.packages = [ chromiumDev ];
}
