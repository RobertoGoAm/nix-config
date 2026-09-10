"""claude-stats -- what Claude Code has actually been doing.

Reads the transcripts Claude Code writes under ~/.claude/projects and reports
which tools, skills, subagents, hooks and standing instructions were used over
a window, what each cost in tokens and wall time, and which of the skills
installed on this machine were never reached at all.

Standard library only, one file, no configuration: copy it anywhere a colleague
has Claude Code and it reports on their own machine. Nothing leaves the
machine -- there is no network call in here.

  claude-stats                      the last 30 days
  claude-stats --since 7d --top 10
  claude-stats --since all --project nix-config
  claude-stats --html report.html   a page to hand round
  claude-stats --json               the same numbers for a dashboard

Rereading a gigabyte of JSONL on every run would be rude, so each file is
remembered by the byte offset already folded in, and a second run only parses
what was appended since.
"""

import argparse
import datetime
import html
import json
import os
import pathlib
import re
import sys

ROOT = pathlib.Path.home() / ".claude" / "projects"
CLAUDE = pathlib.Path.home() / ".claude"
CACHE = pathlib.Path(
    os.environ.get("XDG_CACHE_HOME", pathlib.Path.home() / ".cache")
) / "claude-stats"
STATE = CACHE / "state.json"

# Bumped whenever the shape of a bucket changes, which throws the cache away
# rather than adding numbers counted one way to numbers counted another.
VERSION = 5

# USD per million tokens: input, output, cache write, cache read. Keyed by
# family rather than by model id, because a dated id arrives with every release
# and the price does not move with it. An id matching nothing is reported as
# unpriced instead of silently costing zero. These are list API prices: on a
# subscription they say what the work would have cost, not what was paid.
RATES = {
    "opus": (15.0, 75.0, 18.75, 1.50),
    "sonnet": (3.0, 15.0, 3.75, 0.30),
    "haiku": (0.80, 4.0, 1.0, 0.08),
    "fable": (3.0, 15.0, 3.75, 0.30),
}

# No transcript records the token count of an individual payload -- only the
# tokens of the request that carried it, and one request carries many. Four
# characters to a token is the usual rule of thumb, and it is used here only
# for sizes that are compared against each other.
CHARS_PER_TOKEN = 4

TOKEN_KEYS = (
    ("in", "input_tokens"),
    ("out", "output_tokens"),
    ("cw", "cache_creation_input_tokens"),
    ("cr", "cache_read_input_tokens"),
)

# Slash commands the CLI itself owns. They are not skills, and counting them as
# such buries the skills under /exit and /compact.
BUILTINS = {
    "exit", "quit", "clear", "compact", "resume", "model", "mcp", "help",
    "config", "cost", "usage", "status", "login", "logout", "agents", "init",
    "review", "vim", "terminal-setup", "doctor", "bug", "release-notes",
    "add-dir", "memory", "permissions", "hooks", "export", "privacy-settings",
    "statusline", "todos", "tasks", "artifacts", "feedback", "fast",
}

# Attachments that exist to carry standing context into the conversation. The
# rest -- file reads, edit snippets, token reminders -- are work, not overhead.
CONTEXT_KINDS = {
    "skill_listing": "skill catalogue",
    "deferred_tools_delta": "deferred tool list",
    "agent_listing_delta": "agent listing",
    "mcp_instructions_delta": "MCP instructions",
    "environment": "environment",
    "session_context": "session context",
    "task_reminder": "task reminders",
    "auto_mode": "auto mode",
    "compact_file_reference": "compaction handover",
}

COMMAND = re.compile(r"<command-name>(/[A-Za-z0-9:_-]+)</command-name>")
# The line a skill's instructions arrive under. That message is addressed to
# Claude but written by the CLI, so it must not be mistaken for a person
# typing -- which would end the very skill it is starting.
SKILL_BODY = "Base directory for this skill:"
STORE_PATH = re.compile(r"/nix/store/[a-z0-9]{32}-")
WHITESPACE = re.compile(r"\s+")


# --------------------------------------------------------------------------
# Reading
# --------------------------------------------------------------------------

