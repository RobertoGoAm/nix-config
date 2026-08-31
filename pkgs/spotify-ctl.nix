# spotify-ctl: now-playing and transport control over the Spotify Web API.
#
# Replaces the AppleScript the menu bar used to run, which could only reach a
# running Spotify.app. This reaches whatever Connect device is active, which
# is normally the headless librespot agent -- so the status item keeps working
# with no desktop client installed.
{ writers }:
writers.writePython3Bin "spotify-ctl" { flakeIgnore = [ "E501" ]; } (builtins.readFile ./spotify-ctl.py)
