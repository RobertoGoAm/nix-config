#!/usr/bin/env bash
# jira-board: the Jira side of Herdr's board tab and of the jira wrapper.
#   jira-board login                     store the API token in the keychain
#   jira-board project FOLDER [BRANCH]   the project key for a checkout
#   jira-board meta KEY                  the project's board and its columns
#   jira-board view FOLDER [BRANCH]      board, sprint, issues and backlog as JSON
#   jira-board transitions ISSUE         the moves open to an issue
#   jira-board move ISSUE TRANSITION     make one
#   jira-board assign ISSUE              assign it to yourself
set -u -o pipefail

conf="${JIRA_BOARD_CONFIG:-$HOME/.config/jira-board/config.json}"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/jira-board"
fields="summary,status,issuetype,priority,assignee,parent"

fail() {
  jq -nc --arg e "$1" '{error: $e}'
  exit 1
}

[ -r "$conf" ] || fail "no Jira configured on this machine"
server="$(jq -r .server "$conf")"
login="$(jq -r .login "$conf")"

token() {
  /usr/bin/security find-generic-password -s jira-api-token -a "$login" -w 2>/dev/null
}

api() {
  local t
  t="$(token)" || {
    echo "no Jira API token in the keychain: run jira-board login" >&2
    return 9
  }
  if [ $# -ge 3 ]; then
    curl -sS --fail-with-body -u "$login:$t" -X "$1" -H 'Accept: application/json' \
      -H 'Content-Type: application/json' --data "$3" "$server$2"
  else
    curl -sS --fail-with-body -u "$login:$t" -X "$1" -H 'Accept: application/json' "$server$2"
  fi
}

uri() {
  jq -rn --arg q "$1" '$q | @uri'
}

project() {
  local key
  key="$(printf '%s' "${2:-}" | grep -oE '[A-Z][A-Z0-9]+-[0-9]+' | head -1 | cut -d- -f1 || true)"
  if [ -n "$key" ]; then
    echo "$key"
    return
  fi
  jq -r --arg f "$1" '(.folders // {}) | to_entries
    | map(select(.key as $p
        | if ($p | endswith("*")) then ($f | startswith($p | rtrimstr("*")))
          else $f == $p or ($f | startswith($p + "/")) or ($f | startswith($p + "-worktrees/")) end))
    | sort_by(.key | length) | last | .value // empty' "$conf"
}

meta() {
  local file="$cache/$1.json" want boards board id cols me
  if [ -s "$file" ] && [ -z "$(find "$file" -mmin +1440)" ]; then
    cat "$file"
    return
  fi
  mkdir -p "$cache"
  want="$(jq -r --arg k "$1" '(.boards // {})[$k] // empty' "$conf")"
  boards="$(api GET "/rest/agile/1.0/board?projectKeyOrId=$1&maxResults=50")" || return 1
  board="$(jq -c --arg w "$want" '[.values[]]
    | if $w != "" then map(select((.id | tostring) == $w)) else . end
    | (map(select(.type == "scrum")) + .)[0] // empty' <<<"$boards")"
  [ -n "$board" ] || return 3
  id="$(jq -r .id <<<"$board")"
  cols="$(api GET "/rest/agile/1.0/board/$id/configuration")" || return 1
  me="$(api GET "/rest/api/3/myself")" || return 1
  jq -nc --arg k "$1" --arg s "$server" --argjson b "$board" --argjson c "$cols" --argjson me "$me" '{
    key: $k,
    board: {id: $b.id, name: $b.name, type: $b.type, url: "\($s)/jira/software/c/projects/\($k)/boards/\($b.id)"},
    columns: [$c.columnConfig.columns[] | {name, statuses: [.statuses[].id]}],
    me: $me.accountId
  }' >"$file.tmp" && mv "$file.tmp" "$file" && cat "$file"
}

