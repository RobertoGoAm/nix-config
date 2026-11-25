# mr-review-github: mr-review for a repository on GitHub, called by mr-review
# with the same arguments and answering in the same shapes, so Herdr's MRs tab
# reviews pull requests as it does merge requests.
#
# GitLab's draft notes are GitHub's pending review: one per pull request and
# person, which only they see until it is submitted. A comment on lines is a
# thread of the pending review, a reply is a pending reply in a thread, and a
# comment on the whole pull request goes into the pending review's own body.
# submit submits it as a comment; approve submits it as an approval, drafts and
# all, as GitHub keeps only one review in the making.

fail() {
  jq -nc --arg e "$1" '{error: $e}'
  echo "mr-review: $1" >&2
  exit 1
}

cmd=${1:-}
shift || true
cd "${1:?DIR}" 2>/dev/null || fail "no folder $1"
url=$(git remote get-url origin 2>/dev/null) || fail "no origin remote"
repo=$(printf '%s' "$url" | sed -E 's#^[a-z+]+://[^/]+/##; s#^[^@]+@[^:]+:##; s#\.git$##')
owner=${repo%%/*}
name=${repo#*/}

err=$(mktemp)
trap 'rm -f "$err"' EXIT

# A GraphQL request whose answer lands in $out, or the script fails with the
# first error GitHub gives.
ql() {
  out=$(gh api graphql "$@" 2>"$err") || fail "$(head -c 300 "$err")"
  if jq -e '.errors' <<<"$out" >/dev/null; then fail "$(jq -r '.errors[0].message' <<<"$out")"; fi
}

rest() {
  out=$(gh api "$@" 2>"$err") || fail "$(head -c 300 "$err")"
}

# GitHub's check rollup in GitLab's pipeline words, which the tab draws.
# shellcheck disable=SC2016 # jq, not shell
CI='def ci: (. // "none") | ascii_downcase | if . == "failure" or . == "error" then "failed" elif . == "pending" or . == "expected" then "running" else . end;'

# The pull request's node id and my pending review on it, if there is one.
pending() {
  # shellcheck disable=SC2016 # GraphQL variables
  ql -f query='query($o: String!, $n: String!, $num: Int!) { repository(owner: $o, name: $n) { pullRequest(number: $num) {
      id reviews(states: PENDING, first: 1) { nodes { id body } } } } }' -f o="$owner" -f n="$name" -F num="$1"
  pr=$(jq -r '.data.repository.pullRequest.id' <<<"$out")
  review=$(jq -r '.data.repository.pullRequest.reviews.nodes[0].id // empty' <<<"$out")
  review_body=$(jq -r '.data.repository.pullRequest.reviews.nodes[0].body // empty' <<<"$out")
}

# My pending review, started when there is none yet.
start_review() {
  pending "$1"
  if [ -z "$review" ]; then
    # shellcheck disable=SC2016
    ql -f query='mutation($pr: ID!) { addPullRequestReview(input: {pullRequestId: $pr}) { pullRequestReview { id } } }' -f pr="$pr"
    review=$(jq -r '.data.addPullRequestReview.pullRequestReview.id' <<<"$out")
  fi
}

# shellcheck disable=SC2016
LIST_QUERY='query($o: String!, $n: String!) {
  viewer { login }
  repository(owner: $o, name: $n) {
    nameWithOwner url owner { login }
    pullRequests(states: OPEN, first: 100, orderBy: {field: UPDATED_AT, direction: DESC}) {
      nodes {
        number title isDraft url headRefName baseRefName updatedAt createdAt
        author { __typename login ... on User { name } }
        reviewRequests(first: 20) { nodes { requestedReviewer { ... on User { login } } } }
        reviewDecision
        latestOpinionatedReviews(first: 20) { nodes { state author { login } } }
        commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
        reviewThreads(first: 100) { nodes { isResolved } }
        additions deletions changedFiles
      }
    }
  }
}'

# shellcheck disable=SC2016
SHOW_QUERY='query($o: String!, $n: String!, $num: Int!) {
  viewer { login }
  repository(owner: $o, name: $n) {
    pullRequest(number: $num) {
      reviewDecision
      commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
      latestOpinionatedReviews(first: 20) { nodes { id databaseId state author { login } } }
      reviews(last: 50) { nodes { id state body createdAt author { login } } }
      reviewThreads(first: 100) { nodes {
        id isResolved path line diffSide
        comments(first: 50) { nodes { id body createdAt state author { login } } }
      } }
    }
  }
}'

