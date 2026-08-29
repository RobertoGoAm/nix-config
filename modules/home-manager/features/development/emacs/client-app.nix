# A GUI entry point that attaches to the daemon instead of starting a rival Emacs.
#
# services.emacs already runs `emacs --fg-daemon' under launchd, and the `em'
# wrapper opens terminal frames against it -- but the Emacs.app that
# home-manager copies into ~/Applications/Home Manager Apps is the raw NS build.
# Launching it from Spotlight or the Dock starts a SECOND, independent Emacs:
# its own buffers, its own session, and its own copy of every language server
# for the same projects. The two never meet, so a file open in the app is
# invisible to `em', and the daemon this config is built around ends up
# unused.
#
# This bundle is the icon to click instead. --alternate-editor="" means a
# missing daemon is started rather than an error, so it works before launchd
# has got there and on a machine where the agent is off.
#
# The stock Emacs.app is deliberately left in place: it is what home-manager
# installs, and it is still the way to get a clean instance for testing a
# config change without disturbing the running one.
{
  config,
  pkgs,
  lib,
  ...
}:
lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  home.packages = [
    (pkgs.runCommand "emacs-client-app" { } ''
      app="$out/Applications/Emacs Client.app"
      mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

      cat > "$app/Contents/MacOS/Emacs Client" <<SCRIPT
      #!/bin/bash
      # -c for a new graphical frame; the empty alternate editor starts a
      # daemon if none is listening rather than failing.
      #
      # -n so emacsclient returns as soon as the frame exists instead of
      # blocking until it is closed. Without it this script stays alive for the
      # whole editing session, and macOS keeps a second Dock icon for it
      # alongside the daemon's own -- which reads as the launcher being stuck,
      # when the window it opened is right there under the name "Emacs".
      # Returning immediately is enough: the icon goes when the process does.
      #
      # LSUIElement would hide that icon outright, and was tried here, but the
      # bundle then stopped launching from Finder and Spotlight altogether.
      # Not worth it for a second of Dock icon.
      exec "${config.programs.emacs.finalPackage}/bin/emacsclient" \
        -c -n --alternate-editor="" "\$@"
      SCRIPT
      chmod +x "$app/Contents/MacOS/Emacs Client"

      cat > "$app/Contents/Info.plist" <<'PLIST'
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>CFBundleExecutable</key>
        <string>Emacs Client</string>
        <key>CFBundleIconFile</key>
        <string>Emacs</string>
        <key>CFBundleIdentifier</key>
        <string>org.gnu.Emacs.client</string>
        <key>CFBundleName</key>
        <string>Emacs Client</string>
        <key>CFBundlePackageType</key>
        <string>APPL</string>
        <key>CFBundleVersion</key>
        <string>1.0</string>
        <key>NSHighResolutionCapable</key>
        <true/>
      </dict>
      </plist>
      PLIST

      cp "${config.programs.emacs.finalPackage}/Applications/Emacs.app/Contents/Resources/Emacs.icns" \
         "$app/Contents/Resources/Emacs.icns"
    '')
  ];
}