def family(model):
    for name in RATES:
        if name in (model or ""):
            return name
    return None


def cost_of(tokens, model):
    rates = RATES.get(family(model))
    if rates is None:
        return None
    return sum(
        tokens.get(key, 0) * rate / 1_000_000
        for (key, _), rate in zip(TOKEN_KEYS, rates)
    )


def local_date(stamp):
    try:
        when = datetime.datetime.fromisoformat(str(stamp).replace("Z", "+00:00"))
    except (TypeError, ValueError):
        return None
    return when.astimezone().date().isoformat()


def text_of(content):
    """Every string inside a message's content, concatenated."""
    if isinstance(content, str):
        return content
    if not isinstance(content, list):
        return ""
    out = []
    for block in content:
        if isinstance(block, str):
            out.append(block)
        elif isinstance(block, dict):
            for key in ("text", "content"):
                value = block.get(key)
                if isinstance(value, str):
                    out.append(value)
                elif isinstance(value, list):
                    out.append(text_of(value))
    return "\n".join(out)


def blocks_of(entry):
    content = entry.get("message", {}).get("content")
    if not isinstance(content, list):
        return []
    return [block for block in content if isinstance(block, dict)]


def tokens_of(text):
    return len(text or "") // CHARS_PER_TOKEN


def short_path(path):
    return str(path).replace(str(pathlib.Path.home()), "~")


def bash_verb(command):
    """The command a Bash call is really about.

    Auto mode prefixes a `cd` on to almost everything and the shell snapshot
    exports a page of variables, so the first word of the line is nearly always
    one of three answers. The interesting verb is the first one that is not
    plumbing.
    """
    plumbing = {"cd", "export", "source", ".", "set", "setopt", "eval", "true", "builtin"}
    for piece in re.split(r"&&|\|\||;|\|", command):
        words = piece.strip().split()
        if not words:
            continue
        verb = os.path.basename(words[0].strip("(){}$"))
        if verb and verb not in plumbing:
            return verb[:24]
    return "?"


def hook_label(attachment):
    name = attachment.get("hookName") or attachment.get("hookEvent") or "?"
    command = STORE_PATH.sub("", str(attachment.get("command") or ""))
    command = WHITESPACE.sub(" ", command).strip()
    return "%s  %s" % (name, command[:44]) if command else str(name)


def empty_day():
    return {
        "models": {},
        "agent_models": {},
        "tools": {},
        "agent_tools": {},
        "bash": {},
        "skills": {},
        "commands": {},
        "agents": {},
        "hooks": {},
        "rules": {},
        "context": {},
        "catalogue": {},
        "prompts": 0,
        "api_errors": 0,
        "compactions": 0,
        "duration_ms": 0,
        "sessions": [],
    }


def bump(bucket, key, **fields):
    row = bucket.setdefault(key, {})
    for name, value in fields.items():
        row[name] = row.get(name, 0) + value
    return row


def add_tokens(bucket, model, usage):
    row = bucket.setdefault(model, {})
    for key, field in TOKEN_KEYS:
        row[key] = row.get(key, 0) + (usage.get(field) or 0)
    row["msgs"] = row.get("msgs", 0) + 1


def merge(into, extra):
    for key, value in extra.items():
        if isinstance(value, dict):
            merge(into.setdefault(key, {}), value)
        elif isinstance(value, list):
            into[key] = sorted(set(into.get(key, [])) | set(value))
        else:
            into[key] = into.get(key, 0) + value


def parse(chunk, days, state, agent_type, installed):
    """Fold one chunk of one transcript into per-day buckets.

    STATE carries across the chunk boundary what a single pass would otherwise
    lose: which skill is in play, which tool calls are still waiting for their
    result, and which API requests have already been counted.
    """
    pending = state.setdefault("pending", {})
    counted = state.setdefault("counted", [])

    for line in chunk.splitlines():
        if not line.strip():
            continue
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        day = local_date(entry.get("timestamp"))
        if day is None:
            continue
        bucket = days.setdefault(day, empty_day())
        session = entry.get("sessionId")
        if session and session not in bucket["sessions"]:
            bucket["sessions"].append(session)

        kind = entry.get("type")
        if kind == "assistant":
            fold_assistant(entry, bucket, state, agent_type, pending, counted)
        elif kind == "user":
            fold_user(entry, bucket, state, agent_type, pending, installed)
        elif kind == "attachment":
            fold_attachment(entry.get("attachment") or {}, bucket)
        elif kind == "system":
            fold_system(entry, bucket, state)

    # A tool call whose result never arrives, and a request id from an hour
    # ago, would otherwise be kept for ever and travel into the cache.
    if len(pending) > 64:
        state["pending"] = dict(list(pending.items())[-64:])
    if len(counted) > 32:
        state["counted"] = counted[-32:]