case "$cmd" in
list)
  ql -f query="$LIST_QUERY" -f o="$owner" -f n="$name"
  jq -c "$CI"'
    .data.viewer.login as $me | .data.repository as $r |
    {me: $me, forge: "github", project: $r.nameWithOwner, url: $r.url,
     mrs: [$r.pullRequests.nodes[] | {
       iid: .number, title, draft: .isDraft, url,
       source: .headRefName, target: .baseRefName,
       updated: .updatedAt, created: .createdAt,
       author: (.author.login // "ghost"), author_name: (.author.name // .author.login // "ghost"),
       mine: (.author.login == $me),
       review: (([.reviewRequests.nodes[].requestedReviewer.login] | index($me) != null)
                or (.author.__typename == "Bot" and $r.owner.login == $me)),
       approved: (.reviewDecision == "APPROVED"),
       approvals_left: (if .reviewDecision == "REVIEW_REQUIRED" then 1 else null end),
       approved_by_me: ([.latestOpinionatedReviews.nodes[] | select(.state == "APPROVED") | .author.login] | index($me) != null),
       pipeline: (.commits.nodes[0].commit.statusCheckRollup.state | ci),
       threads: (.reviewThreads.nodes | length),
       unresolved: ([.reviewThreads.nodes[] | select(.isResolved | not)] | length),
       add: .additions, del: .deletions, files: .changedFiles}]}' <<<"$out"
  ;;

show)
  num=${2:?NUMBER}
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp" "$err"' EXIT
  fetch() {
    name_=$1
    shift
    gh api "$@" >"$tmp/$name_" 2>"$tmp/$name_.err"
    echo $? >"$tmp/$name_.code"
  }
  fetch pr "repos/$owner/$name/pulls/$num" &
  fetch files --paginate "repos/$owner/$name/pulls/$num/files?per_page=100" &
  fetch comments --paginate "repos/$owner/$name/issues/$num/comments?per_page=100" &
  fetch graph graphql -f query="$SHOW_QUERY" -f o="$owner" -f n="$name" -F num="$num" &
  wait
  for f in pr files comments graph; do
    [ "$(cat "$tmp/$f.code")" = 0 ] || fail "$(head -c 300 "$tmp/$f.err")"
  done
  jq -n "$CI"'
    def at: {path, old_path: .path,
             old_line: (if .diffSide == "LEFT" then .line else null end),
             new_line: (if .diffSide == "RIGHT" then .line else null end)};
    $pr[0] as $p | $graph[0].data.viewer.login as $me | $graph[0].data.repository.pullRequest as $g |
    ([$g.reviews.nodes[] | select(.state == "PENDING")][0]) as $pending |
    {me: $me, forge: "github",
     mr: {iid: $p.number, title: $p.title, description: ($p.body // ""),
          author: $p.user.login, author_name: $p.user.login,
          source: $p.head.ref, target: $p.base.ref, url: $p.html_url,
          draft: $p.draft, state: $p.state, sha: $p.head.sha, refs: null,
          merge_status: $p.mergeable_state,
          pipeline: ($g.commits.nodes[0].commit.statusCheckRollup.state | ci),
          pipeline_url: ($p.html_url + "/checks"),
          approved: ($g.reviewDecision == "APPROVED"),
          approvals_left: (if $g.reviewDecision == "REVIEW_REQUIRED" then 1 else null end),
          approved_by: [$g.latestOpinionatedReviews.nodes[] | select(.state == "APPROVED") | .author.login],
          approved_by_me: ([$g.latestOpinionatedReviews.nodes[] | select(.state == "APPROVED") | .author.login] | index($me) != null),
          can_approve: ($p.user.login != $me)},
     files: [($files | add // [])[] | {
       old_path: (.previous_filename // .filename), new_path: .filename,
       status: (if .status == "added" then "A" elif .status == "removed" then "D" elif .status == "renamed" then "R" else "M" end),
       generated: false, too_large: (.patch == null and .changes > 0),
       diff: (.patch // "")}],
     threads: ([$g.reviewThreads.nodes[] | select(any(.comments.nodes[]; .state != "PENDING")) | {
         id, resolvable: true, resolved: .isResolved, at: at,
         notes: [.comments.nodes[] | select(.state != "PENDING") | {id, author: .author.login, body, created: .createdAt}]}]
       + ([($comments | add // [])[] | {id: "ic\(.id)", resolvable: false, resolved: false, at: null,
           notes: [{id: "ic\(.id)", author: .user.login, body, created: .created_at}]}]
          + [$g.reviews.nodes[] | select(.state != "PENDING" and (.body // "") != "") | {id, resolvable: false, resolved: false, at: null,
           notes: [{id, author: .author.login, body: (if .state == "APPROVED" then "Approved. " else "" end + .body), created: .createdAt}]}]
          | sort_by(.notes[0].created))),
     drafts: ([$g.reviewThreads.nodes[] | . as $t | .comments.nodes | to_entries[] | select(.value.state == "PENDING") | {
         id: .value.id, body: .value.body,
         reply_to: (if .key == 0 then null else $t.id end),
         at: (if .key == 0 then ($t | at) else null end)}]
       + (if $pending and ($pending.body // "") != "" then [{id: $pending.id, body: $pending.body, reply_to: null, at: null}] else [] end))}' \
    --slurpfile pr "$tmp/pr" --slurpfile files "$tmp/files" --slurpfile comments "$tmp/comments" --slurpfile graph "$tmp/graph" \
    >"$tmp/out"
  highlight "$tmp/out" "${num:-${iid:-}}"
  ;;

comment)
  num=${2:?NUMBER}
  body=${3:?BODY}
  if [ -n "${4:-}" ]; then
    start_review "$num"
    if [ -n "${8:-}" ]; then
      ends=$(jq -c '{line: (.end.new // .end.old), side: (if .end.new != null then "RIGHT" else "LEFT" end),
                     start: (.start.new // .start.old), start_side: (if .start.new != null then "RIGHT" else "LEFT" end)}' <<<"$8") \
        || fail "bad line range: $8"
    elif [ -n "${7:-}" ]; then
      ends=$(jq -nc --argjson l "$7" '{line: $l, side: "RIGHT"}')
    else
      ends=$(jq -nc --argjson l "${6:?OLD_LINE}" '{line: $l, side: "LEFT"}')
    fi
    line=$(jq -r '.line' <<<"$ends")
    side=$(jq -r '.side' <<<"$ends")
    range=()
    if [ "$(jq -r '.start // empty' <<<"$ends")" != "" ] && [ "$(jq -r '.start' <<<"$ends")" != "$line" ]; then
      range=(-F sl="$(jq -r '.start' <<<"$ends")" -f ss="$(jq -r '.start_side' <<<"$ends")")
    fi
    # shellcheck disable=SC2016
    ql -f query='mutation($r: ID!, $path: String!, $body: String!, $line: Int!, $side: DiffSide!, $sl: Int, $ss: DiffSide) {
        addPullRequestReviewThread(input: {pullRequestReviewId: $r, path: $path, body: $body, line: $line, side: $side, startLine: $sl, startSide: $ss}) {
          thread { comments(first: 1) { nodes { id } } } } }' \
      -f r="$review" -f path="$4" -f body="$body" -F line="$line" -f side="$side" "${range[@]}"
    jq -e '.data.addPullRequestReviewThread.thread' <<<"$out" >/dev/null \
      || fail "GitHub took no comment on line $line of $4: it only takes lines its diff shows"
    jq -c '{id: .data.addPullRequestReviewThread.thread.comments.nodes[0].id}' <<<"$out"
  else
    pending "$num"
    if [ -n "$review" ] && [ -z "$review_body" ]; then
      # GitHub cannot give a body to a review started without one: an empty
      # one is replaced, one holding line comments has to be published first.
      # shellcheck disable=SC2016
      ql -f query='query($r: ID!) { node(id: $r) { ... on PullRequestReview { comments(first: 1) { totalCount } } } }' -f r="$review"
      [ "$(jq -r '.data.node.comments.totalCount' <<<"$out")" = 0 ] \
        || fail "GitHub can't add a comment on the whole pull request to a review already holding line comments: publish them (S) first"
      # shellcheck disable=SC2016
      ql -f query='mutation($r: ID!) { deletePullRequestReview(input: {pullRequestReviewId: $r}) { pullRequestReview { id } } }' -f r="$review"
      review=""
    fi
    if [ -n "$review" ]; then
      # shellcheck disable=SC2016
      ql -f query='mutation($r: ID!, $body: String!) { updatePullRequestReview(input: {pullRequestReviewId: $r, body: $body}) { pullRequestReview { id } } }' \
        -f r="$review" -f body="$review_body"$'\n\n'"$body"
      jq -c '{id: .data.updatePullRequestReview.pullRequestReview.id}' <<<"$out"
    else
      # shellcheck disable=SC2016
      ql -f query='mutation($pr: ID!, $body: String!) { addPullRequestReview(input: {pullRequestId: $pr, body: $body}) { pullRequestReview { id } } }' \
        -f pr="$pr" -f body="$body"
      jq -c '{id: .data.addPullRequestReview.pullRequestReview.id}' <<<"$out"
    fi
  fi
  ;;

reply)
  num=${2:?NUMBER}
  case "${3:?THREAD}" in
  PRRT_*) ;;
  *) fail "GitHub takes replies only in threads on lines: C comments on the whole pull request" ;;
  esac
  start_review "$num"
  # shellcheck disable=SC2016
  ql -f query='mutation($r: ID!, $t: ID!, $body: String!) {
      addPullRequestReviewThreadReply(input: {pullRequestReviewId: $r, pullRequestReviewThreadId: $t, body: $body}) { comment { id } } }' \
    -f r="$review" -f t="$3" -f body="${4:?BODY}"
  jq -c '{id: .data.addPullRequestReviewThreadReply.comment.id}' <<<"$out"
  ;;

undraft)
  case "${3:?NOTE}" in
  PRR_*)
    # shellcheck disable=SC2016
    ql -f query='mutation($r: ID!) { updatePullRequestReview(input: {pullRequestReviewId: $r, body: ""}) { pullRequestReview { id } } }' -f r="$3" ;;
  *)
    # shellcheck disable=SC2016
    ql -f query='mutation($id: ID!) { deletePullRequestReviewComment(input: {id: $id}) { pullRequestReview { id } } }' -f id="$3" ;;
  esac
  jq -nc '{ok: true}'
  ;;

resolve)
  if [ "${4:-true}" = true ]; then op=resolveReviewThread; else op=unresolveReviewThread; fi
  ql -f query="mutation(\$t: ID!) { $op(input: {threadId: \$t}) { thread { id isResolved } } }" -f t="${3:?THREAD}"
  jq -c --arg op "$op" '.data[$op].thread | {id, resolved: .isResolved}' <<<"$out"
  ;;

approve)
  pending "${2:?NUMBER}"
  if [ -n "$review" ]; then
    # shellcheck disable=SC2016
    ql -f query='mutation($r: ID!) { submitPullRequestReview(input: {pullRequestReviewId: $r, event: APPROVE}) { pullRequestReview { id } } }' -f r="$review"
  else
    # shellcheck disable=SC2016
    ql -f query='mutation($pr: ID!) { addPullRequestReview(input: {pullRequestId: $pr, event: APPROVE}) { pullRequestReview { id } } }' -f pr="$pr"
  fi
  jq -nc '{ok: true}'
  ;;

unapprove)
  num=${2:?NUMBER}
  # shellcheck disable=SC2016
  ql -f query='query($o: String!, $n: String!, $num: Int!) { viewer { login } repository(owner: $o, name: $n) { pullRequest(number: $num) {
      latestOpinionatedReviews(first: 20) { nodes { databaseId state author { login } } } } } }' -f o="$owner" -f n="$name" -F num="$num"
  id=$(jq -r '.data.viewer.login as $me | [.data.repository.pullRequest.latestOpinionatedReviews.nodes[] | select(.state == "APPROVED" and .author.login == $me)][0].databaseId // empty' <<<"$out")
  [ -n "$id" ] || fail "no approval of mine to take back"
  rest -X PUT "repos/$owner/$name/pulls/$num/reviews/$id/dismissals" -f message="Approval withdrawn" -f event=DISMISS
  jq -nc '{ok: true}'
  ;;

submit)
  pending "${2:?NUMBER}"
  [ -n "$review" ] || fail "no drafts to publish"
  # shellcheck disable=SC2016
  ql -f query='mutation($r: ID!) { submitPullRequestReview(input: {pullRequestReviewId: $r, event: COMMENT}) { pullRequestReview { id } } }' -f r="$review"
  jq -nc '{ok: true}'
  ;;

*)
  echo "usage: mr-review list|show|comment|reply|undraft|resolve|approve|unapprove|submit DIR [NUMBER ...]" >&2
  exit 2
  ;;
esac
