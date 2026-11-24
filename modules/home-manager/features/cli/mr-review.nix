# The GitLab side

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

# Errexit stays off: =show='s requests run in the background and each records
# its own exit code, which errexit would end before it was written.

{ pkgs, ... }:
let
  mrReview = pkgs.writeShellApplication {
    name = "mr-review";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.git
      pkgs.glab
      pkgs.gnused
      pkgs.jq
    ];
    bashOptions = [
      "nounset"
      "pipefail"
    ];
    text = builtins.readFile ./mr-review.sh;
  };
in
{
  home.packages = [ mrReview ];

  home.file.".config/herdr-app/mods/mrs" = {
    source = ./herdr-app/mrs;
    recursive = true;
  };
}
