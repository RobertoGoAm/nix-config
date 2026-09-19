"""What the next `nix-update` would cost, worked out before you run it.

`nix-update` bumps every flake input and rebuilds. Most days that is a few
hundred substituted paths and a two minute activation. Some days an input
moves onto a package the binary cache has not built for this platform yet,
and the same command turns into a forty minute compile with no warning --
or onto one that does not evaluate at all, and fails after the lock file has
already been rewritten.

This answers both questions ahead of time, on a schedule, so the menu bar can
say whether now is a good moment:

  * clone HEAD into a throwaway git worktree, so nothing here is touched
  * update the flake inputs *there*
  * ask nix what that plan would build locally versus fetch
  * write the verdict as JSON

Reading HEAD rather than the working tree is deliberate: uncommitted edits are
usually half-finished and would report costs that no `nix-update` will ever
pay. What is committed is what the command will actually build.

The verdict is advisory. "heavy" does not mean broken, it means the update is
better started before lunch than before a meeting.
"""

import argparse
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import time

# Packages whose source build is measured in tens of minutes on an M-series
# laptop. Anything not named here is counted, not weighed -- the full build
# list goes into the report either way.
HEAVY = (
    "nodejs",
    "chromium",
    "electron",
    "webkit",
    "llvm",
    "clang",
    "rustc",
    "ghc",
    "texlive",
    "qtbase",
    "qtwebengine",
    "openjdk",
    "gcc",
    "boost",
    "ffmpeg",
    "mesa",
    "swift",
    "sbcl",
    "firefox",
    "thunderbird",
    "libreoffice",
    "blender",
    "opencv",
    "torch",
    "tensorflow",
    "spidermonkey",
)

# Past this many local builds the update is worth scheduling even when none of
# them is individually famous for being slow: a hundred small compiles is still
# an hour of fans.
MANY_BUILDS = 60


def is_heavy(name):
    """Does this derivation name a long build?

    Anchored at the start of the name rather than matched anywhere inside it.
    A substring rule reads `hm-firefox-extensions` -- a link farm that finishes
    instantly -- as a Firefox build, and then every report says the update is
    expensive. The cost of anchoring is missing a heavy package that appears
    under a prefix, `python3.13-torch` say; a false "clear" that turns into a
    long build is a worse surprise than a false alarm, but a permanent false
    alarm is the one that gets the whole indicator ignored.
    """
    low = name.lower()
    if "wrapper" in low or "hook" in low:
        return False
    return any(low == h or low.startswith(h + "-") or low.startswith(h + "_") for h in HEAVY)


def run(cmd, cwd=None, timeout=1800):
    return subprocess.run(
        cmd,
        cwd=cwd,
        timeout=timeout,
        capture_output=True,
        text=True,
    )


def drv_name(path):
    """/nix/store/<hash>-foo-1.2.drv -> foo-1.2"""
    base = os.path.basename(path)
    base = base[:-4] if base.endswith(".drv") else base
    return base.split("-", 1)[1] if "-" in base else base


def parse_plan(text):
    """Pull the build and fetch sections out of `nix build --dry-run` output.

    Nix writes these to stderr as prose, and switches to the singular for a
    single item ("this derivation will be built:"), which is what the two
    alternations below are for. There is no --json for a dry run, so the prose
    is the interface.
    """
    builds, download_mb = [], 0.0
    section = None
    for line in text.splitlines():
        stripped = line.strip()
        if re.match(r"^(these \d+ derivations|this derivation) will be built:", stripped):
            section = "build"
            continue
        m = re.match(
            r"^(?:these \d+ paths|this path) will be fetched \(([\d.]+) MiB download",
            stripped,
        )
        if m:
            section = "fetch"
            download_mb = float(m.group(1))
            continue
        if stripped.startswith("/nix/store/"):
            if section == "build":
                builds.append(drv_name(stripped))
            continue
        # Any other non-indented prose ends the list it followed.
        if stripped and not line.startswith(" "):
            section = None
    return builds, download_mb


def parse_updated_inputs(text):
    """`nix flake update` names each moved input as "• Updated input 'x':"."""
    return sorted(set(re.findall(r"Updated input '([^']+)'", text)))


def error_summary(text):
    """The last error nix printed, without the stack trace above it."""
    lines = [l.rstrip() for l in text.splitlines() if l.strip()]
    errors = [l for l in lines if l.strip().startswith("error:")]
    if errors:
        return errors[-1].strip()[len("error:"):].strip() or errors[-1].strip()
    return lines[-1].strip() if lines else "nix failed without a message"


def default_host():
    return socket.gethostname().split(".")[0].lower()


def preflight(repo, host, timeout):
    started = time.time()
    report = {
        "checked": int(started),
        "host": host,
        "updated": [],
        "build_count": 0,
        "builds": [],
        "heavy": [],
        "download_mb": 0.0,
        "verdict": "broken",
        "error": None,
        "duration_s": 0,
    }

    tmp = tempfile.mkdtemp(prefix="nix-preflight.")
    tree = os.path.join(tmp, "tree")
    try:
        # --detach, so this never moves a branch, and HEAD rather than a named
        # branch so it works the same on a detached checkout.
        add = run(["git", "-C", repo, "worktree", "add", "--detach", tree, "HEAD"])
        if add.returncode != 0:
            report["error"] = error_summary(add.stderr or add.stdout)
            return report

        upd = run(["nix", "flake", "update"], cwd=tree, timeout=timeout)
        if upd.returncode != 0:
            report["error"] = error_summary(upd.stderr or upd.stdout)
            return report
        report["updated"] = parse_updated_inputs(upd.stderr)

        attr = f".#darwinConfigurations.{host}.system"
        dry = run(["nix", "build", "--dry-run", attr], cwd=tree, timeout=timeout)
        if dry.returncode != 0:
            report["error"] = error_summary(dry.stderr or dry.stdout)
            return report

        builds, download_mb = parse_plan(dry.stderr)
        heavy = sorted({b for b in builds if is_heavy(b)})

        report["build_count"] = len(builds)
        report["builds"] = sorted(builds)
        report["heavy"] = heavy
        report["download_mb"] = download_mb
        report["error"] = None
        report["verdict"] = (
            "heavy" if heavy else "big" if len(builds) > MANY_BUILDS else "clear"
        )
        return report
    except subprocess.TimeoutExpired:
        report["error"] = f"timed out after {timeout}s"
        return report
    finally:
        report["duration_s"] = int(time.time() - started)
        # Remove the worktree through git, not rm -rf: the administrative entry
        # under .git/worktrees outlives the directory and `git worktree add`
        # refuses the same path afterwards.
        run(["git", "-C", repo, "worktree", "remove", "--force", tree])
        shutil.rmtree(tmp, ignore_errors=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--repo", default=os.path.expanduser("~/nix-config"))
    ap.add_argument("--host", default=default_host())
    ap.add_argument("--out", help="write the report here instead of stdout")
    ap.add_argument("--timeout", type=int, default=1800)
    args = ap.parse_args()

    report = preflight(args.repo, args.host, args.timeout)
    blob = json.dumps(report, indent=2) + "\n"

    if not args.out:
        sys.stdout.write(blob)
        return 0

    # Written through a temp file in the same directory: the menu bar reads this
    # every 30 seconds and must never catch a half-written file.
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    tmp = f"{args.out}.{os.getpid()}.tmp"
    with open(tmp, "w") as fh:
        fh.write(blob)
    os.replace(tmp, args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