def fold_assistant(entry, bucket, state, agent_type, pending, counted):
    message = entry.get("message") or {}
    usage = message.get("usage") or {}
    model = message.get("model") or "unknown"

    # One API response is written as several entries -- one per content block --
    # each repeating the same usage. Counting per entry inflates every token
    # number by however many blocks the answer happened to have.
    request = entry.get("requestId")
    fresh = request is None or request not in counted
    if request is not None:
        counted.append(request)

    skill = state.get("skill")
    if fresh:
        add_tokens(
            bucket["agent_models"] if agent_type else bucket["models"], model, usage
        )
        if agent_type:
            bump(bucket["agents"], agent_type, turns=1)
        if skill:
            bump(bucket["skills"], skill, **{
                key: (usage.get(field) or 0) for key, field in TOKEN_KEYS
            })

    where = "agent_tools" if agent_type else "tools"
    for block in blocks_of(entry):
        if block.get("type") != "tool_use":
            continue
        name = block.get("name") or "?"
        args = block.get("input") if isinstance(block.get("input"), dict) else {}
        bump(bucket[where], name, calls=1)
        if block.get("id"):
            pending[block["id"]] = name
        if skill:
            bump(bucket["skills"], skill, tool_calls=1)
        if name == "Bash":
            bump(bucket["bash"], bash_verb(str(args.get("command", ""))), calls=1)
        elif name == "Skill":
            asked = str(args.get("skill") or "?")
            bump(bucket["skills"], asked, calls=1)
            state["skill"] = asked
        elif name in ("Agent", "Task"):
            bump(
                bucket["agents"], str(args.get("subagent_type") or "general-purpose"),
                calls=1, prompt_tokens=tokens_of(str(args.get("prompt", ""))),
            )


def fold_user(entry, bucket, state, agent_type, pending, installed):
    results = [b for b in blocks_of(entry) if b.get("type") == "tool_result"]
    where = "agent_tools" if agent_type else "tools"
    for block in results:
        name = pending.pop(block.get("tool_use_id"), None) or "?"
        body = text_of(block.get("content"))
        bump(
            bucket[where], name,
            result_tokens=tokens_of(body),
            errors=1 if block.get("is_error") else 0,
        )
        if state.get("skill"):
            if name == "Skill":
                bump(bucket["skills"], state["skill"], load_tokens=tokens_of(body))
            elif block.get("is_error"):
                bump(bucket["skills"], state["skill"], tool_errors=1)

    text = text_of(entry.get("message", {}).get("content"))
    names = COMMAND.findall(text)
    carries_skill = SKILL_BODY in text
    if carries_skill and state.get("skill"):
        # The instructions themselves, which is what a skill costs before it
        # has done anything at all.
        bump(bucket["skills"], state["skill"], load_tokens=tokens_of(text))
    if not results and not names and not carries_skill:
        bucket["prompts"] += 1
        # A prompt from a person ends whatever the last skill was doing.
        state["skill"] = None
    for name in names:
        bare = name.lstrip("/")
        bump(bucket["commands"], name, calls=1)
        # A slash command is how a skill is usually reached. Only names that
        # exist as skills on this machine are counted as one; /exit is a
        # command and nothing more.
        if bare in installed and bare not in BUILTINS:
            bump(bucket["skills"], bare, calls=1, load_tokens=tokens_of(text))
            state["skill"] = bare


