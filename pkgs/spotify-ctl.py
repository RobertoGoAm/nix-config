"""Minimal Spotify Web API client: now-playing and transport control.

Exists so the menu bar keeps working without the desktop app. The AppleScript
it replaces could only ever talk to a running Spotify.app; this talks to
whatever Connect device is active, which is normally the headless librespot
agent.

Credentials come from sops at /var/run/secrets:

  spotify_client_id, spotify_client_secret   the registered application
  spotify_refresh_token                      from `spotify-ctl auth', once

Access tokens are minted from the refresh token and cached in TMPDIR until
they expire, so a 30-second menu-bar refresh costs one cached read rather
than a round trip to Spotify's token endpoint.

Every failure path prints nothing and exits 0. A status bar is not the place
to surface a stack trace, and a silent section reads as "not playing", which
is the truth often enough.
"""

import base64
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

SECRETS = "/var/run/secrets"
CACHE = os.path.join(os.environ.get("TMPDIR", "/tmp"), "spotify-ctl-token.json")
API = "https://api.spotify.com/v1"
REDIRECT = "http://127.0.0.1:8080/smudge-api-callback"
SCOPES = "user-read-playback-state user-modify-playback-state"


def secret(name):
    """Read a sops secret, falling back to the environment.

    The environment fallback exists for `auth', which runs before the
    credentials are in sops -- you cannot obtain the refresh token to store
    without the client id, and you cannot get the client id out of sops until
    a rebuild has installed it. Reading SPOTIFY_CLIENT_ID and
    SPOTIFY_CLIENT_SECRET from the environment collapses that into one pass.
    """
    try:
        with open(os.path.join(SECRETS, name)) as fh:
            return fh.read().strip()
    except OSError:
        return os.environ.get(name.upper()) or None


def _post_token(data):
    cid, sec = secret("spotify_client_id"), secret("spotify_client_secret")
    if not cid or not sec:
        return None
    auth = base64.b64encode(f"{cid}:{sec}".encode()).decode()
    req = urllib.request.Request(
        "https://accounts.spotify.com/api/token",
        data=urllib.parse.urlencode(data).encode(),
        headers={"Authorization": f"Basic {auth}",
                 "Content-Type": "application/x-www-form-urlencoded"},
    )
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.load(r)


def access_token():
    try:
        with open(CACHE) as fh:
            tok = json.load(fh)
        if tok.get("expires_at", 0) > time.time() + 30:
            return tok["access_token"]
    except (OSError, ValueError, KeyError):
        pass
    rt = secret("spotify_refresh_token")
    if not rt:
        return None
    body = _post_token({"grant_type": "refresh_token", "refresh_token": rt})
    if not body:
        return None
    body["expires_at"] = time.time() + body.get("expires_in", 3600)
    try:
        with open(CACHE, "w") as fh:
            os.chmod(CACHE, 0o600)
            json.dump(body, fh)
    except OSError:
        pass
    return body.get("access_token")


def call(method, path, token):
    req = urllib.request.Request(API + path, method=method,
                                 headers={"Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        # 204 is "nothing playing"; 403/404 is "no active device".
        if e.code in (204, 403, 404):
            return {}
        raise


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "now"

    if cmd == "auth":
        cid = secret("spotify_client_id")
        if not cid:
            print("No spotify_client_id yet. Before it is in sops, pass the pair"
                  " from developer.spotify.com in the environment:\n\n"
                  "  SPOTIFY_CLIENT_ID=... SPOTIFY_CLIENT_SECRET=... spotify-ctl auth\n",
                  file=sys.stderr)
            return 1
        q = urllib.parse.urlencode({"client_id": cid, "response_type": "code",
                                    "redirect_uri": REDIRECT, "scope": SCOPES})
        print("Open this, approve, then paste the ?code= value back here:\n")
        print(f"https://accounts.spotify.com/authorize?{q}\n")
        code = input("code: ").strip()
        body = _post_token({"grant_type": "authorization_code", "code": code,
                            "redirect_uri": REDIRECT})
        if not body or "refresh_token" not in body:
            print("no refresh token returned", file=sys.stderr)
            return 1
        print("\nAdd this to secrets.yaml as spotify_refresh_token:\n")
        print(body["refresh_token"])
        return 0

    token = access_token()
    if not token:
        return 0

    try:
        if cmd == "now":
            d = call("GET", "/me/player/currently-playing", token)
            item = (d or {}).get("item") or {}
            name = item.get("name")
            artists = ", ".join(a["name"] for a in item.get("artists", []))
            if name:
                state = "▶" if (d or {}).get("is_playing") else "❚❚"
                print(f"{state}\t{artists}\t{name}")
        elif cmd == "playpause":
            d = call("GET", "/me/player", token) or {}
            call("PUT", "/me/player/pause" if d.get("is_playing") else "/me/player/play", token)
        elif cmd == "next":
            call("POST", "/me/player/next", token)
        elif cmd == "previous":
            call("POST", "/me/player/previous", token)
    except Exception:
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
