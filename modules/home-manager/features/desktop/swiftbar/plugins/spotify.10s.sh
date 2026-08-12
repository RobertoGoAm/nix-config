#!/bin/sh
# Now playing. Needs Automation access for SwiftBar -> Spotify the first time
# (System Settings > Privacy & Security > Automation); until then osascript
# returns nothing and this stays quiet rather than showing an error.
set -eu

running="$(osascript -e 'application "Spotify" is running' 2>/dev/null || echo false)"
[ "$running" = "true" ] || exit 0

state="$(osascript -e 'tell application "Spotify" to player state as string' 2>/dev/null || true)"
[ -n "$state" ] || exit 0

track="$(osascript -e 'tell application "Spotify" to name of current track' 2>/dev/null || true)"
artist="$(osascript -e 'tell application "Spotify" to artist of current track' 2>/dev/null || true)"
[ -n "$track" ] || exit 0

icon="▶"; [ "$state" = "playing" ] || icon="❚❚"
echo "$icon $artist — $track | length=45"
echo "---"
echo "$track"
echo "$artist"
echo "---"
echo "Play/Pause | bash=/usr/bin/osascript param1=-e param2='tell application \"Spotify\" to playpause' terminal=false refresh=true"
echo "Next | bash=/usr/bin/osascript param1=-e param2='tell application \"Spotify\" to next track' terminal=false refresh=true"
echo "Previous | bash=/usr/bin/osascript param1=-e param2='tell application \"Spotify\" to previous track' terminal=false refresh=true"