def fold_attachment(attachment, bucket):
    kind = attachment.get("type")

    if kind == "instructions":
        # The standing instruction files, each with its own weight. This is the
        # only place a CLAUDE.md is ever priced.
        for item in attachment.get("files") or []:
            bump(
                bucket["rules"], short_path(item.get("path") or "?"),
                injections=1, tokens=tokens_of(item.get("content") or ""),
            )
        return

    if kind == "skill_listing":
        size = tokens_of(attachment.get("content") or "")
        bump(
            bucket["catalogue"], "skill_listing",
            injections=1, tokens=size, skills=attachment.get("skillCount") or 0,
        )
        bump(bucket["context"], CONTEXT_KINDS[kind], injections=1, tokens=size)
        return

    if kind in CONTEXT_KINDS:
        # Some of these carry their text in `content`, others hand over a
        # structure -- a tool list, an agent listing -- whose serialised size is
        # the closest thing to what it will cost in the window.
        payload = attachment.get("content")
        if not isinstance(payload, str) or not payload:
            payload = json.dumps(
                {k: v for k, v in attachment.items() if k != "type"}, default=str
            )
        bump(bucket["context"], CONTEXT_KINDS[kind], injections=1, tokens=tokens_of(payload))
        return

    if kind and kind.startswith(("hook_", "async_hook")):
        failed = kind in ("hook_non_blocking_error", "hook_blocking_error")
        bump(
            bucket["hooks"], hook_label(attachment),
            fired=1,
            errors=1 if failed else 0,
            blocked=1 if kind == "hook_blocking_error" else 0,
            duration_ms=attachment.get("durationMs") or 0,
            out_tokens=tokens_of(
                str(attachment.get("stdout") or "") + str(attachment.get("content") or "")
            ),
        )


def fold_system(entry, bucket, state):
    subtype = entry.get("subtype")
    if subtype == "turn_duration":
        spent = entry.get("durationMs") or 0
        bucket["duration_ms"] += spent
        if state.get("skill"):
            bump(bucket["skills"], state["skill"], duration_ms=spent)
    elif subtype == "api_error":
        bucket["api_errors"] += 1
    elif subtype == "compact_boundary":
        bucket["compactions"] += 1


def agent_type_of(path):
    """Which kind of subagent a transcript belongs to, None for a main session."""
    if path.parent.name != "subagents":
        return None
    meta = path.parent / (path.name[: -len(".jsonl")] + ".meta.json")
    try:
        with meta.open() as handle:
            return json.load(handle).get("agentType") or "unknown"
    except (OSError, ValueError):
        return "unknown"


def skills_on_disk():
    """Every skill and command installed for this user, by name."""
    names = set()
    for root in (CLAUDE / "skills", CLAUDE / "plugins"):
        if root.is_dir():
            for skill in root.rglob("SKILL.md"):
                names.add(skill.parent.name)
    if (CLAUDE / "commands").is_dir():
        for command in (CLAUDE / "commands").rglob("*.md"):
            names.add(command.stem)
    return names


def scan(use_cache=True):
    """Every transcript folded into per-day buckets, reading only new bytes."""
    try:
        with STATE.open() as handle:
            state = json.load(handle)
    except (OSError, ValueError):
        state = {}
    if state.get("version") != VERSION or not use_cache:
        state = {"version": VERSION, "files": {}}
    files = state.setdefault("files", {})
    installed = skills_on_disk()

    for path in (sorted(ROOT.rglob("*.jsonl")) if ROOT.is_dir() else []):
        name = str(path)
        try:
            size = path.stat().st_size
        except OSError:
            continue
        record = files.get(name)
        if record is None or record.get("offset", 0) > size:
            record = {"offset": 0, "days": {}, "state": {}}
        if record["offset"] == size:
            files[name] = record
            continue
        try:
            with path.open("rb") as handle:
                handle.seek(record["offset"])
                data = handle.read()
        except OSError:
            continue
        # Only whole lines: the file may be mid-write.
        cut = data.rfind(b"\n")
        if cut == -1:
            files[name] = record
            continue
        parse(
            data[: cut + 1].decode("utf-8", "replace"),
            record["days"], record.setdefault("state", {}),
            agent_type_of(path), installed,
        )
        record["offset"] += cut + 1
        files[name] = record

    if use_cache:
        try:
            CACHE.mkdir(parents=True, exist_ok=True)
            tmp = STATE.with_suffix(".tmp")
            with tmp.open("w") as handle:
                json.dump(state, handle)
            tmp.replace(STATE)
        except OSError:
            pass
    return files


