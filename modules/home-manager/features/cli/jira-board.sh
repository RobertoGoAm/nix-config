#!/usr/bin/env bash
# jira-board: the Jira side of Herdr's board tab and of the jira wrapper.
# Several Jira sites can be configured; a checkout's folder picks the site.
set -u -o pipefail

conf="${JIRA_BOARD_CONFIG:-$HOME/.config/jira-board/config.json}"
cacheroot="${XDG_CACHE_HOME:-$HOME/.cache}/jira-board"
fields="summary,status,issuetype,priority,assignee,parent,flagged,created,timetracking,subtasks,labels,components"
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
jira-board export FOLDER [BRANCH] [--copy]
                                      every issue of the board and its backlog,
                                      sub-tasks included, as a table for an agent
jira-board --site NAME issue ISSUE [--json | --copy]
                                      the issue written out for an agent to read
                                      (--copy: onto the clipboard instead)
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

keep() {
  local out
  out="$(cat)"
  [ -n "$out" ] || return 1
  if ! { printf '%s\n' "$out" >"$1.$$" && mv -f "$1.$$" "$1" 2>/dev/null; }; then
    rm -f "$1.$$"
  fi
  printf '%s\n' "$out"
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
  local file="$cache/$1.json" want boards board id cols me lanes
  if [ -s "$file" ] && [ -z "$(find "$file" -mmin +1440)" ] && jq -e 'has("swimlanes")' "$file" >/dev/null 2>&1; then
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
  lanes="$(api GET "/rest/greenhopper/1.0/rapidviewconfig/editmodel.json?rapidViewId=$id" 2>/dev/null |
    jq -c '{strategy: (.swimlanesConfig.swimlaneStrategy // "none"),
      lanes: [.swimlanesConfig.swimlanes[]? | {name, query: (.query // ""), default: (.isDefault // false)}]}' 2>/dev/null)" ||
    lanes='{"strategy":"none","lanes":[]}'
  [ -n "$lanes" ] || lanes='{"strategy":"none","lanes":[]}'
  jq -nc --arg site "$site" --arg k "$1" --arg s "$server" --argjson b "$board" --argjson c "$cols" --argjson me "$me" --argjson l "$lanes" '{
    site: $site, key: $k,
    board: {id: $b.id, name: $b.name, type: $b.type, url: "\($s)/jira/software/c/projects/\($k)/boards/\($b.id)"},
    columns: [$c.columnConfig.columns[] | {name, statuses: [.statuses[].id]}],
    swimlanes: $l,
    me: $me.accountId
  }' | keep "$file"
}

paged() {
  local all='[]' at=0 page n total
  while [ "$at" -lt 2000 ]; do
    page="$(api GET "$1&maxResults=100&startAt=$at")" || return 1
    all="$(jq -c --argjson p "$page" '. + ($p.issues // [])' <<<"$all")"
    n="$(jq '.issues // [] | length' <<<"$page")"
    total="$(jq '.total // 0' <<<"$page")"
    at=$((at + n))
    { [ "$n" -gt 0 ] && [ "$at" -lt "$total" ]; } || break
  done
  jq -c '{issues: .}' <<<"$all"
}

view() {
  local m id type sprint='null' sid='' issues backlog file lanekeys q
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
      issues="$(paged "/rest/agile/1.0/sprint/$sid/issue?fields=$fields")" || fail "could not read the sprint's issues"
    fi
  else
    issues="$(paged "/rest/agile/1.0/board/$id/issue?fields=$fields&jql=$(uri 'statusCategory != Done OR resolutiondate >= -14d')")" ||
      fail "could not read the board's issues"
  fi
  backlog="$(paged "/rest/agile/1.0/board/$id/backlog?fields=$fields")" || backlog='{"issues":[]}'
  lanekeys='[]'
  if [ "$(jq -r '.swimlanes.strategy // "none"' <<<"$m")" = custom ]; then
    while IFS= read -r q; do
      [ -n "$q" ] || continue
      local keys='[]' at=0 path page n total
      if [ -n "$sid" ]; then
        path="/rest/agile/1.0/sprint/$sid/issue?jql=$(uri "$q")"
      else
        path="/rest/agile/1.0/board/$id/issue?jql=$(uri "($q) AND (statusCategory != Done OR resolutiondate >= -14d)")"
      fi
      while [ "$at" -lt 1000 ]; do
        page="$(api GET "$path&fields=summary&maxResults=100&startAt=$at" 2>/dev/null)" || break
        keys="$(jq -c --argjson p "$page" '. + [$p.issues[]?.key]' <<<"$keys")"
        n="$(jq '.issues | length' <<<"$page")"
        total="$(jq '.total // 0' <<<"$page")"
        at=$((at + n))
        { [ "$n" -gt 0 ] && [ "$at" -lt "$total" ]; } || break
      done
      lanekeys="$(jq -c --arg q "$q" --argjson k "$keys" '. + [{query: $q, keys: $k}]' <<<"$lanekeys")"
    done < <(jq -r '.swimlanes.lanes[] | select(.default | not) | .query' <<<"$m")
  fi
  jq -nc --arg s "$server" --argjson m "$m" --argjson sprint "$sprint" --argjson i "$issues" --argjson b "$backlog" --argjson lk "$lanekeys" '
    def card: {
      key, summary: .fields.summary,
      status: .fields.status.name, statusId: .fields.status.id,
      category: .fields.status.statusCategory.key,
      type: .fields.issuetype.name, subtask: (.fields.issuetype.subtask // false),
      parent: (.fields.parent.key // null),
      priority: (.fields.priority.name // null),
      assignee: (.fields.assignee.displayName // null),
      labels: (.fields.labels // []),
      components: [(.fields.components // [])[].name],
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
    $m + {sprint: $sprint, issues: [$i.issues[] | card], backlog: [$b.issues[] | card], at: (now | floor)}
    | .swimlanes.lanes = [(.swimlanes.lanes // [])[] | . as $lane | . + {keys: (if .default then null else ([$lk[] | select(.query == $lane.query) | .keys][0] // []) end)}]' | keep "$file"
}

issue() {
  local raw
  raw="$(api GET "/rest/api/2/issue/$1?fields=summary,description,status,issuetype,priority,assignee,reporter,parent,labels,timetracking,subtasks,issuelinks,comment,created")" ||
    fail "could not read $1"
  if [ "${2:-}" = --json ]; then
    jq -c --arg server "$server" --arg site "$site" '{key, site: $site, summary: .fields.summary, status: .fields.status.name,
      url: "\($server)/browse/\(.key)", type: .fields.issuetype.name, priority: (.fields.priority.name // null),
      assignee: (.fields.assignee.displayName // null)}' <<<"$raw"
    return
  fi
  jq -r --arg server "$server" '
    def tidy: gsub("\r"; "") | gsub("[ \t]+\n"; "\n") | gsub("\n{3,}"; "\n\n") | sub("^\n+"; "") | sub("\n+$"; "");
    def linked(dir; i): "- \(dir) \(i.key) \(i.fields.summary) (\(i.fields.status.name))";
    .fields as $f |
    "# \(.key): \($f.summary)", "",
    "\($server)/browse/\(.key)", "",
    "- Type: \($f.issuetype.name)",
    "- Status: \($f.status.name)",
    "- Priority: \($f.priority.name // "none")",
    "- Assignee: \($f.assignee.displayName // "unassigned")",
    "- Reporter: \($f.reporter.displayName // "unknown")",
    "- Created: \(($f.created // "")[0:10])",
    (if $f.parent then "- Parent: \($f.parent.key) \($f.parent.fields.summary)" else empty end),
    (if (($f.labels // []) | length) > 0 then "- Labels: \($f.labels | join(", "))" else empty end),
    (if $f.timetracking.originalEstimate then "- Estimate: \($f.timetracking.remainingEstimate // "?") left of \($f.timetracking.originalEstimate)" else empty end),
    "", "## Description", "", (($f.description // "") | tidy | if . == "" then "(none)" else . end),
    (if (($f.subtasks // []) | length) > 0 then "", "## Sub-tasks", "",
      ($f.subtasks[] | "- \(.key) \(.fields.summary) (\(.fields.status.name))") else empty end),
    (if (($f.issuelinks // []) | length) > 0 then "", "## Linked issues", "",
      ($f.issuelinks[] | if .outwardIssue then linked(.type.outward; .outwardIssue) else linked(.type.inward; .inwardIssue) end) else empty end),
    (($f.comment.comments // []) | if length > 0 then "", "## Comments", "",
      (.[-10:][] | "### \(.author.displayName) · \(.created[0:10])", "", (.body | tidy), "") else empty end)
  ' <<<"$raw" | if [ "${2:-}" = --copy ]; then /usr/bin/pbcopy; else cat; fi
}

export_board() {
  local v keys all='[]' batch found out
  resolve "$1" "${2:-}" || fail "this folder belongs to no configured Jira site"
  v="$(view "$1" "${2:-}")" || exit 1
  keys="$(jq -c '[(.issues[], .backlog[]) | .key, .subtasks[].key] | unique' <<<"$v")"
  for ((at = 0; at < $(jq length <<<"$keys"); at += 100)); do
    batch="$(jq -r --argjson a "$at" '.[$a:$a + 100] | join(",")' <<<"$keys")"
    found="$(api POST /rest/api/3/search/jql "$(jq -nc --arg q "key in ($batch)" \
      '{jql: $q, maxResults: 100, fields: ["summary", "status", "issuetype", "priority", "assignee", "parent", "labels", "components", "created", "timetracking"]}')")" ||
      fail "could not read the issues"
    all="$(jq -c --argjson f "$found" '. + $f.issues' <<<"$all")"
  done
  out="$(jq -r --argjson v "$v" '
    def clean: tostring | gsub("[\t\n\r|]+"; " ");
    ($v.columns // []) as $cols |
    (reduce $v.issues[] as $i ({}; .[$i.key] = ([$cols[] | select(.statuses | map(tostring) | index($i.statusId | tostring)) | .name][0] // $i.status))) as $col |
    (reduce $v.backlog[] as $i ({}; .[$i.key] = "Backlog")) as $back |
    (map({key: .key, value: .}) | from_entries) as $by |
    def place(k): $col[k] // $back[k];
    def row(f; where):
      [where, f.key, f.fields.issuetype.name, (f.fields.parent.key // ""), f.fields.summary, f.fields.status.name,
       (f.fields.priority.name // ""), (f.fields.assignee.displayName // "unassigned"), ((f.fields.created // "")[0:10]),
       (if f.fields.created then ((now - (f.fields.created[0:19] + "Z" | fromdateiso8601)) / 86400 | floor) else "" end),
       (f.fields.timetracking.originalEstimate // ""), (f.fields.timetracking.remainingEstimate // ""), (f.fields.timetracking.timeSpent // ""),
       ((f.fields.labels // []) | join(", ")), ([(f.fields.components // [])[].name] | join(", "))] | map(clean) | join("\t");
    "Jira board \($v.board.name) (project \($v.key)), exported \(now | strftime("%Y-%m-%d")).",
    "Where: the board column the issue is in, or Backlog; a sub-task is listed after its parent, with the parent in Parent, and is where its parent is.",
    "Age: days since it was created. Estimates are Jira time strings (1w = 5d, 1d = 8h).",
    "",
    (["Where", "Key", "Type", "Parent", "Summary", "Status", "Priority", "Assignee", "Created", "Age (days)", "Original estimate", "Remaining", "Spent", "Labels", "Components"] | join("\t")),
    (($v.issues + $v.backlog)[] as $i | ($by[$i.key] // empty) as $f |
      row($f; place($i.key)),
      ($i.subtasks[] | ($by[.key] // empty) as $s | row($s; "\(place($i.key)) (sub-task)")))
  ' <<<"$all")" || fail "could not write the table"
  printf '%s\n' "$out"
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
  export)
    shift
    copy=""
    args=()
    for a in "$@"; do
      if [ "$a" = --copy ]; then copy=1; else args+=("$a"); fi
    done
    if [ -n "$copy" ]; then
      export_board "${args[0]:?folder}" "${args[1]:-}" | /usr/bin/pbcopy
    else
      export_board "${args[0]:?folder}" "${args[1]:-}"
    fi
    ;;
  meta | transitions | move | assign | issue)
    [ -n "$site" ] || only
    case "$1" in
      meta) meta "${2:?key}" ;;
      issue) issue "${2:?issue}" "${3:-}" ;;
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
