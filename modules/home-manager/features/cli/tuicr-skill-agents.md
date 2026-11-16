
## Orca

When `$ORCA_AGENT_SESSION_ID` is set the agent runs inside Orca, which has no
split pane to borrow, so tuicr opens in a new terminal tab of the worktree:

```bash
<skill-directory>/tuicr-wrapper-orca.sh /path/to/repo -- -w
<skill-directory>/tuicr-wrapper-orca.sh /path/to/repo -- pr <url>
```

Like the cmux wrapper it returns at once and prints the tab's handle between
`=== TUICR TERMINAL ===` markers. Close the tab with
`orca terminal close --terminal <handle>`; it also closes itself when tuicr
exits cleanly, and stays open showing the error when tuicr fails.

## Herdr desktop

When `$HC_TERMINAL_ID` is set (and `$HERDR_ENV` is not) the agent runs in a
Herdr desktop pane, a herdr-core terminal. Open tuicr as a new pane in the
agent's own tab by giving it the same `herdr.space` and `herdr.tab` labels, then
focus it so the user sees it at once:

```bash
info="$(hc get "$HC_TERMINAL_ID" --json)"
space="$(jq -r '.labels["herdr.space"]' <<<"$info")"
tab="$(jq -r '.labels["herdr.tab"]' <<<"$info")"
t="$(hc run --bg --json --no-parent --no-notify --rm --cwd /path/to/repo \
  --label "herdr.space=$space" --label "herdr.tab=$tab" -- tuicr pr <url> | jq -r .address)"
herdr-app do pane.focus --terminal "$t"
```

For a pull or merge request, also label your own terminal so the agents list
shows a PR pill with its CI state (passing, running, failing) beside your row:
`hc label "$HC_TERMINAL_ID" review.url=<url> review.terminal=$t`. Bring the
review back to the front with `herdr-app do pane.focus --terminal $t`; close it
with `hc kill $t`.

## Pull requests open by themselves

Pull and merge requests opened with `gh pr create`, `glab mr create` or
`df mr-generate` are opened in tuicr automatically by a hook: in a split of
the agent's own pane inside the Herdr TUI (`$HERDR_ENV` is `1`), in a focused
pane of the agent's tab inside Herdr desktop (`$HC_TERMINAL_ID` set, with the
PR label described above), in a new tab inside Orca. The hook reports the URL
and the pane id, terminal or tab handle back as context.
Do not launch a second tuicr for them. Wait for the user, then read the PR
session's comments as described in **Read User Comments**; its slug (such as
`gh:owner/repo/pr/N`) comes from `tuicr review list --repo /path/to/repo`.
