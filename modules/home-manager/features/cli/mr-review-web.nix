# Reviewing merge requests from the phone

# Herdr's app on the phone shows terminals only, and tuicr there is keyboard
# work on a narrow screen. This is a page for the phone instead, kept on its
# home screen: the open merge and pull requests of every repository a Herdr
# terminal works in, and a request one file at a time, coloured as in the MRs
# tab (=mr-review.org=), with a tap on a line (or a tap on another to make a
# range) to comment, and the file marked read with the button at the bottom,
# which goes on to the next unread one. Threads sit under their lines with
# Reply and Resolve; the request's own page has Publish, Approve, a comment on
# the whole request and "Continue in <file>", where I left off on either screen.

# It is a front for =mr-review= and nothing else, so the drafts are GitLab's
# draft notes or GitHub's pending review, and the read marks and the place are
# =mr-review='s progress: a comment begun on the phone is in the MRs tab, and a
# file marked read in Herdr is read here.

{
  config,
  lib,
  pkgs,
  ...
}:
let
  port = 8787;
  server = pkgs.writeShellApplication {
    name = "mr-review-web";
    runtimeInputs = [
      pkgs.git
      pkgs.python3
    ];
    text = ''exec python3 ${./mr-review-web/server.py} "$@"'';
  };
in

# Served by prometheus, to the tailnet only

# The work GitLab's login stays on the work laptop, so the page is served from
# here: it answers while prometheus is awake and on the tailnet. The server
# (=mr-review-web/server.py=, the standard library only) listens on
# localhost, and Tailscale serve puts it on this machine's tailnet name over
# HTTPS, so nothing is public and there is no certificate to look after. Each
# request through Tailscale names who sent it, and the server lets in only the
# tailnet login that owns this machine. It runs only the helper's own reads and
# changes, and only for the repositories it found: those Herdr's terminals work
# in (=hc ls=; a terminal on vulcan counts when the same path is a checkout
# here), and any listed one per line in =~/.config/mr-review/repos=.

# A launchd agent keeps it running, with the profile's =mr-review= and =hc= on
# its PATH. The serve setting lives in Tailscale and lasts across restarts, so
# activation only adds it when it is missing; where Tailscale is not running,
# or HTTPS certificates are off for the tailnet, it says so and leaves it.

lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  home.packages = [ server ];

  launchd.agents.mr-review-web = {
    enable = true;
    config = {
      ProgramArguments = [ "${server}/bin/mr-review-web" ];
      EnvironmentVariables = {
        MR_REVIEW_WEB_PORT = toString port;
        MR_REVIEW_WEB_STATIC = "${./mr-review-web}";
        PATH = "${config.home.profileDirectory}/bin:${config.home.homeDirectory}/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin";
      };
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Background";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/mr-review-web.log";
    };
  };

  home.activation.mrReviewWebServe = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ts=""
    for t in /usr/local/bin/tailscale /Applications/Tailscale.app/Contents/MacOS/Tailscale; do
      [ -x "$t" ] && { ts="$t"; break; }
    done
    if [ -z "$ts" ]; then
      warnEcho "mr-review-web: no tailscale CLI, so the phone page is not served"
    elif ! "$ts" serve status --json 2>/dev/null | grep -qF "127.0.0.1:${toString port}"; then
      run "$ts" serve --bg --https=443 "http://127.0.0.1:${toString port}" \
        || warnEcho "mr-review-web: tailscale serve failed (is HTTPS on for the tailnet?)"
    fi
  '';
}