def collect(files, since, project):
    total = empty_day()
    days = set()
    for name, record in files.items():
        if project and project not in name:
            continue
        for day, bucket in record["days"].items():
            if since and day < since:
                continue
            days.add(day)
            merge(total, bucket)
    total["days"] = sorted(days)
    return total


# --------------------------------------------------------------------------
# Shaping
# --------------------------------------------------------------------------

def token_sum(models):
    total = {"msgs": 0}
    for key, _ in TOKEN_KEYS:
        total[key] = 0
    for row in models.values():
        for key, _ in TOKEN_KEYS:
            total[key] += row.get(key, 0)
        total["msgs"] += row.get("msgs", 0)
    return total


def spend(models):
    priced, unpriced = 0.0, 0
    for model, row in models.items():
        value = cost_of(row, model)
        if value is None:
            unpriced += sum(row.get(key, 0) for key, _ in TOKEN_KEYS)
        else:
            priced += value
    return priced, unpriced


def money(value):
    return "-" if value is None else "$%.2f" % value


def compact(value):
    value = float(value)
    for unit, size in (("M", 1_000_000), ("k", 1_000)):
        if abs(value) >= size:
            return "%.1f%s" % (value / size, unit)
    return "%d" % round(value)


def clock(millis):
    minutes = round((millis or 0) / 60000)
    return "%dm" % minutes if minutes < 90 else "%dh%02dm" % (minutes // 60, minutes % 60)


def rate(part, whole):
    return "%d%%" % round(100 * part / whole) if whole else "-"


def sections(total, args):
    """Every table the report can show, as (title, headers, rows, note)."""
    out = []
    wanted = args.sections

    if "models" in wanted:
        rows = []
        for model, row in sorted(total["models"].items(), key=lambda kv: -kv[1].get("msgs", 0)):
            rows.append([
                model, compact(row.get("msgs", 0)), compact(row.get("in", 0)),
                compact(row.get("out", 0)), compact(row.get("cw", 0)),
                compact(row.get("cr", 0)), money(cost_of(row, model)),
            ])
        out.append((
            "Models", ["model", "turns", "in", "out", "cache write", "cache read", "list price"],
            rows, "",
        ))

    if "tools" in wanted:
        for title, key in (("Tools", "tools"), ("Tools inside subagents", "agent_tools")):
            rows = []
            for name, row in sorted(total[key].items(), key=lambda kv: -kv[1].get("calls", 0)):
                calls = row.get("calls", 0)
                rows.append([
                    name, compact(calls), rate(row.get("errors", 0), calls),
                    compact(row.get("result_tokens", 0)),
                    compact(row.get("result_tokens", 0) / calls) if calls else "-",
                ])
            out.append((
                title, ["tool", "calls", "errors", "result tokens", "per call"], rows,
                "Result tokens are what each tool's output added to the conversation.",
            ))
        rows = [
            [verb, compact(row.get("calls", 0))]
            for verb, row in sorted(total["bash"].items(), key=lambda kv: -kv[1].get("calls", 0))
        ]
        out.append((
            "Shell commands", ["command", "calls"], rows,
            "The first non-plumbing verb of each Bash call.",
        ))

    if "skills" in wanted:
        rows = []
        for name, row in sorted(
            total["skills"].items(), key=lambda kv: (-kv[1].get("calls", 0), kv[0])
        ):
            after = sum(row.get(key, 0) for key, _ in TOKEN_KEYS)
            rows.append([
                name, compact(row.get("calls", 0)), compact(row.get("load_tokens", 0)),
                compact(after), clock(row.get("duration_ms", 0)),
                compact(row.get("tool_calls", 0)), compact(row.get("tool_errors", 0)),
            ])
        out.append((
            "Skills used",
            ["skill", "runs", "load tokens", "tokens after", "time", "tools", "tool errors"],
            rows,
            "Load tokens are the instructions themselves; tokens after are what the turns "
            "following the invocation spent, which is the work the skill directed.",
        ))

        idle = sorted(skills_on_disk() - set(total["skills"]) - BUILTINS)
        catalogue = total["catalogue"].get("skill_listing", {})
        listings = catalogue.get("injections", 0)
        # `skills` is the running sum of skillCount over every injection, so
        # dividing the summed size by it gives the cost of one skill being
        # listed once -- the number an unused skill is charged, every session.
        each = catalogue.get("tokens", 0) / catalogue["skills"] if catalogue.get("skills") else 0
        out.append((
            "Skills never used in this window", ["skill"], [[name] for name in idle],
            "The catalogue was injected %s time(s), %s tokens each time, about %s tokens per "
            "skill listed -- so these %d were carried for roughly %s tokens over the window "
            "without being reached once."
            % (compact(listings), compact(catalogue.get("tokens", 0) / listings),
               compact(each), len(idle), compact(each * len(idle) * listings))
            if listings else "No skill catalogue was recorded in this window.",
        ))

    if "commands" in wanted:
        rows = [
            [name, compact(row.get("calls", 0))]
            for name, row in sorted(
                total["commands"].items(), key=lambda kv: -kv[1].get("calls", 0)
            )
        ]
        out.append(("Slash commands", ["command", "uses"], rows, ""))

    if "agents" in wanted:
        rows = []
        for name, row in sorted(total["agents"].items(), key=lambda kv: -kv[1].get("calls", 0)):
            calls = row.get("calls", 0)
            rows.append([
                name, compact(calls), compact(row.get("turns", 0)),
                compact(row.get("turns", 0) / calls) if calls else "-",
                compact(row.get("prompt_tokens", 0)),
            ])
        out.append((
            "Subagents", ["agent", "runs", "turns", "turns per run", "brief tokens"], rows,
            "Runs are counted where they were asked for and turns where they happened, so a "
            "run spawned before this window still shows its turns.",
        ))

    if "rules" in wanted:
        for title, key, note in (
            ("Standing instructions", "rules",
             "Every CLAUDE.md and imported rule file, priced. Nothing records whether a rule "
             "was obeyed -- this is what carrying it costs, which is the half worth pruning."),
            ("Other standing context", "context", ""),
        ):
            rows = []
            for name, row in sorted(total[key].items(), key=lambda kv: -kv[1].get("tokens", 0)):
                times = row.get("injections", 0)
                rows.append([
                    name, compact(times), compact(row.get("tokens", 0)),
                    compact(row.get("tokens", 0) / times) if times else "-",
                ])
            out.append((title, ["block", "injections", "tokens", "per injection"], rows, note))

        rows = []
        for name, row in sorted(total["hooks"].items(), key=lambda kv: -kv[1].get("fired", 0)):
            fired = row.get("fired", 0)
            rows.append([
                name, compact(fired), compact(row.get("errors", 0)),
                rate(row.get("errors", 0), fired), clock(row.get("duration_ms", 0)),
                compact(row.get("out_tokens", 0)),
            ])
        out.append((
            "Hooks", ["hook", "fired", "errors", "error rate", "time", "output tokens"], rows,
            "The enforcement half of the rules: what actually ran, how often it failed, and "
            "how much it said back into the conversation.",
        ))

    return out


def headline(total, args):
    main, agents = token_sum(total["models"]), token_sum(total["agent_models"])
    main_cost, main_unpriced = spend(total["models"])
    agent_cost, agent_unpriced = spend(total["agent_models"])
    return {
        "window": "%s to %s" % (total["days"][0], total["days"][-1]) if total["days"] else "no data",
        "days": len(total["days"]),
        "project": args.project or "",
        "prompts": total["prompts"],
        "sessions": len(total["sessions"]),
        "turns": main["msgs"],
        "agent_turns": agents["msgs"],
        "tokens": {key: main[key] + agents[key] for key, _ in TOKEN_KEYS},
        "cost": main_cost + agent_cost,
        "main_cost": main_cost,
        "agent_cost": agent_cost,
        "unpriced": main_unpriced + agent_unpriced,
        "duration_ms": total["duration_ms"],
        "api_errors": total["api_errors"],
        "compactions": total["compactions"],
    }


# --------------------------------------------------------------------------
# Printing
# --------------------------------------------------------------------------

def print_report(total, args):
    head = headline(total, args)
    print("\n\033[1mClaude Code, %s\033[0m  (%d active day(s)%s)" % (
        head["window"], head["days"],
        ", project %r" % head["project"] if head["project"] else "",
    ))
    print("  prompts %s   sessions %s   turns %s (+%s inside subagents)" % (
        compact(head["prompts"]), head["sessions"],
        compact(head["turns"]), compact(head["agent_turns"]),
    ))
    print("  tokens  in %s   out %s   cache write %s   cache read %s" % tuple(
        compact(head["tokens"][key]) for key, _ in TOKEN_KEYS
    ))
    print("  wall time %s   api errors %s   compactions %s" % (
        clock(head["duration_ms"]), compact(head["api_errors"]), compact(head["compactions"]),
    ))
    print("  list price %s  (sessions %s, subagents %s)%s" % (
        money(head["cost"]), money(head["main_cost"]), money(head["agent_cost"]),
        "   [%s tokens on models with no price here]" % compact(head["unpriced"])
        if head["unpriced"] else "",
    ))

    for title, headers, rows, note in sections(total, args):
        print("\n\033[1m%s\033[0m" % title)
        if note:
            print("\033[2m  %s\033[0m" % note)
        if not rows:
            print("  (none)")
            continue
        shown = rows[: args.top] if args.top else rows
        widths = [len(column) for column in headers]
        for row in shown:
            for index, cell in enumerate(row):
                widths[index] = max(widths[index], len(str(cell)))
        print("\033[2m  %s\033[0m" % "  ".join(
            ("%-*s" if index == 0 else "%*s") % (widths[index], column)
            for index, column in enumerate(headers)
        ))
        for row in shown:
            print("  " + "  ".join(
                ("%-*s" if index == 0 else "%*s") % (widths[index], cell)
                for index, cell in enumerate(row)
            ))
        if args.top and len(rows) > args.top:
            print("\033[2m  ... and %d more\033[0m" % (len(rows) - args.top))


HTML_HEAD = """<title>Claude Code usage</title>
<style>
  :root {
    color-scheme: light dark;
    --bg: #fbfbf9; --fg: #1a1a18; --dim: #6b6b66; --line: #e3e3de;
    --panel: #f2f2ee;
  }
  @media (prefers-color-scheme: dark) {
    :root { --bg: #16161a; --fg: #e8e8e4; --dim: #9a9a94;
            --line: #2c2c33; --panel: #1e1e24; }
  }
  body { margin: 0; background: var(--bg); color: var(--fg);
         font: 14px/1.55 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
  main { max-width: 62rem; margin: 0 auto; padding: 2.5rem 1.25rem 5rem; }
  h1 { font-size: 1.5rem; margin: 0 0 .25rem; }
  h2 { font-size: 1rem; margin: 2.5rem 0 .35rem; }
  p.note { color: var(--dim); margin: 0 0 .75rem; max-width: 46rem; }
  .panel { border: 1px solid var(--line); border-radius: .5rem;
           padding: 1rem 1.15rem; background: var(--panel); }
  .panel dl { display: grid; grid-template-columns: repeat(auto-fit, minmax(8rem, 1fr));
              gap: .75rem 1.5rem; margin: 0; }
  dt { color: var(--dim); font-size: .74rem; text-transform: uppercase; letter-spacing: .06em; }
  dd { margin: .1rem 0 0; font-size: 1.15rem; font-variant-numeric: tabular-nums; }
  .scroll { overflow-x: auto; }
  table { border-collapse: collapse; width: 100%; font-variant-numeric: tabular-nums; }
  th, td { padding: .35rem .6rem; border-bottom: 1px solid var(--line);
           text-align: right; white-space: nowrap; }
  th:first-child, td:first-child { text-align: left; font-variant-numeric: normal; }
  th { color: var(--dim); font-weight: 600; font-size: .8rem; }
  tbody tr:hover td { background: var(--panel); }
  footer { color: var(--dim); margin-top: 3rem; font-size: .82rem; max-width: 46rem; }
  code { background: var(--panel); padding: .1rem .3rem; border-radius: .25rem; }
</style>
"""


def write_html(total, args, path):
    head = headline(total, args)
    parts = [HTML_HEAD, "<main>", "<h1>Claude Code usage</h1>"]
    parts.append('<p class="note">%s &middot; %d active day(s)%s</p>' % (
        html.escape(head["window"]), head["days"],
        " &middot; project <code>%s</code>" % html.escape(head["project"])
        if head["project"] else "",
    ))
    parts.append('<div class="panel"><dl>')
    for label, value in (
        ("Prompts", compact(head["prompts"])),
        ("Sessions", str(head["sessions"])),
        ("Turns", compact(head["turns"])),
        ("Subagent turns", compact(head["agent_turns"])),
        ("Wall time", clock(head["duration_ms"])),
        ("Tokens out", compact(head["tokens"]["out"])),
        ("Cache read", compact(head["tokens"]["cr"])),
        ("List price", money(head["cost"])),
    ):
        parts.append("<dt>%s</dt><dd>%s</dd>" % (html.escape(label), html.escape(value)))
    parts.append("</dl></div>")

    for title, headers, rows, note in sections(total, args):
        parts.append("<h2>%s</h2>" % html.escape(title))
        if note:
            parts.append('<p class="note">%s</p>' % html.escape(note))
        if not rows:
            parts.append('<p class="note">(none)</p>')
            continue
        parts.append('<div class="scroll"><table><thead><tr>')
        parts.extend("<th>%s</th>" % html.escape(str(column)) for column in headers)
        parts.append("</tr></thead><tbody>")
        for row in (rows[: args.top] if args.top else rows):
            parts.append("<tr>")
            parts.extend("<td>%s</td>" % html.escape(str(cell)) for cell in row)
            parts.append("</tr>")
        parts.append("</tbody></table></div>")
        if args.top and len(rows) > args.top:
            parts.append('<p class="note">... and %d more</p>' % (len(rows) - args.top))

    parts.append(
        "<footer>Read from this machine's own transcripts under "
        "<code>~/.claude/projects</code> by <code>claude-stats</code>. Prices are list API "
        "rates applied to the tokens recorded, not an invoice. Payload sizes are estimated "
        "at four characters to the token.</footer></main>"
    )
    pathlib.Path(path).write_text("\n".join(parts))
    return path


def main():
    parser = argparse.ArgumentParser(
        description="What Claude Code has been doing: tools, skills, rules, subagents, cost.",
    )
    parser.add_argument("--since", default="30d", metavar="WHEN",
                        help="7d, 30d, 2026-01-01, or all (default 30d)")
    parser.add_argument("--project", metavar="TEXT",
                        help="only transcripts whose path contains TEXT")
    parser.add_argument("--top", type=int, default=20, metavar="N",
                        help="rows per table, 0 for all (default 20)")
    parser.add_argument("--sections", default="models,tools,skills,commands,agents,rules",
                        help="which tables to show")
    parser.add_argument("--html", metavar="FILE", help="write a shareable HTML report")
    parser.add_argument("--json", action="store_true", help="emit the numbers instead")
    parser.add_argument("--no-cache", action="store_true",
                        help="reread every transcript from the start")
    args = parser.parse_args()
    args.sections = set(args.sections.split(","))
    args.top = args.top or None

    since = None
    if args.since != "all":
        window = re.fullmatch(r"(\d+)d", args.since)
        since = (
            datetime.date.today() - datetime.timedelta(days=int(window.group(1)))
        ).isoformat() if window else args.since

    total = collect(scan(use_cache=not args.no_cache), since, args.project)
    if args.json:
        json.dump(
            {"summary": headline(total, args), "buckets": total},
            sys.stdout, indent=2, sort_keys=True,
        )
        print()
    elif args.html:
        print("wrote %s" % write_html(total, args, args.html))
    else:
        print_report(total, args)


if __name__ == "__main__":
    main()
