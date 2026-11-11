
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

Pull and merge requests opened with `gh pr create`, `glab mr create` or
`df mr-generate` are opened in tuicr automatically by a hook, which reports the
URL and the tab's handle back as context. Do not launch a second tuicr for
them. Wait for the user, then read the PR session's comments as described in
**Read User Comments**; its slug (such as `gh:owner/repo/pr/N`) comes from
`tuicr review list --repo /path/to/repo`.
