
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
Herdr desktop pane, a herdr-core terminal. A review opens as a new tab in your
own space, named so the user can find it with Cmd+P, and takes the focus:
`diff · <branch>` for the working tree, `#<number> <title>` for a pull request
(`!<iid> <title>` for a GitLab merge request).

```bash
space="$(hc get "$HC_TERMINAL_ID" --json | jq -r '.labels["herdr.space"]')"
title="diff · $(git -C /path/to/repo branch --show-current)"
t="$(herdr-app do tab.new --space "$space" --name "$title" --folder /path/to/repo \
  --argv '["tuicr","-w"]' | jq -r .terminal)"
```

If `herdr-app` is missing or fails (the agent runs on another machine than the
window), start it as a new tab of your space through herdr-core instead; Herdr
names that tab itself:

```bash
t="$(hc run --bg --json --no-parent --no-notify --rm --cwd /path/to/repo \
  --label "herdr.space=$space" --label "herdr.tab=tbreview$(date +%s)" -- tuicr -w | jq -r .address)"
```

Label your own terminal so the agents list links the review to you (and, for a
pull request, shows a PR pill with its CI state):
`hc label "$HC_TERMINAL_ID" review.terminal=$t "review.title=$title"`, plus
`review.url=<url>` for a pull request. The user reaches it again with Cmd+P by
its title, or Cmd+Shift+R from your row; close it with `hc kill $t`.

## Pull requests open by themselves

Pull and merge requests opened with `gh pr create`, `glab mr create` or
`df mr-generate` are opened in tuicr automatically by a hook: in a split of
the agent's own pane inside the Herdr TUI (`$HERDR_ENV` is `1`), in a new,
focused tab named after the request inside Herdr desktop (`$HC_TERMINAL_ID`
set, with the labels described above), in a new tab inside Orca. The hook reports the URL
and the pane id, terminal or tab handle back as context.
Do not launch a second tuicr for them. Wait for the user, then read the PR
session's comments as described in **Read User Comments**; its slug (such as
`gh:owner/repo/pr/N`) comes from `tuicr review list --repo /path/to/repo`.
