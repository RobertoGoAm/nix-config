#!/usr/bin/env bash
# jira-board: the Jira side of Herdr's board tab and of the jira wrapper.
# Several Jira sites can be configured; a checkout's folder picks the site.
set -u -o pipefail

conf="${JIRA_BOARD_CONFIG:-$HOME/.config/jira-board/config.json}"
cacheroot="${XDG_CACHE_HOME:-$HOME/.cache}/jira-board"
fields="summary,status,issuetype,priority,assignee,parent,flagged,created,timetracking,subtasks"
site="" server="" login="" cache="" key=""

fail() {
  jq -nc --arg e "$1" '{error: $e}'
  exit 1
}

usage() {
  cat >&2 <<'USAGE'
jira-board [--site NAME] login        store the API token(s) in the keychain
jira-board [--site NAME] check        try the stored token(s) again
jira-board sites                      the configured sites
jira-board project FOLDER [BRANCH]    the site and project key for a checkout
jira-board [--fresh] view FOLDER [BRANCH]
                                      board, sprint, issues and backlog as JSON
                                      (kept 90 s unless --fresh)
jira-board --site NAME meta KEY       a project's board and its columns
jira-board --site NAME transitions ISSUE
jira-board --site NAME move ISSUE TRANSITION
jira-board --site NAME assign ISSUE   to yourself
USAGE
  exit 2
}

[ -r "$conf" ] || fail "no Jira configured on this machine"

use() {
  site="$1"
  server="$(jq -r --arg s "$site" '.sites[$s].server // empty' "$conf")"
  [ -n "$server" ] || fail "no Jira site called $site"
  login="$(jq -r --arg s "$site" '.sites[$s].login' "$conf")"
  cache="$cacheroot/$site"
}

only() {
  local names
  names="$(jq -r '.sites | keys[]' "$conf")"
  [ "$(wc -l <<<"$names")" -eq 1 ] || fail "several Jira sites: say which with --site"
  use "$names"
}

token() {
  /usr/bin/security find-generic-password -s jira-api-token -a "$login" -w 2>/dev/null
}

base() {
  if [ -s "$cache/base" ]; then cat "$cache/base"; else echo "$server"; fi
}

