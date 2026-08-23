{
  pkgs,
  ...
}:
let
  # Chrome with web security disabled, for local development. Previously built
  # on the chromium snapshot overlay; that overlay is gone, and Zen -- being
  # Firefox-based -- has no equivalent, since --disable-web-security is a
  # Chromium flag with no Gecko counterpart. Chrome accepts it identically, and
  # it is already installed as a cask for work, so it costs nothing extra.
  #
  # /Applications, not the nix store: Chrome is a homebrew cask, so the path is
  # fixed rather than a store reference. The launcher checks for it and says so
  # instead of failing with a bare "no such file".
  chromePath = "/Applications/Google Chrome.app";

  # Its own --user-data-dir on purpose. Chrome refuses --disable-web-security
  # against a normal profile, and pointing it at the real one would disable the
  # same-origin policy for everyday browsing, cookies and logins included.
  launcher = ''
    if [ ! -d "${chromePath}" ]; then
      echo "Google Chrome is not installed at ${chromePath} (it comes from the homebrew cask)." >&2
      exit 1
    fi
    exec "${chromePath}/Contents/MacOS/Google Chrome" \
      --disable-web-security \
      --user-data-dir="/tmp/chrome_dev" \
      "$@"
  '';

  darwinApp = pkgs.runCommand "chrome-dev" { } ''
    app="$out/Applications/Chrome Dev.app"
    mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

    cat > "$app/Contents/MacOS/Chrome Dev" <<'SCRIPT'
    #!/bin/bash
    ${launcher}
    SCRIPT
    chmod +x "$app/Contents/MacOS/Chrome Dev"

    cat > "$app/Contents/Info.plist" <<'PLIST'
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleExecutable</key>
      <string>Chrome Dev</string>
      <key>CFBundleIconFile</key>
      <string>app</string>
      <key>CFBundleIdentifier</key>
      <string>com.google.Chrome.Dev</string>
      <key>CFBundleName</key>
      <string>Chrome Dev</string>
      <key>CFBundlePackageType</key>
      <string>APPL</string>
      <key>CFBundleVersion</key>
      <string>1.0</string>
      <key>NSHighResolutionCapable</key>
      <true/>
    </dict>
    </plist>
    PLIST

    if [ -f "${chromePath}/Contents/Resources/app.icns" ]; then
      cp "${chromePath}/Contents/Resources/app.icns" "$app/Contents/Resources/app.icns"
    fi
  '';

  # Linux has no Chrome cask; google-chrome is in nixpkgs and is the same
  # browser, so the flag and the throwaway profile carry over unchanged.
  linuxBin = pkgs.writeShellScriptBin "chrome-dev" ''
    exec ${pkgs.google-chrome}/bin/google-chrome-stable \
      --disable-web-security \
      --user-data-dir="/tmp/chrome_dev" \
      "$@"
  '';
in
{
  home.packages = [ (if pkgs.stdenv.hostPlatform.isDarwin then darwinApp else linuxBin) ];
}
