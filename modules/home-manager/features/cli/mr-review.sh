# mr-review: the forge side of Herdr's MRs tab, one JSON answer per call.
#
#   mr-review list DIR                     open merge requests of DIR's repository
#   mr-review show DIR IID                 one merge request: diff, threads, drafts
#   mr-review comment DIR IID BODY [NEW_PATH OLD_PATH OLD_LINE NEW_LINE [RANGE]]
#                                          a draft note, on a line when given one,
#                                          on lines when RANGE is also given:
#                                          {"start": END, "end": END}, each END
#                                          {"oc", "nc", "type", "old", "new"}
#   mr-review reply DIR IID DISCUSSION BODY
#                                          a draft reply to a thread
#   mr-review undraft DIR IID NOTE         drop one of my draft notes
#   mr-review resolve DIR IID DISCUSSION true|false
#   mr-review approve|unapprove DIR IID
#   mr-review submit DIR IID               publish every draft note at once
#   mr-review state DIR IID                my progress on it: {reads, pos}
#   mr-review read DIR IID PATH [DIGEST]   mark a file read at that digest, or
#                                          unmark it with none
#   mr-review pos DIR IID POSITION         keep my place: {path, old, new, ...}
#   mr-review where URL DIR                the checkout of URL's repository: {dir},
#                                          DIR's own, or one beside or below it
#
# DIR is any checkout of the repository; glab takes the host and the project
# from its origin. A repository on GitHub is handed to mr-review-github, which
# answers the same calls in the same shapes. Errors go to stderr with a non-zero exit, and stdout then
# holds {"error": "..."} so the tab can show it.

fail() {
  jq -nc --arg e "$1" '{error: $e}'
  echo "mr-review: $1" >&2
  exit 1
}

enter() {
  cd "$1" 2>/dev/null || fail "no folder $1"
  url=$(git remote get-url origin 2>/dev/null) || fail "no origin remote"
  # git@host:group/sub/project.git or https://host/group/sub/project(.git)
  path=$(printf '%s' "$url" | sed -E 's#^[a-z+]+://[^/]+/##; s#^[^@]+@[^:]+:##; s#\.git$##')
}

# The answer of one request, or the whole script fails with GitLab's message.
# Always into a variable first: inside a pipe, a failure would only end the
# pipe's subshell and the next stage would reshape the error.
api() {
  out=$(glab api "$@" 2>"$err") || fail "$(head -c 300 "$err")"
}

err=$(mktemp)
trap 'rm -f "$err"' EXIT

# shellcheck disable=SC2016 # GraphQL variables, not shell ones
LIST_QUERY='query($p: ID!) {
  currentUser { username }
  project(fullPath: $p) {
    fullPath webUrl
    mergeRequests(state: opened, first: 100, sort: UPDATED_DESC) {
      nodes {
        iid title draft webUrl sourceBranch targetBranch updatedAt createdAt
        author { username name }
        reviewers { nodes { username } }
        approved approvalsLeft approvedBy { nodes { username } }
        headPipeline { status }
        resolvableDiscussionsCount resolvedDiscussionsCount
        diffStatsSummary { additions deletions fileCount }
      }
    }
  }
}'

cmd=${1:-}
shift || true

# Progress is the same for either forge, so it is answered before handing on.
case "$cmd" in
state)
  state_file "${1:?DIR}" "${2:?IID}"
  state
  exit 0
  ;;
read)
  state_file "${1:?DIR}" "${2:?IID}"
  # shellcheck disable=SC2016 # jq variables
  change_state --arg p "${3:?PATH}" --arg d "${4:-}" '.reads |= (if $d == "" then del(.[$p]) else .[$p] = $d end)'
  exit 0
  ;;
pos)
  state_file "${1:?DIR}" "${2:?IID}"
  # shellcheck disable=SC2016 # jq variables
  change_state --argjson pos "${3:?POSITION}" '.pos = $pos'
  exit 0
  ;;
