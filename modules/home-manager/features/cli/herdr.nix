# hnei, as in nvim

# Herdr moves between panes on vim's =h j k l=, after the prefix (=ctrl+b=) and
# in navigate mode. They get the three swaps nvim has on this Colemak board:
# down, up and right go to =n e i=, and what the prefix had on =n= and =e=
# (next tab, edit the scrollback) moves to the =j= and =k= they freed. Nothing
# held =prefix+i=. Every other binding keeps Herdr's own letter, capitals
# included, so =prefix+shift+n= still makes a new workspace.

{
  config,
  lib,
  pkgs,
  ...
}:
let
  herdr = config.programs.herdr.package;

  # Claude's sessions come back after a restart

  # =herdr integration install claude= writes a hook script into the Claude
  # config directory and adds a SessionStart hook that runs it, which tells
  # Herdr each pane's Claude session so it can resume them after the server or
  # the machine restarts. Claude's settings.json is declared here and rewritten
  # on every switch, so the integration is declared instead of installed by
  # hand: the script is generated at build time by the packaged Herdr itself, so
  # it always matches the version, and the hook is the exact one Herdr would
  # add, so =herdr integration status= reports it installed. The script exits at
  # once outside a Herdr pane, so Claude sessions elsewhere, Orca's included,
  # run it for nothing.

  claudeIntegration = pkgs.runCommand "herdr-claude-integration" { } ''
    mkdir -p claude home/.config
    printf '{}\n' > claude/settings.json
    HOME=$PWD/home XDG_CONFIG_HOME=$PWD/home/.config CLAUDE_CONFIG_DIR=$PWD/claude \
      ${lib.getExe herdr} integration install claude > /dev/null
    install -m 755 claude/hooks/herdr-agent-state.sh $out
  '';
