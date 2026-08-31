# Regenerates the macOS defaults modules from an app's live...

# Regenerates the macOS defaults modules from an app's live preferences.
# See pin-prefs.py for what it filters and why.

{
  lib,
  writeShellApplication,
  python3,
}:
writeShellApplication {
  name = "pin-prefs";
  runtimeInputs = [ python3 ];
  text = ''
    exec python3 "${./pin-prefs.py}" "$@"
  '';
  meta = {
    description = "Regenerate a macOS defaults module from an app's live preferences";
    mainProgram = "pin-prefs";
    platforms = lib.platforms.darwin;
  };
}
