"""mr-review-web: the phone's page for reviewing merge and pull requests.

Serves the page (index.html beside this file) and a small API over mr-review,
the same helper Herdr's MRs tab calls, so drafts, read marks and the place in
a request are the same on both screens. It listens on localhost only; Tailscale
serve puts it on the tailnet, and the identity headers Tailscale adds are
checked against the tailnet's owner of this machine.

    GET  /api/repos                 the repositories with an open Herdr terminal
    GET  /api/list?dir=DIR          mr-review list
    GET  /api/show?dir=DIR&iid=N    mr-review show
    POST /api/do {dir, args}        one of mr-review's changes
"""

import http.server
import json
import os
import subprocess
import sys
import threading
import time
import urllib.parse

PORT = int(os.environ.get("MR_REVIEW_WEB_PORT", "8787"))
HELPER = os.environ.get("MR_REVIEW", "mr-review")
STATIC = os.environ.get("MR_REVIEW_WEB_STATIC", os.path.dirname(os.path.abspath(__file__)))
EXTRA = os.path.expanduser("~/.config/mr-review/repos")

# The changes the page may ask for, and nothing else: the API never runs
# arbitrary commands, only these subcommands of the helper.
CHANGES = {"comment", "reply", "undraft", "resolve", "approve", "unapprove", "submit", "read", "pos"}

STATIC_FILES = {
    "/": ("index.html", "text/html; charset=utf-8"),
    "/index.html": ("index.html", "text/html; charset=utf-8"),
    "/manifest.json": ("manifest.json", "application/manifest+json"),
    "/icon.png": ("icon.png", "image/png"),
}


def run(args, timeout=60):
    try:
        out = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as e:
        return 1, "", str(e)
    return out.returncode, out.stdout, out.stderr


def owner_login():
    """The tailnet login that owns this machine: the only one let in."""
    for binary in ("tailscale", "/Applications/Tailscale.app/Contents/MacOS/Tailscale"):
        code, out, _ = run([binary, "status", "--json"], timeout=10)
        if code == 0:
            try:
                status = json.loads(out)
                user = status["User"][str(status["Self"]["UserID"])]
                return user["LoginName"]
            except (KeyError, ValueError):
                return None
    return None


OWNER = owner_login()


class Repos:
    """Checkouts here that Herdr terminals work in, plus any listed by hand.

    A terminal on another machine counts when the same path is a checkout on
    this one, as the MRs tab does for a space on vulcan.
    """

    def __init__(self):
        self.lock = threading.Lock()
        self.at = 0.0
        self.found = []

    def get(self):
        with self.lock:
            if time.time() - self.at > 60 or not self.found:
                self.found = self.scan()
                self.at = time.time()
            return self.found

    def scan(self):
        folders = []
        code, out, _ = run(["hc", "ls", "--json"], timeout=15)
        if code == 0:
            try:
                for t in json.loads(out).get("terminals", []):
                    if t.get("cwd"):
                        folders.append(t["cwd"])
            except ValueError:
                pass
        try:
            with open(EXTRA, encoding="utf-8") as fh:
                folders += [os.path.expanduser(line.strip()) for line in fh if line.strip() and not line.startswith("#")]
        except OSError:
            pass
        roots = {}
        for folder in dict.fromkeys(folders):
            if not os.path.isdir(folder):
                continue
            code, top, _ = run(["git", "-C", folder, "rev-parse", "--show-toplevel"], timeout=5)
            if code != 0:
                continue
            top = top.strip()
            if top in roots:
                continue
            code, origin, _ = run(["git", "-C", top, "remote", "get-url", "origin"], timeout=5)
            if code == 0:
                roots[top] = {"dir": top, "name": os.path.basename(top), "origin": origin.strip()}
        return sorted(roots.values(), key=lambda r: r["name"].lower())


REPOS = Repos()


class Handler(http.server.BaseHTTPRequestHandler):
    server_version = "mr-review-web"

    def log_message(self, fmt, *args):
        sys.stderr.write("%s %s\n" % (self.log_date_time_string(), fmt % args))

    def allowed(self):
        login = self.headers.get("Tailscale-User-Login")
        if login is None:
            # Not through Tailscale serve: only this machine reaches the port.
            return True
        return OWNER is None or login == OWNER

    def send(self, code, body, kind="application/json"):
        data = body.encode("utf-8") if isinstance(body, str) else body
        self.send_response(code)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def error(self, code, message):
        self.send(code, json.dumps({"error": message}))

    def repo(self, folder):
        dirs = {r["dir"] for r in REPOS.get()}
        return folder if folder in dirs else None

    def helper(self, args):
        code, out, err = run([HELPER] + args, timeout=120)
        if out.strip().startswith(("{", "[")):
            self.send(200 if code == 0 else 502, out)
        else:
            self.error(502, (err or out or "mr-review failed").strip()[-400:])

    def do_GET(self):
        if not self.allowed():
            return self.error(403, "not yours")
        url = urllib.parse.urlparse(self.path)
        query = urllib.parse.parse_qs(url.query)
        if url.path in STATIC_FILES:
            name, kind = STATIC_FILES[url.path]
            try:
                with open(os.path.join(STATIC, name), "rb") as fh:
                    return self.send(200, fh.read(), kind)
            except OSError:
                return self.error(404, "missing " + name)
        if url.path == "/api/repos":
            return self.send(200, json.dumps({"repos": REPOS.get()}))
        folder = self.repo(query.get("dir", [""])[0])
        if url.path in ("/api/list", "/api/show") and not folder:
            return self.error(404, "unknown repository")
        if url.path == "/api/list":
            return self.helper(["list", folder])
        if url.path == "/api/show":
            iid = query.get("iid", [""])[0]
            if not iid.isdigit():
                return self.error(400, "bad request number")
            return self.helper(["show", folder, iid])
        return self.error(404, "not found")

    def do_POST(self):
        if not self.allowed():
            return self.error(403, "not yours")
        if urllib.parse.urlparse(self.path).path != "/api/do":
            return self.error(404, "not found")
        try:
            length = int(self.headers.get("Content-Length", "0"))
            body = json.loads(self.rfile.read(min(length, 1_000_000)) or b"{}")
        except ValueError:
            return self.error(400, "bad json")
        folder = self.repo(body.get("dir", ""))
        args = body.get("args")
        if not folder:
            return self.error(404, "unknown repository")
        if not isinstance(args, list) or not args or args[0] not in CHANGES or not all(isinstance(a, str) for a in args):
            return self.error(400, "not a change the page may make")
        return self.helper([args[0], folder] + args[1:])


def main():
    server = http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    sys.stderr.write("mr-review-web on 127.0.0.1:%d, owner %s\n" % (PORT, OWNER or "unknown"))
    server.serve_forever()


if __name__ == "__main__":
    main()