api() {
  local t b
  t="$(token)" || {
    echo "no Jira API token in the keychain for $login: run jira-board login" >&2
    return 9
  }
  b="${JIRA_BOARD_BASE:-$(base)}"
  if [ $# -ge 3 ]; then
    curl -sS --fail-with-body -u "$login:$t" -X "$1" -H 'Accept: application/json' \
      -H 'Content-Type: application/json' --data "$3" "$b$2"
  else
    curl -sS --fail-with-body -u "$login:$t" -X "$1" -H 'Accept: application/json' "$b$2"
  fi
}

signin() {
  local cid gateway who
  mkdir -p "$cache"
  if who="$(JIRA_BOARD_BASE="$server" api GET /rest/api/3/myself 2>/dev/null)"; then
    echo "$server" >"$cache/base"
  else
    cid="$(curl -sS "$server/_edge/tenant_info" | jq -r '.cloudId // empty')"
    gateway="https://api.atlassian.com/ex/jira/$cid"
    if [ -n "$cid" ] && who="$(JIRA_BOARD_BASE="$gateway" api GET /rest/api/3/myself 2>/dev/null)"; then
      echo "$gateway" >"$cache/base"
    else
      echo "$site: Jira refused the token for $login. Check that the token was copied whole, that it" >&2
      echo "was made signed in as $login, and that $login is how you sign in to $server." >&2
      return 1
    fi
  fi
  jq -r --arg s "$site" '"\($s): signed in to Jira as \(.displayName)"' <<<"$who"
}

login_site() {
  local t
  echo "$site ($server), as $login." >&2
  IFS= read -rsp "API token (hidden): " t </dev/tty
  echo >&2
  t="$(printf '%s' "$t" | tr -d '[:space:]')"
  if [ -z "$t" ]; then
    echo "$site: no token given, skipped." >&2
    return 1
  fi
  printf 'add-generic-password -U -s jira-api-token -a %s -w %s\n' "$login" "$t" | /usr/bin/security -i >/dev/null || return 1
  unset t
  rm -rf "$cache"
  signin
}

uri() {
  jq -rn --arg q "$1" '$q | @uri'
}

locate() {
  jq -c --arg f "$1" '
    def hit($p):
      if ($p | endswith("*")) then ($f | startswith($p | rtrimstr("*")))
      else $f == $p or ($f | startswith($p + "/")) or ($f | startswith($p + "-worktrees/")) end;
    [.sites | to_entries[] | .key as $s | .value as $v
      | (($v.roots // [])[] | {site: $s, path: ., key: null}),
        (($v.folders // {}) | to_entries[] | {site: $s, path: .key, key: .value})]
    | map(select(hit(.path))) | sort_by(.path | length)
    | (last // null) as $best
    | if $best == null then null
      else {site: $best.site, key: (map(select(.site == $best.site and .key != null)) | last | .key // null)} end' "$conf"
}

resolve() {
  local where s
  where="$(locate "$1")"
  s="$(jq -r '.site // empty' <<<"$where")"
  [ -n "$s" ] || return 1
  use "$s"
  key="$(printf '%s' "${2:-}" | grep -oE '[A-Z][A-Z0-9]+-[0-9]+' | head -1 | cut -d- -f1 || true)"
  [ -n "$key" ] || key="$(jq -r '.key // empty' <<<"$where")"
}

project() {
  resolve "$1" "${2:-}" || return 1
  jq -nc --arg site "$site" --arg server "$server" --arg login "$login" --arg key "$key" \
    '{site: $site, server: $server, login: $login, key: (if $key == "" then null else $key end)}'
}

meta() {
  local file="$cache/$1.json" want boards board id cols me
  if [ -s "$file" ] && [ -z "$(find "$file" -mmin +1440)" ]; then
    cat "$file"
    return
  fi
  mkdir -p "$cache"
  want="$(jq -r --arg s "$site" --arg k "$1" '(.sites[$s].boards // {})[$k] // empty' "$conf")"
  boards="$(api GET "/rest/agile/1.0/board?projectKeyOrId=$1&maxResults=50")" || return 1
  board="$(jq -c --arg w "$want" '[.values[]]
    | if $w != "" then map(select((.id | tostring) == $w)) else . end
    | (map(select(.type == "scrum")) + .)[0] // empty' <<<"$boards")"
  [ -n "$board" ] || return 3
  id="$(jq -r .id <<<"$board")"
  cols="$(api GET "/rest/agile/1.0/board/$id/configuration")" || return 1
  me="$(api GET "/rest/api/3/myself")" || return 1
  jq -nc --arg site "$site" --arg k "$1" --arg s "$server" --argjson b "$board" --argjson c "$cols" --argjson me "$me" '{
    site: $site, key: $k,
    board: {id: $b.id, name: $b.name, type: $b.type, url: "\($s)/jira/software/c/projects/\($k)/boards/\($b.id)"},
    columns: [$c.columnConfig.columns[] | {name, statuses: [.statuses[].id]}],
    me: $me.accountId
  }' >"$file.tmp" && mv "$file.tmp" "$file" && cat "$file"
}

view() {
  local m id type sprint='null' sid issues backlog file
  resolve "$1" "${2:-}" || fail "this folder belongs to no configured Jira site"
  [ -n "$key" ] || fail "no Jira project for this folder on $site: name the branch after a ticket or map the folder"
  token >/dev/null || fail "no Jira API token for $site yet: run jira-board login in a terminal"
  file="$cache/$key.view.json"
  if [ -z "${fresh:-}" ] && [ -s "$file" ] && [ $(($(date +%s) - $(stat -c %Y "$file"))) -lt 90 ]; then
    cat "$file"
    return
  fi
  m="$(meta "$key")" || fail "could not read the board of $key on $site"
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
      flagged: (.fields.flagged // false),
      created: ((.fields.created // "") | sub("(?<h>[+-][0-9]{2})(?<m>[0-9]{2})$"; "\(.h):\(.m)")),
      estimate: (.fields.timetracking // {} | {
        original: (.originalEstimate // null), remaining: (.remainingEstimate // null), spent: (.timeSpent // null),
        originalS: (.originalEstimateSeconds // null), remainingS: (.remainingEstimateSeconds // null), spentS: (.timeSpentSeconds // null)
      }),
      subtasks: [(.fields.subtasks // [])[] | {
        key, summary: .fields.summary, status: .fields.status.name,
        category: (.fields.status.statusCategory.key // null),
        priority: (.fields.priority.name // null), type: (.fields.issuetype.name // null),
        url: "\($s)/browse/\(.key)"
      }],
      mine: ((.fields.assignee.accountId // "") == $m.me),
      url: "\($s)/browse/\(.key)"
    };
    $m + {sprint: $sprint, issues: [$i.issues[] | card], backlog: [$b.issues[] | card], at: (now | floor)}' >"$file.tmp" &&
    mv "$file.tmp" "$file" && cat "$file"
}

each_site() {
  local s status=0
  if [ -n "$site" ]; then
    "$@" || status=1
    return "$status"
  fi
  for s in $(jq -r '.sites | keys[]' "$conf"); do
    use "$s"
    "$@" || status=1
  done
  return "$status"
}

fresh=""
if [ "${1:-}" = "--fresh" ]; then
  fresh=1
  shift
fi

if [ "${1:-}" = "--site" ]; then
  use "${2:?site name}"
  shift 2
fi

case "${1:-}" in
  login)
    if [ ! -t 0 ]; then
      echo "jira-board login asks for each token, hidden: run it in a terminal tab, not through a pipe." >&2
      exit 2
    fi
    each_site login_site
    ;;
  check)
    clear_base() {
      rm -f "$cache/base"
      signin
    }
    each_site clear_base
    ;;
  sites) jq -c '.sites | to_entries | map({site: .key, server: .value.server, login: .value.login})' "$conf" ;;
  project) project "${2:?folder}" "${3:-}" ;;
  view) view "${2:?folder}" "${3:-}" ;;
  meta | transitions | move | assign)
    [ -n "$site" ] || only
    case "$1" in
      meta) meta "${2:?key}" ;;
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
    esac
    ;;
  *) usage ;;
esac