where)
  # An agent in one repository opens requests in the ones beside it, so the
  # checkout is found by its origin: DIR's own, then the folder named after
  # the project beside or below it, then any other there.
  origin_path() {
    git -C "$1" remote get-url origin 2>/dev/null \
      | sed -E 's#^[a-z+]+://[^/]+/##; s#^[^@]+@[^:]+:##; s#\.git$##; s#/$##' | tr '[:upper:]' '[:lower:]'
  }
  want=$(printf '%s' "${1:?URL}" | sed -E 's#/(-/merge_requests|pull)/[0-9]+.*$##; s#^[a-z+]+://[^/]+/##' | tr '[:upper:]' '[:lower:]')
  from=${2:?DIR}
  own=$(git -C "$from" rev-parse --show-toplevel 2>/dev/null) || own=""
  parent=$(dirname "${own:-$from}")
  for d in "$own" "$parent/${want##*/}" "$from/${want##*/}" "$parent"/*/ "$from"/*/; do
    d=${d%/}
    [ -n "$d" ] && [ -e "$d/.git" ] || continue
    if [ "$(origin_path "$d")" = "$want" ]; then
      jq -nc --arg d "$d" '{dir: $d}'
      exit 0
    fi
  done
  fail "no checkout of $want in or beside $from"
  ;;
esac

if [ -n "${1:-}" ] && origin=$(git -C "$1" remote get-url origin 2>/dev/null) && [[ "$origin" == *github.com* ]]; then
  exec mr-review-github "$cmd" "$@"
fi

