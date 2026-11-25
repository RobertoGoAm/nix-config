# The forge side

# The tab asks =mr-review= (=mr-review.sh=) for everything and gets one JSON
# answer per call, so the mod holds no GitLab knowledge and the helper can be
# tried from a terminal: =mr-review list .= in a checkout. =glab= does the
# talking, with the host and project of the folder's =origin=:

# - =list= is one GraphQL query for every open merge request with its
#   reviewers, approvals, pipeline, thread counts and diff size, where the REST
#   list would need a request per merge request for half of those.
# - =show= makes its five requests (the merge request, its diffs, discussions,
#   drafts and approvals) at once and waits for the slowest.
# - =comment=, =reply=, =undraft=, =resolve=, =approve=, =unapprove= and
#   =submit= each make one change.

# A comment on several lines carries GitLab's =line_range=, whose ends are
# named by line codes: the SHA-1 of the file's path and the old and new line
# counters at that line, both of them even on a line only one side has. The
# mod keeps those counters on every row it draws for that.

# =show= also colours the code. Each file's old side (its context and removed
# lines) and new side (context and added lines) go through =bat= as two files
# of their own, hunks run together, with bat's =ansi= theme: the sixteen
# terminal colours, which the tab paints in Herdr's theme, so the diff takes
# the same colours as the terminals beside it. PHP is named outright, as a
# hunk rarely has the =<?php= bat would switch PHP on from. A file too large
# or generated, or one bat fails on, is drawn plain.

# A repository on GitHub goes to =mr-review-github= (=mr-review-github.sh=),
# which answers the same calls in the same shapes, so the tab knows one helper.
# GitLab's draft notes are GitHub's pending review there: one per pull request
# and person, seen only by them until it is submitted. A comment on lines is a
# thread of that review, a reply a pending reply in a thread, and a comment on
# the whole pull request goes into the review's own body. =S= submits it as a
# comment; =a= submits it as an approval, drafts and all, since GitHub keeps one
# review in the making. Pull requests a GitHub App opens in a repository of mine
# (an agent's) count as waiting for my review. The colouring both use is
# =mr-review-lib.sh=, put before each script, with the progress below.

# Progress is the helper's too, so every screen that reviews a request shares
# it: the files marked read, each with the digest of its diff, and the place,
# as the last screen left it. =state=, =read= and =pos= keep them in
# =~/.local/state/mr-review/<origin>/<number>.json=, and =show= hands them back
# with the request. The MRs tab and the phone's page (=mr-review-web.org=) both
# read and write them there.

# Errexit stays off: =show='s requests run in the background and each records
# its own exit code, which errexit would end before it was written.

{ pkgs, ... }:
let
  shared = builtins.readFile ./mr-review-lib.sh;
  tools = [
    pkgs.bat
    pkgs.coreutils
    pkgs.gawk
    pkgs.git
    pkgs.gnused
    pkgs.jq
  ];
  options = [
    "nounset"
    "pipefail"
  ];
  mrReviewGithub = pkgs.writeShellApplication {
    name = "mr-review-github";
    runtimeInputs = tools ++ [ pkgs.gh ];
    bashOptions = options;
    text = shared + builtins.readFile ./mr-review-github.sh;
  };
  mrReview = pkgs.writeShellApplication {
    name = "mr-review";
    runtimeInputs = tools ++ [
      pkgs.glab
      mrReviewGithub
    ];
    bashOptions = options;
    text = shared + builtins.readFile ./mr-review.sh;
  };
in
{
  home.packages = [ mrReview ];

  home.file.".config/herdr-app/mods/mrs" = {
    source = ./herdr-app/mrs;
    recursive = true;
  };
}
