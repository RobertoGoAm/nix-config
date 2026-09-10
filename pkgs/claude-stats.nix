# Reports what Claude Code has actually been doing, from its own...

# Reports what Claude Code has actually been doing, from its own transcripts.

# Claude Code writes every session to =~/.claude/projects= as JSONL, and that
# file records far more than the conversation: the token usage of each request,
# every tool call and its result, the instruction files injected into the run,
# each hook firing with its exit code and duration, and -- in
# =<session>/subagents/= -- a transcript per subagent with a sidecar naming its
# type. Nothing aggregates any of it, so nothing answers the questions worth
# asking about a setup this size: which skills earn their place, which rules are
# being carried at what price, which hooks are quietly failing.

# This does. It is deliberately one file of standard-library Python with no
# configuration and no network call, so it can be handed to a colleague and run
# on their machine as-is:

#   #+begin_example
#   nix run github:RobertoGoAm/nix-config#claude-stats -- --since 7d
#   curl -O https://raw.githubusercontent.com/RobertoGoAm/nix-config/master/pkgs/claude-stats.py
#   #+end_example

# Three things it can say that no other surface can. A skill's cost is split
# between the instructions it loads and the tokens the turns after it spend,
# which is the difference between a skill that is expensive to consult and one
# that directs expensive work. A skill installed but never invoked is still
# listed in the catalogue injected into every session, so the report prices the
# ones that were never reached. And a hook's error rate is counted from the
# attachment the CLI records for each firing, which is how a hook that has been
# failing for a thousand invocations stops being invisible.

# A command proxy is read the two ways it hides. Where Claude types =rtk git
# status= the shell table would answer "rtk" and say nothing about what ran, so
# wrappers -- rtk, sudo, env, timeout and the rest -- are looked through to the
# verb underneath. Where the proxy's =PreToolUse= hook rewrites the command
# instead, the tool call in the transcript still shows the original, so the
# rewrite is taken from the hook's own output, where
# =hookSpecificOutput.updatedInput= records what will really run. Each rewritten
# call is remembered by its tool-use id, and the result it returns is counted
# apart from the results of the calls the hook left alone -- which gives a
# per-verb comparison of proxied against plain. The hook chooses which calls to
# rewrite and it chooses the ones with big output, so that comparison is reported
# as a signal about where the proxy is pointed, not as a measurement.

# Attribution is honest about its two estimates: a payload's own token count is
# never recorded, so sizes are taken at four characters to the token, and the
# money column is list API prices applied to the tokens that were recorded --
# what the work would have cost, not what a subscription was billed.

{
  lib,
  writeShellApplication,
  python3,
}:
writeShellApplication {
  name = "claude-stats";

  runtimeInputs = [ python3 ];

  # Every argument through: the script takes --since/--project/--top plus

  # --html/--json.

  text = ''
    exec python3 "${./claude-stats.py}" "$@"
  '';

  meta = {
    description = "Aggregate Claude Code transcripts into tool, skill, rule and agent metrics";
    mainProgram = "claude-stats";
    platforms = lib.platforms.all;
  };
}
