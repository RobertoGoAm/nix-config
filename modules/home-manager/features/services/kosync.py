"""A kosync server: reading position, shared between everything that reads.

KOReader's sync protocol is five endpoints and one row per book, so this is
the whole thing rather than a wrapper around something bigger. The official
server is Lua on OpenResty with Redis behind it; nixpkgs packages neither it
nor any of the reimplementations, and standing up two daemons to store one
integer per book was the wrong trade.

Endpoints, exactly as KOReader's kosync plugin calls them:

    POST /users/create          {username, password}   password is already MD5
    GET  /users/auth            x-auth-user, x-auth-key headers
    PUT  /syncs/progress        {document, progress, percentage, device,
                                 device_id}
    GET  /syncs/progress/<doc>  the same fields back
    GET  /healthcheck

`document` is not a filename -- it is how KOReader identifies a book across
devices, and it is either the MD5 of the filename or a partial MD5 of the
file's contents depending on the "Document matching method" setting. The
server never needs to know which: it is an opaque key, and two readers agree
only if they are set the same way. That setting is the usual reason sync
appears to work and syncs nothing.

Credentials: the client MD5s the password before sending, and then replays
that same digest as x-auth-key on every request -- so the digest, not the
password, is the credential. It is stored here as a salted SHA-256 so a
copy of the database is not directly replayable.
"""

import hashlib
import json
import os
import secrets
import sqlite3
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DB_PATH = os.environ.get("KOSYNC_DB", os.path.expanduser("~/.local/share/kosync/kosync.db"))
HOST = os.environ.get("KOSYNC_HOST", "0.0.0.0")
PORT = int(os.environ.get("KOSYNC_PORT", "8081"))
# Registration is a POST any client on the tailnet can make. It has to be open
# to create the first account, and there is no reason to leave it open after.
ALLOW_REGISTER = os.environ.get("KOSYNC_ALLOW_REGISTER", "1") == "1"

_lock = threading.Lock()


def connect():
    db = sqlite3.connect(DB_PATH, check_same_thread=False)
    db.execute("PRAGMA journal_mode=WAL")
    db.executescript(
        """
        CREATE TABLE IF NOT EXISTS users (
            username TEXT PRIMARY KEY,
            salt     TEXT NOT NULL,
            key_hash TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS progress (
            username   TEXT NOT NULL,
            document   TEXT NOT NULL,
            progress   TEXT NOT NULL,
            percentage REAL NOT NULL,
            device     TEXT,
            device_id  TEXT,
            timestamp  INTEGER NOT NULL,
            PRIMARY KEY (username, document)
        );
        """
    )
    db.commit()
    return db


def hash_key(key, salt):
    return hashlib.sha256((salt + key).encode("utf-8")).hexdigest()


class Handler(BaseHTTPRequestHandler):
    server_version = "kosync/1.0"
    protocol_version = "HTTP/1.1"

    # ---- plumbing --------------------------------------------------------

    def log_message(self, fmt, *args):
        """One line per request, without the client address.

        BaseHTTPRequestHandler's default resolves the peer and prints it; on a
        tailnet that is a second name for a machine already identified by the
        username, and it goes to a log file nobody rotates.
        """
        sys.stderr.write("%s %s\n" % (self.command, self.path))

    def reply(self, status, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        # KOReader sends and expects its own vendor type; it accepts
        # application/json back, and so does everything else.
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def body(self):
        length = int(self.headers.get("Content-Length") or 0)
        if not length:
            return {}
        try:
            return json.loads(self.rfile.read(length).decode("utf-8"))
        except ValueError:
            return {}

    def authenticate(self):
        """Return the username, or None having already sent the 401."""
        username = self.headers.get("x-auth-user")
        key = self.headers.get("x-auth-key")
        if not username or not key:
            self.reply(401, {"message": "Unauthorized"})
            return None
        with _lock:
            row = self.server.db.execute(
                "SELECT salt, key_hash FROM users WHERE username = ?", (username,)
            ).fetchone()
        # compare_digest on both branches: returning early for an unknown user
        # makes "no such account" measurably faster than "wrong password", which
        # is how a username list gets enumerated.
        salt, expected = row if row else ("", "0" * 64)
        if not secrets.compare_digest(hash_key(key, salt), expected):
            self.reply(401, {"message": "Unauthorized"})
            return None
        return username

    # ---- endpoints -------------------------------------------------------

    def do_GET(self):
        if self.path == "/healthcheck":
            return self.reply(200, {"state": "OK"})

        if self.path == "/users/auth":
            if self.authenticate():
                self.reply(200, {"authorized": "OK"})
            return

        if self.path.startswith("/syncs/progress/"):
            username = self.authenticate()
            if not username:
                return
            document = self.path[len("/syncs/progress/"):]
            with _lock:
                row = self.server.db.execute(
                    "SELECT progress, percentage, device, device_id, timestamp"
                    " FROM progress WHERE username = ? AND document = ?",
                    (username, document),
                ).fetchone()
            if not row:
                # An empty object, not a 404: KOReader treats a 404 as the
                # server being broken and stops trying, where {} correctly
                # means "nobody has read this yet".
                return self.reply(200, {})
            return self.reply(200, {
                "username": username,
                "document": document,
                "progress": row[0],
                "percentage": row[1],
                "device": row[2],
                "device_id": row[3],
                "timestamp": row[4],
            })

        self.reply(404, {"message": "Not found"})

    def do_POST(self):
        if self.path != "/users/create":
            return self.reply(404, {"message": "Not found"})
        if not ALLOW_REGISTER:
            return self.reply(403, {"message": "Registration is closed"})

        payload = self.body()
        username = (payload.get("username") or "").strip()
        key = payload.get("password") or ""
        if not username or not key:
            return self.reply(400, {"message": "Missing username or password"})

        salt = secrets.token_hex(16)
        with _lock:
            existing = self.server.db.execute(
                "SELECT 1 FROM users WHERE username = ?", (username,)
            ).fetchone()
            if existing:
                # 402 is what KOReader looks for to say "already registered";
                # a 409 shows up in the app as an unexplained failure.
                return self.reply(402, {"message": "Username is already registered."})
            self.server.db.execute(
                "INSERT INTO users (username, salt, key_hash) VALUES (?, ?, ?)",
                (username, salt, hash_key(key, salt)),
            )
            self.server.db.commit()
        self.reply(201, {"username": username})

    def do_PUT(self):
        if self.path != "/syncs/progress":
            return self.reply(404, {"message": "Not found"})
        username = self.authenticate()
        if not username:
            return

        payload = self.body()
        document = payload.get("document")
        if not document:
            return self.reply(400, {"message": "Missing document"})
        now = int(time.time())
        with _lock:
            self.server.db.execute(
                "INSERT INTO progress"
                " (username, document, progress, percentage, device, device_id, timestamp)"
                " VALUES (?, ?, ?, ?, ?, ?, ?)"
                " ON CONFLICT(username, document) DO UPDATE SET"
                " progress = excluded.progress, percentage = excluded.percentage,"
                " device = excluded.device, device_id = excluded.device_id,"
                " timestamp = excluded.timestamp",
                (username, document, str(payload.get("progress", "")),
                 float(payload.get("percentage") or 0), payload.get("device"),
                 payload.get("device_id"), now),
            )
            self.server.db.commit()
        self.reply(200, {"document": document, "timestamp": now})


def main():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    server.db = connect()
    sys.stderr.write("kosync listening on %s:%d\n" % (HOST, PORT))
    server.serve_forever()


if __name__ == "__main__":
    main()
