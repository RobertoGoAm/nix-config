#!/usr/bin/env bash
# jira-digest: a daily note per Jira board of the tickets that touch the parts
# of the system named in its config, with what is new or changed since the
# last one. Claude sorts the tickets into those parts; jira-board reads Jira.
set -u -o pipefail

conf="${JIRA_DIGEST_CONFIG:-$HOME/.config/jira-digest/config.json}"
stateroot="${XDG_STATE_HOME:-$HOME/.local/state}/jira-digest"
today="$(date +%F)"
scheduled=""
only=""
BATCH=40

usage() {
  cat >&2 <<'USAGE'
jira-digest [KEY]           write today's digest now (every board, or KEY's)
jira-digest --scheduled     the same, unless a digest was already written today
USAGE
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --scheduled) scheduled=1 ;;
    -h | --help) usage ;;
    -*) usage ;;
    *) only="$1" ;;
  esac
  shift
done

[ -r "$conf" ] || {
  echo "jira-digest: no digests configured ($conf)" >&2
  exit 1
}
mkdir -p "$stateroot"

if [ -n "$scheduled" ] && [ "$(cat "$stateroot/last-run" 2>/dev/null)" = "$today" ]; then
  echo "jira-digest: already written today" >&2
  exit 0
fi

notify() {
  terminal-notifier -group "jira-digest-$1" -title "$2" -message "$3" ${4:+-open "$4"} >/dev/null 2>&1 || true
}

