#!/usr/bin/env bash
# tuicr-prs: pick one of this repository's open pull or merge requests and
# review it in tuicr; leaving tuicr comes back to the list.
set -u -o pipefail

if [[ "${1:-}" == "--list" ]]; then
  remote="$(git remote get-url origin 2>/dev/null)" || exit 1
  case "$remote" in
    *github.com*)
      gh pr list --limit 100 --json number,title,author,headRefName,isDraft,reviewDecision \
        --jq '.[] | ["#\(.number)", ((if .isDraft then "[draft] " else "" end) + .title), "@\(.author.login)", .headRefName, (.reviewDecision // "" | ascii_downcase | gsub("_"; " "))] | @tsv'
      ;;
    *)
      glab mr list --per-page 100 -F json \
        | jq -r '.[] | ["!\(.iid)", ((if .draft then "[draft] " else "" end) + .title), "@\(.author.username)", .source_branch, (.detailed_merge_status // "" | gsub("_"; " "))] | @tsv'
      ;;
  esac
  exit
fi

cd "${1:-$PWD}" || exit 1
if ! git remote get-url origin >/dev/null 2>&1; then
  echo "Not a git repository with an origin remote: $PWD" >&2
  exit 1
fi

self="$(command -v tuicr-prs || printf '%s' "$0")"
while true; do
  pick="$("$self" --list | fzf --delimiter=$'\t' --prompt='PRs > ' --layout=reverse \
    --header='enter: review in tuicr · ctrl-r: reload · esc: quit' \
    --bind "ctrl-r:reload($self --list)")" || break
  number="$(cut -f1 <<<"$pick" | tr -d '#!')"
  [[ -n "$number" ]] && tuicr pr "$number"
done