case "$cmd" in
list)
  enter "${1:?DIR}"
  api graphql -f query="$LIST_QUERY" -f p="$path"
  # GraphQL finds a project only by its path now; an origin left on the path
  # it had before a move is followed by REST, which answers with the new one.
  if [ "$(printf '%s' "$out" | jq -r '.data.project == null')" = true ]; then
    api projects/:id
    path=$(printf '%s' "$out" | jq -r '.path_with_namespace')
    api graphql -f query="$LIST_QUERY" -f p="$path"
  fi
  printf '%s' "$out" | jq -c 'if .errors then {error: (.errors[0].message)} else
      .data.currentUser.username as $me | .data.project as $p |
      {me: $me, project: $p.fullPath, url: $p.webUrl,
       mrs: [$p.mergeRequests.nodes[] | {
         iid: (.iid | tonumber), title, draft, url: .webUrl,
         source: .sourceBranch, target: .targetBranch,
         updated: .updatedAt, created: .createdAt,
         author: .author.username, author_name: .author.name,
         mine: (.author.username == $me),
         review: ([.reviewers.nodes[].username] | index($me) != null),
         approved, approvals_left: .approvalsLeft,
         approved_by_me: ([.approvedBy.nodes[].username] | index($me) != null),
         reviewed: ([.approvedBy.nodes[].username] | index($me) != null),
         pipeline: ((.headPipeline.status // "none") | ascii_downcase),
         threads: .resolvableDiscussionsCount,
         unresolved: (.resolvableDiscussionsCount - .resolvedDiscussionsCount),
         add: .diffStatsSummary.additions, del: .diffStatsSummary.deletions,
         files: .diffStatsSummary.fileCount}]} end'
  ;;

show)
  enter "${1:?DIR}"
  iid=${2:?IID}
  base="projects/:id/merge_requests/$iid"
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp" "$err"' EXIT
  # Five independent requests: in parallel, the tab waits for the slowest.
  # Each leaves its answer, its stderr and its exit code under its name.
  fetch() {
    name=$1
    shift
    glab api "$@" >"$tmp/$name" 2>"$tmp/$name.err"
    echo $? >"$tmp/$name.code"
  }
  fetch mr "$base" &
  fetch diffs --paginate "$base/diffs?per_page=100" &
  fetch threads --paginate "$base/discussions?per_page=100" &
  fetch drafts --paginate "$base/draft_notes?per_page=100" &
  fetch approvals "$base/approvals" &
  wait
  for f in mr diffs threads; do
    [ "$(cat "$tmp/$f.code")" = 0 ] || fail "$(head -c 300 "$tmp/$f.err")"
  done
  # Older GitLab has no draft notes, and approvals can be off for a project.
  [ "$(cat "$tmp/drafts.code")" = 0 ] || echo '[]' >"$tmp/drafts"
  [ "$(cat "$tmp/approvals.code")" = 0 ] || echo '{}' >"$tmp/approvals"
  me=$(glab api user 2>/dev/null | jq -r '.username // empty')
  # --paginate prints one array per page: slurp and add them up.
  jq -n --arg me "$me" \
    --slurpfile mr "$tmp/mr" --slurpfile diffs "$tmp/diffs" \
    --slurpfile threads "$tmp/threads" --slurpfile drafts "$tmp/drafts" \
    --slurpfile approvals "$tmp/approvals" '
    def pos: {path: (.new_path // .old_path), old_path, old_line, new_line};
    $mr[0] as $m | $approvals[0] as $a |
    {me: $me,
     mr: {iid: $m.iid, title: $m.title, description: ($m.description // ""),
          author: $m.author.username, author_name: $m.author.name,
          source: $m.source_branch, target: $m.target_branch, url: $m.web_url,
          draft: $m.draft, state: $m.state, sha: $m.sha, refs: $m.diff_refs,
          merge_status: $m.detailed_merge_status,
          pipeline: ($m.head_pipeline.status // "none"),
          pipeline_url: ($m.head_pipeline.web_url // null),
          approved: ($a.approved // false), approvals_left: ($a.approvals_left // null),
          approved_by: [($a.approved_by // [])[].user.username],
          approved_by_me: ($a.user_has_approved // false),
          can_approve: ($a.user_can_approve // false)},
     files: [($diffs | add // [])[] | {
       old_path, new_path,
       status: (if .new_file then "A" elif .deleted_file then "D" elif .renamed_file then "R" else "M" end),
       generated: (.generated_file // false), too_large: (.too_large // false),
       diff: (.diff // "")}],
     threads: [($threads | add // [])[] | select(.notes[0].system | not) | {
       id, resolvable: (.notes[0].resolvable // false),
       resolved: (.notes[0].resolved // false),
       at: (if .notes[0].position and .notes[0].position.position_type == "text" then (.notes[0].position | pos) else null end),
       notes: [.notes[] | select(.system | not) | {id, author: .author.username, body, created: .created_at}]}],
     drafts: [($drafts | add // [])[] | {
       id, body: .note, reply_to: .discussion_id,
       at: (if .position and .position.position_type == "text" then (.position | pos) else null end)}]}' >"$tmp/out"
  highlight "$tmp/out" "${num:-${iid:-}}"
  ;;

comment)
  enter "${1:?DIR}"
  iid=${2:?IID}
  body=${3:?BODY}
  base="projects/:id/merge_requests/$iid"
  if [ -n "${4:-}" ]; then
    api "$base"
    refs=$(printf '%s' "$out" | jq -c '.diff_refs')
    position=$(jq -nc --argjson r "$refs" --arg new "$4" --arg old "${5:-$4}" \
      --arg ol "${6:-}" --arg nl "${7:-}" '
      {position_type: "text", base_sha: $r.base_sha, start_sha: $r.start_sha, head_sha: $r.head_sha,
       new_path: $new, old_path: $old}
      + (if $ol != "" then {old_line: ($ol | tonumber)} else {} end)
      + (if $nl != "" then {new_line: ($nl | tonumber)} else {} end)')
    if [ -n "${8:-}" ]; then
      # GitLab names a line of a diff by the SHA-1 of the file'"'"'s path and the
      # old and new line counters there, both of them even on a one-sided line.
      sha=$(printf '%s' "$4" | sha1sum | cut -c1-40)
      position=$(jq -nc --argjson p "$position" --argjson r "$8" --arg sha "$sha" '
        def side: {line_code: "\($sha)_\(.oc)_\(.nc)", type, old_line: .old, new_line: .new};
        $p + {line_range: {start: ($r.start | side), end: ($r.end | side)}}') || fail "bad line range: $8"
    fi
    api -X POST "$base/draft_notes" -f note="$body" -F position="$position"
  else
    api -X POST "$base/draft_notes" -f note="$body"
  fi
  printf '%s' "$out" | jq -c '{id}'
  ;;

reply)
  enter "${1:?DIR}"
  api -X POST "projects/:id/merge_requests/${2:?IID}/draft_notes" \
    -f note="${4:?BODY}" -f in_reply_to_discussion_id="${3:?DISCUSSION}"
  printf '%s' "$out" | jq -c '{id}'
  ;;

undraft)
  enter "${1:?DIR}"
  api -X DELETE "projects/:id/merge_requests/${2:?IID}/draft_notes/${3:?NOTE}" 
  jq -nc '{ok: true}'
  ;;

resolve)
  enter "${1:?DIR}"
  api -X PUT "projects/:id/merge_requests/${2:?IID}/discussions/${3:?DISCUSSION}" \
    -F resolved="${4:-true}"
  printf '%s' "$out" | jq -c '{id, resolved: .notes[0].resolved}'
  ;;

approve | unapprove)
  enter "${1:?DIR}"
  api -X POST "projects/:id/merge_requests/${2:?IID}/$cmd" 
  jq -nc '{ok: true}'
  ;;

submit)
  enter "${1:?DIR}"
  api -X POST "projects/:id/merge_requests/${2:?IID}/draft_notes/bulk_publish" 
  jq -nc '{ok: true}'
  ;;

*)
  echo "usage: mr-review list|show|comment|reply|undraft|resolve|approve|unapprove|submit DIR [IID ...]" >&2
  exit 2
  ;;
esac