in
{
  programs.herdr = {
    enable = true;
    mutableSettings = true;
    settings.keys = {
      focus_pane_down = "prefix+n";
      focus_pane_up = "prefix+e";
      focus_pane_right = "prefix+i";
      next_tab = "prefix+j";
      edit_scrollback = "prefix+k";
      navigate_pane_down = "n";
      navigate_pane_up = "e";
      navigate_pane_right = "i";
    };
  };

  home.file.".claude/hooks/herdr-agent-state.sh".source = claudeIntegration;

  programs.claude-code.settings.hooks.SessionStart = [
    {
      matcher = "^(startup|resume|clear|compact|fork)$";
      hooks = [
        {
          type = "command";
          command = "bash '${config.home.homeDirectory}/.claude/hooks/herdr-agent-state.sh' session";
          timeout = 10;
        }
      ];
    }
  ];

  # Agents that run inside Herdr can drive it

  # Herdr ships a skill that teaches a coding agent to split panes, run commands
  # without stealing focus, read another pane's output and wait on other agents.
  # It comes from Herdr's own source and only applies inside a Herdr pane
  # (=HERDR_ENV=1=), so it is installed beside tuicr's rather than left to
  # =npx skills add=.

  home.file.".claude/skills/herdr".source = "${herdr.src}/skills/herdr";

  # The TUI's agent panel in attention order

  # The sidebar lists agents by space unless told otherwise. Priority order puts
  # the ones that need you on top, then the ones that finished while nobody was
  # looking, so =prefix+o= (open the notification target) and a glance at the top
  # row are enough to find the next agent to answer.

  programs.herdr.settings.ui.agent_panel_sort = "priority";

  # Herdr desktop: an agents list that says what needs you

  # The desktop app (the =herdr-app= cask in =macos/prometheus/casks.org=) keeps
  # its own JSON settings in =~/.config/herdr-app= and draws its sidebar from
  # mods, small JavaScript panels in =mods/<name>/=. Its shipped =agents= mod is
  # replaced on every start, so the changes live in a copy, =agents-plus=, beside
  # this module in =herdr-app/agents-plus=:

  # - Filters above the list, each with a count of the agents it would show:
  #   All; Active (working, needing you, or changed state
  #   in the last hour, so recently finished and recently failed turns stay in
  #   view); Needs you (blocked, or finished unseen); Review (agents with a pull
  #   or merge request open).
  # - A PR pill on every agent whose terminal carries a =review.url= label, which
  #   the tuicr review hook in =tuicr.org= sets when the agent opens a pull or
  #   merge request. Its color is the request's CI, polled every minute with =gh
  #   pr view= or =glab mr view= on the agent's own machine: green passing,
  #   spinning while running, red failing, then merged or closed. Clicking it
  #   focuses the request's tuicr pane, or opens a new one beside the agent.
  # - A search box under the filters, narrowing whichever filter is on (and its
  #   counts) to the agents whose space, tab, session title, program, pull
  #   request (=#123=, =!45=, its URL) or CI state (=ci:fail=) match every word
  #   typed; a word also matches its letters in order, so =fxlg= finds "fix
  #   login". Enter focuses the first agent left, Escape clears it.
  # - The Dock badge counts the agents waiting on you.
  # - A macOS notification when an agent starts needing you, or finishes while
  #   you aren't looking at it. Herdr itself only draws a note inside its window
  #   and plays a sound, which a hidden window or another space never shows. The
  #   mod runs on this Mac, so agents on vulcan notify here too. Clicking the
  #   notification brings Herdr forward on that agent. They go through
  #   =terminal-notifier=, the first time after macOS asks to allow it.
  # - Three commands for keys: =agents-plus.attention= focuses the next agent
  #   that needs you (blocked before finished, longest waiting first, cycling on
  #   each press), =agents-plus.filter= cycles the filters, and
  #   =agents-plus.review= brings up the focused agent's review, and
  #   =agents-plus.search= puts the cursor in the search box.

  # Linked file by file, not as one store path: Herdr writes =jsconfig.json= and
  # type files into every mod folder, so the folder itself has to stay writable.

  home.file.".config/herdr-app/mods/agents-plus" = {
    source = ./herdr-app/agents-plus;
    recursive = true;
  };

  home.packages = lib.optional pkgs.stdenv.hostPlatform.isDarwin pkgs.terminal-notifier;

  # A picker that names sessions, not programs

  # The shipped picker (=cmd-p=) labels a tab nobody named with its agent's
  # program, so every Claude tab reads "Claude Code". =picker-plus= is a copy that
  # labels it with the agents' own terminal titles -- Claude's session title --
  # falling back to the tab's name, and matches what is typed against those titles
  # and the agents' pull request numbers too. A tab someone named keeps its name; one named after its own program,
  # which is what Herdr's agent menu does when it starts one, counts as unnamed. A
  # tab with no agent, which Herdr calls by its number, is labelled from its
  # terminal instead: the title the program set, else the program and its folder
  # (=zsh · nix-config=).

  home.file.".config/herdr-app/mods/picker-plus" = {
    source = ./herdr-app/picker-plus;
    recursive = true;
  };

  # A layout that shows it

  # Layouts name their mods, and the shipped =main= layout is also rewritten on
  # every start, so a layout of its own, =herdr-plus=, is derived from it on
  # every switch: the same tree with =agents-plus= in place of =agents=. Deriving
  # it each time keeps it in step with Herdr's updates to =main=; edits made to
  # =herdr-plus= from inside the app last until the next switch. Herdr picks the
  # file up live. The keys that drive =agents-plus= reach it only while a layout
  # showing it is up, so the first time the file is made, a running app is
  # switched to it; after that the app remembers the choice, and =cmd-shift-l=
  # cycles layouts. Nothing happens on a machine where the app has never run.

  home.activation.herdrAppLayout = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    app="$HOME/.config/herdr-app"
    if [ -f "$app/layouts/main.json" ]; then
      first=; [ -f "$app/layouts/herdr-plus.json" ] || first=1
      tmp="$(mktemp)"
      if ${lib.getExe pkgs.jq} 'walk(if type == "object" and .mod == "agents" then .mod = "agents-plus" else . end)' \
          "$app/layouts/main.json" > "$tmp"; then
        run install -m 644 "$tmp" "$app/layouts/herdr-plus.json"
        if [ -n "$first" ] && [ -S "$app/herdr-app.sock" ] && command -v herdr-app >/dev/null; then
          run herdr-app do layout.switch --name herdr-plus >/dev/null 2>&1 || true
        fi
      else
        warnEcho "could not derive the herdr-plus layout from $app/layouts/main.json"
      fi
      rm -f "$tmp"
    fi
  '';

  # Keys for the agents that need you

  # =cmd-]= and =cmd-[= already step through the agents list in the order it
  # shows. Added on top of them, and =cmd-p= moved to =picker-plus=:

  # | Key           | Does                                                  |
  # |---------------+-------------------------------------------------------|
  # | =cmd-j=       | jump to the next agent that needs you                 |
  # | =cmd-p=, =cmd-k= | fuzzy-find an agent by its session title, a tab or a space |
  # | =cmd-shift-j= | cycle the agents list's filter                        |
  # | =cmd-shift-r= | bring up the focused agent's pull request in tuicr    |
  # | =cmd-shift-f= | search the agents list (within the current filter)    |

  # =keys.json= is the app's and stays writable: any edit marks it as the
  # person's, after which Herdr stops adding its new default keys to it, so
  # these are merged into the existing file on every switch rather than written
  # over it, and the declared keys win. Before the app's first start there is no
  # file to merge into, and nothing is written.

  home.activation.herdrAppKeys =
    let
      keys = pkgs.writeText "herdr-app-keys.json" (
        builtins.toJSON {
          global = {
            "cmd-j" = "agents-plus.attention";
            "cmd-p" = "mod.open:picker-plus";
            "cmd-k" = "mod.open:picker-plus";
            "cmd-shift-j" = "agents-plus.filter";
            "cmd-shift-r" = "agents-plus.review";
            "cmd-shift-f" = "agents-plus.search";
          };
        }
      );
    in
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      file="$HOME/.config/herdr-app/keys.json"
      if [ -f "$file" ]; then
        tmp="$(mktemp)"
        if ${lib.getExe pkgs.jq} -s '.[0] * .[1]' "$file" ${keys} > "$tmp"; then
          if ! cmp -s "$tmp" "$file"; then run install -m 644 "$tmp" "$file"; fi
        else
          warnEcho "could not merge Herdr's keys into $file"
        fi
        rm -f "$tmp"
      fi
    '';
}