# The stream's repositories, each with the stack its manifest shows, so
# Claude can tell which part a repository named in a ticket belongs to. A
# repository cloned later counts the next morning with no config to edit.
repos() {
  local root="$HOME/$1" d name kind
  [ -d "$root" ] || return 0
  for d in "$root"/*/; do
    name="$(basename "$d")"
    case "$name" in *-worktrees | backups | *[A-Z]*) continue ;; esac
    if [ -e "$d/composer.json" ]; then kind="PHP"
    elif ls "$d"/nuxt.config.* >/dev/null 2>&1; then kind="Nuxt"
    elif [ -e "$d/pyproject.toml" ] || [ -e "$d/requirements.txt" ]; then kind="Python"
    elif [ -e "$d/pom.xml" ] || [ -e "$d/build.gradle" ]; then kind="Java"
    elif [ -e "$d/package.json" ] && grep -q '"vue"' "$d/package.json" 2>/dev/null; then kind="Vue/JS"
    elif [ -e "$d/package.json" ]; then kind="JS/TS"
    else kind="other"
    fi
    printf -- '- %s (%s)\n' "$name" "$kind"
  done
}

# The Claude half: one batch of tickets in, a JSON array of verdicts out.
classify() {
  local digest="$1" tickets="$2" prompt out json
  prompt="$(jq -r --argjson d "$digest" --argjson t "$tickets" --arg repos "$(repos "$(jq -r '.repos // ""' <<<"$digest")")" \
    --arg projects "$projects" -n '
    "You sort Jira tickets by the part of the system their work touches.",
    "",
    "About this project:",
    ($d.context // "(no notes)"),
    "",
    (if $projects != "" then "The projects of the stream, as its Confluence space lists them:", $projects, "" else empty end),
    (if $repos != "" then "The repositories of the stream, with the stack each one\u0027s manifest shows:", $repos, "" else empty end),
    "The parts:",
    ($d.areas[] | "- \(.id): \(.label). \(.hint // "")"),
    "",
    "A ticket can touch several parts, or none of them (an empty list): core backend",
    "work, operations, analysis that names no part. A sub-task usually belongs to the",
    "part its own title names, not to everything its parent covers. Judge from the",
    "title, labels, components, parent and description below; when they are not",
    "enough and Atlassian tools are available, read the ticket or the pages it links.",
    "",
    "Answer with only a JSON array, one object per ticket, nothing before or after it:",
    "[{\"key\": \"ABC-1\", \"areas\": [\"<part id>\"], \"why\": \"<at most twelve words>\"}]",
    "",
    "Tickets:",
    ($t | tostring)')"
  # The prompt goes in on stdin: --allowedTools takes every word after it,
  # and would take a prompt given as an argument too.
  out="$(cd "$stateroot" && printf '%s' "$prompt" | CLAUDE_ACCOUNT=work claude -p --model "$(jq -r '.model // "sonnet"' <<<"$digest")" \
    --allowedTools "mcp__claude_ai_Atlassian__getJiraIssue mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql mcp__claude_ai_Atlassian__getConfluencePage" \
    2>>"$stateroot/claude.err")" || return 1
  json="[${out#*\[}"
  json="${json%\]*}]"
  jq -ce 'map(select(type == "object" and (.key | type) == "string")) | map({key, areas: (.areas // []), why: (.why // "")})' <<<"$json"
}

digest_one() {
  local digest="$1" site key dir vault folder note tsv rows texts prev classes need verdicts n prevdate batch
  site="$(jq -r .site <<<"$digest")"
  key="$(jq -r .key <<<"$digest")"
  dir="$stateroot/$site-$key"
  mkdir -p "$dir"
  vault="$(jq -r .vault "$conf")"
  folder="$vault/$(jq -r .notes <<<"$digest")"
  note="$folder/$today.md"

  projects=""
  if [ "$(jq -r '.projectsPage // ""' <<<"$digest")" != "" ]; then
    projects="$(jira-board --site "$site" children "$(jq -r .projectsPage <<<"$digest")" 2>/dev/null | sed 's/^/- /')" || projects=""
  fi
  tsv="$(jira-board --fresh --site "$site" export "$key")" || {
    notify "$key" "Jira digest $key failed" "Could not read the board: $(jq -r '.error // empty' <<<"$tsv" 2>/dev/null)"
    return 1
  }
  # The table under the explanation lines, as objects keyed by its header.
  rows="$(sed -n '/^Where\tKey\t/,$p' <<<"$tsv" | jq -Rsc '
    split("\n") | map(select(length > 0) | split("\t")) |
    .[0] as $h | .[1:] | map([$h, .] | transpose | map({key: .[0], value: (.[1] // "")}) | from_entries)')"

  texts="$(jq -r '.[].Key' <<<"$rows" | xargs jira-board --site "$site" texts | jq -sc 'map(select(.key != null) | {key: .key, value: .}) | from_entries')" ||
    texts='{}'
  classes="$(cat "$dir/classes.json" 2>/dev/null || echo '{}')"

  # Tickets Claude has not seen, or that changed in Jira since it did.
  need="$(jq -c --argjson c "$classes" --argjson t "$texts" '
    [.[] | .Key as $k | select(($c[$k].updated // "") != ($t[$k].updated // "none")) | $k]' <<<"$rows")"
  n="$(jq length <<<"$need")"
  for ((at = 0; at < n; at += BATCH)); do
    batch="$(jq -c --argjson t "$texts" --argjson a "$at" --argjson b "$BATCH" '
      .[$a:$a + $b] | map($t[.] // {key: .}) | map(del(.updated))' <<<"$need")"
    if verdicts="$(classify "$digest" "$batch")" || verdicts="$(classify "$digest" "$batch")"; then
      classes="$(jq -c --argjson v "$verdicts" --argjson t "$texts" '
        reduce $v[] as $x (.; .[$x.key] = {areas: $x.areas, why: $x.why, updated: ($t[$x.key].updated // "")})' <<<"$classes")"
      printf '%s\n' "$classes" >"$dir/classes.json"
    fi
  done

  # Nothing sorted at all is Claude failing, not a quiet board: say so, and
  # keep the last snapshot so the next run still compares with it.
  if [ "$n" -gt 0 ] && [ "$(jq --argjson c "$classes" '[.[] | select($c[.Key])] | length' <<<"$rows")" -eq 0 ]; then
    notify "$key" "Jira digest $key failed" "Claude sorted none of the tickets: see $stateroot/claude.err"
    return 1
  fi

  prev="$(cat "$dir/snapshot.json" 2>/dev/null || echo 'null')"
  prevdate="$(cat "$dir/snapshot.date" 2>/dev/null || true)"
  mkdir -p "$folder"
  jq -r --argjson c "$classes" --argjson prev "$prev" --argjson d "$digest" \
    --arg key "$key" --arg today "$today" --arg prevdate "$prevdate" --arg server "$(jira-board sites | jq -r --arg s "$site" '.[] | select(.site == $s) | .server')" '
    def cell: tostring | gsub("\\|"; "/") | gsub("[\n\r\t]"; " ");
    def link: "[\(.Key)](\($server)/browse/\(.Key))";
    def est: if .["Original estimate"] == "" and .Remaining == "" then "–" else "\(.Remaining | if . == "" then "?" else . end) / \(.["Original estimate"] | if . == "" then "?" else . end)" end;
    def rank: {"Highest": 0, "Rápido": 0, "High": 1, "Medium": 2, "Low": 3, "Lowest": 4}[.Priority] // 2;
    def areas: $c[.Key].areas // null;
    def tags: (areas // []) | map(. as $a | ($d.areas[] | select(.id == $a) | .short // .id)) | join(", ");
    def relevant: (areas // []) | length > 0;
    def table(rows; extra):
      if (rows | length) == 0 then "_None._" else
        "| Ticket | Title | Where | Status | Priority | Assignee | Age | Left / est. | \(extra) |",
        "|---|---|---|---|---|---|---|---|---|",
        (rows | sort_by(rank, -((.["Age (days)"] | tonumber? ) // 0))[] |
          "| \(link) | \(.Summary | cell) | \(.Where | cell) | \(.Status | cell) | \(.Priority | cell) | \(.Assignee | cell) | \(.["Age (days)"])d | \(est) | \((if extra == "Why" then ($c[.Key].why // "") else tags end) | cell) |")
      end;
    (($prev // []) | map({key: .Key, value: .}) | from_entries) as $before |
    [.[] | select(relevant)] as $mine |
    [$mine[] | select($prev != null and ($before[.Key] == null))] as $new |
    [$mine[] | select($before[.Key] != null) | . as $r | $before[.Key] as $b |
      [("Where", "Status", "Priority", "Assignee", "Remaining") | select($r[.] != $b[.]) | "\(.): \($b[.] | if . == "" then "–" else . end) → \($r[.] | if . == "" then "–" else . end)"] as $ch |
      select($ch | length > 0) | . + {changes: ($ch | join("; "))}] as $changed |
    [.[] | select(areas == null)] as $unsorted |
    "# \($key) digest · \($today)",
    "",
    "\(length) tickets on the board and in its backlog; \($mine | length) touch \([$d.areas[].label] | join(" or ")).",
    (if $prev == null then "First digest: nothing to compare with yet." else "Compared with \($prevdate)." end),
    (if ($unsorted | length) > 0 then "\($unsorted | length) tickets could not be sorted this time and are left out; the next run tries them again." else empty end),
    "",
    (if $prev != null then
      "## New since \($prevdate)", "", table($new; "Part"), "",
      "## Changed since \($prevdate)", "",
      (if ($changed | length) == 0 then "_None._" else
        "| Ticket | Title | Part | What changed |", "|---|---|---|---|",
        ($changed[] | "| \(link) | \(.Summary | cell) | \(tags) | \(.changes | cell) |") end), ""
    else empty end),
    ($d.areas[] as $a |
      "## \($a.label)", "",
      table([$mine[] | select((areas // []) | index($a.id))]; "Why"), "")
  ' <<<"$rows" >"$note.tmp" && mv -f "$note.tmp" "$note"

  printf '%s\n' "$rows" >"$dir/snapshot.json"
  echo "$today" >"$dir/snapshot.date"
  notify "$key" "Jira digest $key" "$(grep -m1 'touch' "$note")" \
    "obsidian://open?path=$(jq -rn --arg p "$note" '$p | @uri')"
  echo "$note"
}

status=0
while IFS= read -r digest; do
  [ -z "$only" ] || [ "$(jq -r .key <<<"$digest")" = "$only" ] || continue
  digest_one "$digest" || status=1
done < <(jq -c '.digests[]' "$conf")
# Only a run that wrote every note counts as the day's, so the 9:40 run still
# tries after a failed one.
[ "$status" -ne 0 ] || echo "$today" >"$stateroot/last-run"
exit "$status"