view() {
  local key m id type sprint='null' sid issues backlog
  key="$(project "$1" "${2:-}")"
  [ -n "$key" ] || fail "no Jira project for this folder: name the branch after a ticket or map the folder"
  token >/dev/null || fail "no Jira API token yet: run jira-board login in a terminal"
  m="$(meta "$key")" || fail "could not read the board of $key"
  id="$(jq -r .board.id <<<"$m")"
  type="$(jq -r .board.type <<<"$m")"
  issues='{"issues":[]}'
  if [ "$type" = scrum ]; then
    sprint="$(api GET "/rest/agile/1.0/board/$id/sprint?state=active")" || fail "could not read the sprint of $key"
    sprint="$(jq -c '.values[0] // null | if . == null then null else {id, name, end: (.endDate // null), goal: (.goal // null)} end' <<<"$sprint")"
    sid="$(jq -r '.id // empty' <<<"$sprint")"
    if [ -n "$sid" ]; then
      issues="$(api GET "/rest/agile/1.0/sprint/$sid/issue?maxResults=200&fields=$fields")" || fail "could not read the sprint's issues"
    fi
  else
    issues="$(api GET "/rest/agile/1.0/board/$id/issue?maxResults=200&fields=$fields&jql=$(uri 'statusCategory != Done OR resolutiondate >= -14d')")" ||
      fail "could not read the board's issues"
  fi
  backlog="$(api GET "/rest/agile/1.0/board/$id/backlog?maxResults=100&fields=$fields")" || backlog='{"issues":[]}'
  jq -nc --arg s "$server" --argjson m "$m" --argjson sprint "$sprint" --argjson i "$issues" --argjson b "$backlog" '
    def card: {
      key, summary: .fields.summary,
      status: .fields.status.name, statusId: .fields.status.id,
      category: .fields.status.statusCategory.key,
      type: .fields.issuetype.name, subtask: (.fields.issuetype.subtask // false),
      parent: (.fields.parent.key // null),
      priority: (.fields.priority.name // null),
      assignee: (.fields.assignee.displayName // null),
      mine: ((.fields.assignee.accountId // "") == $m.me),
      url: "\($s)/browse/\(.key)"
    };
    $m + {sprint: $sprint, issues: [$i.issues[] | card], backlog: [$b.issues[] | card], at: (now | floor)}'
}

case "${1:-}" in
  login)
    /usr/bin/security add-generic-password -U -s jira-api-token -a "$login" -w || exit 1
    rm -rf "$cache"
    api GET /rest/api/3/myself | jq -r '"Signed in to Jira as \(.displayName)"'
    ;;
  project) project "${2:?folder}" "${3:-}" ;;
  meta) meta "${2:?key}" ;;
  view) view "${2:?folder}" "${3:-}" ;;
  transitions)
    api GET "/rest/api/3/issue/${2:?issue}/transitions" |
      jq -c '[.transitions[] | {id, name, to: .to.name, category: .to.statusCategory.key}]'
    ;;
  move)
    api POST "/rest/api/3/issue/${2:?issue}/transitions" "$(jq -nc --arg t "${3:?transition}" '{transition: {id: $t}}')" >/dev/null
    ;;
  assign)
    me="$(api GET /rest/api/3/myself | jq -r .accountId)" || exit 1
    api PUT "/rest/api/3/issue/${2:?issue}/assignee" "$(jq -nc --arg a "$me" '{accountId: $a}')" >/dev/null
    ;;
  *)
    cat >&2 <<'USAGE'
jira-board login                     store the API token in the keychain
jira-board project FOLDER [BRANCH]   the project key for a checkout
jira-board meta KEY                  the project's board and its columns
jira-board view FOLDER [BRANCH]      board, sprint, issues and backlog as JSON
jira-board transitions ISSUE         the moves open to an issue
jira-board move ISSUE TRANSITION     make one
jira-board assign ISSUE              assign it to yourself
USAGE
    exit 2
    ;;
esac
