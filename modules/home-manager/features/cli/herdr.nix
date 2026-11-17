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
  #   All; Active (working, needing you, changed state in the last hour, or with
  #   a request whose CI is running or failing, so recently finished turns and
  #   broken builds stay in view); Needs you (blocked, or finished unseen); Review (agents with a pull
  #   or merge request still waiting for a review: open and not yet approved).
  # - A PR pill on every agent with a pull or merge request: the one the tuicr
  #   review hook in =tuicr.org= labels the agent's terminal with when it opens
  #   one, else the one for the branch the agent's folder is on, looked up with
  #   =gh pr view= or =glab mr view= on its machine every five minutes (=main= and
  #   =master= are skipped). It reads =#135 · CI ✓= (or =CI ✗=, a spinner while
  #   running, =no CI=), with =approved= once the request is, polled every minute
  #   with =gh pr view= or =glab mr view= on the agent's own machine. Once the
  #   request is merged or closed its labels are taken off the agent's terminal,
  #   so it leaves the list by itself. Clicking it
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
  # and the agents' pull request numbers too. Matches are ranked: a tab whose own
  # title starts with what was typed (=135= finds =#135 Fix login=), then one
  # with it at a word, then anywhere in the title, then a tab that only matches
  # through its agent's details, such as the agent that opened that request. A tab someone named keeps its name; one named after its own program,
  # which is what Herdr's agent menu does when it starts one, counts as unnamed. A
  # tab with no agent, which Herdr calls by its number, is labelled from its
  # terminal instead: the title the program set, else the program and its folder
  # (=zsh · nix-config=).

  home.file.".config/herdr-app/mods/picker-plus" = {
    source = ./herdr-app/picker-plus;
    recursive = true;
  };

  # A leader key, as in Emacs

  # =cmd-;= opens =leader=, a which-key panel that takes the keyboard the way
  # normal mode does: every key is a command or a group, Backspace goes up a
  # level, Escape or =cmd-;= again leaves. Esc alone stays with the terminal,
  # where Claude and vim need it. The tree follows the Emacs leader in
  # =development/emacs/plugins/keybinds=, so the same letters mean the same
  # things: =a= ai and agents (next needing you, filter, search, =R= review, =m=
  # model and =E= effort of the focused Claude, sent to it as =/model= and
  # =/effort=), =b b= find, =j= jump, =m= music (=m m=, =m n=, =m p= as in Emacs, through
  # =spotify-ctl=; =m l= smudge's playlists in a tab; =m o= the Spotify app), =i= inbox (mu4e through =emacsclient=), =o t=
  # telega (in its Herdr tab, as above; =o T= the app), and Space for the command palette; =t= tabs, =s= spaces and =w=
  # panes add Herdr's own, moving on =h n e i= like nvim on this Colemak board.

  # =j= jumps: every agent, tab and pane of the shown tab gets a two-letter code
  # from the Colemak home row (=ar=, =as=, …); typing it goes there. Herdr does
  # not tell mods where panes sit on screen, so the codes are listed in the
  # panel and drawn on the agents list's rows rather than over each pane.

  home.file.".config/herdr-app/mods/leader" = {
    source = ./herdr-app/leader;
    recursive = true;
  };

  # A bottom bar with the model, the music and the inboxes

  # =toolbar= takes the place of Herdr's status bar and keeps what it showed on
  # the left (machine, branch, how many agents, how many need you). On the right:

  # - The focused Claude's account, model and effort. The account comes from the
  #   login folder its session runs from (=~/.claude=, =~/.claude-work=), checked
  #   with =claude auth status= on the agent's machine every ten minutes, and reads
  #   =Personal · Max= or =<organisation> · Team=; a personal folder signed into
  #   an organisation shows red with how to fix it. Model and effort are read from
  #   its status line on the terminal's screen, effort as =default= when the
  #   status line leaves it out; clicking either opens the leader on that group.
  # - Spotify: previous, play or pause, next, and what is playing, through
  #   =spotify-ctl= (=pkgs/spotify-ctl.py=), the Web API client the Emacs mode
  #   line and the menu bar read. It reaches whichever Connect device is active,
  #   normally the headless librespot one Emacs plays on, so it works with
  #   Spotify.app closed and never starts it. Clicking the track opens smudge's
  #   playlists in a Herdr tab (a terminal frame of the Emacs daemon), where
  #   search and device selection are smudge's own keys.
  # - Unread mail, counted by =mu= every minute with the query the Emacs mode
  #   line uses (=flag:unread=), so the two agree; clicking opens Mail. The
  #   leader's =i i= still opens mu4e.
  # - Telegram's unread unmuted chats, read from telega in the Emacs daemon (the
  #   number the Emacs mode line shows); clicking opens telega in a Herdr tab, a
  #   terminal frame of the same daemon (=emacsclient -t=), or brings that tab back
  #   if it is open. With no telega running it falls back to Telegram.app: its
  #   Dock badge while it runs, a bare icon while closed, and a click opens it.

  home.file.".config/herdr-app/mods/toolbar" = {
    source = ./herdr-app/toolbar;
    recursive = true;
  };

  # Spaces grouped by project, with the name kept and the branch given up

  # =spaces-plus= is a copy of Herdr's =spaces= list with three changes:

  # - Spaces of the same git repository nest under one project row: its name, how
  #   many spaces it has, the most urgent agent state among them, and a fold.
  #   Herdr only nested worktrees under their main checkout; this takes in every
  #   space of the repo, a second session in the same checkout included. Under a
  #   project each space reads as its session: the name someone gave it, else its
  #   agent's title, else its branch.
  # - Herdr puts a space's name and its git tail (repo, branch, ahead and behind)
  #   on one row and shrinks both in proportion when it is too narrow, so a long
  #   branch takes the name down with it. Here the name keeps its width, up to 170
  #   points, and the branch is what truncates.
  # - Its =+= buttons open the launcher below instead of an empty space.

  home.file.".config/herdr-app/mods/spaces-plus" = {
    source = ./herdr-app/spaces-plus;
    recursive = true;
  };

  # Claude as a chat

  # =chat= shows a Claude Code agent as a conversation instead of its terminal,
  # the way shepherdr does. Nothing about the agent changes: it keeps running in
  # its terminal, which stays in the tab under the chat pane, zoomed over it, so
  # its status, notifications and the agents list carry on. The chat reads the
  # session's own transcript -- =sessions/<pid>.json= in the account's config folder
  # names the session, and =projects/*/<id>.jsonl= holds it -- on whichever machine
  # the agent runs, and types what is sent into the terminal with =hc send=.

  # Your messages sit on the right in blue (accent) bubbles and Claude's on the
  # left in amber ones, as rendered Markdown, each with its time under it (the
  # date too for older days). Images you pasted show as thumbnails that open
  # full size in Preview: they live in the transcript as base64, so each is
  # decoded once into =data/chat-images= in Herdr's folder (through =hc exec= for
  # an agent on another machine), since Herdr only draws images from there. each tool call is one
  # line, with a spinner until its result comes back, that opens to show its input
  # and output; slash commands show as chips. Code blocks in Claude's replies are drawn
  # with the toolkit's own code editor, read-only and highlighted for their
  # language in the theme's colours, under a label naming it; inline code stays
  # with the Markdown view, which has no styling of its own to change. File edits
  # (=Edit=, =MultiEdit=, =Write=, =NotebookEdit=) show as a diff instead: the line
  # with =+added −removed= counts, then the changed lines in the terminal's font,
  # highlighted for the file's language, each added line with a green =+=, edge and
  # tint, each removed one the same in red, the first 24 inline and the rest a
  # click away. While Claude is working the list ends
  # in a working line and a Stop button beside Send presses Esc; the list keeps to
  # its bottom as messages come in; a message sent while it works stays at the end
  # marked Queued until the transcript shows Claude took it (it reads queued
  # messages at its next step), and when Claude's screen offers a key to send it
  # now, a Send now button presses that key; when it needs you, the last lines of its screen (the
  # permission prompt or question) show with buttons for 1, 2, 3, Enter and Esc,
  # and Answer in terminal goes back. Only the last 160 messages are drawn, with
  # the earlier ones a click away.

  # Herdr counts a finished agent as read only once its terminal has been looked
  # at, which the chat hides; so while a chat is on screen (its tab shown, the
  # window in front) it records that its agent was seen, and the agents list
  # treats a finished agent seen in its chat as read: out of Needs you, off the
  # Dock badge, and no notification. Herdr's own status dots still wait for the
  # terminal.

  # The view is remembered per agent: an agent last left in chat opens in chat
  # again when it is focused (from its row, the picker or the attention jump),
  # and one switched back to its terminal stays there.

  # =⌘⇧C=, the leader's =a c=, the chat button on a Claude agent's row, or the
  # Chat | Terminal switch in the pane's header opens it, and the same again goes
  # back. That header is =pane-plus=, a copy of Herdr's =pane= header with the
  # switch on every Claude pane and the chat pane named after its agent. Model and effort stay
  # in the bottom bar.

  home.file.".config/herdr-app/mods/chat" = {
    source = ./herdr-app/chat;
    recursive = true;
  };

  home.file.".config/herdr-app/mods/pane-plus" = {
    source = ./herdr-app/pane-plus;
    recursive = true;
  };

  # A launcher for new sessions

  # =launcher= is a dialog for starting work: pick the machine, the agent
  # (Claude, Codex or a plain shell), its model and effort, and whether it opens
  # as a new space or a tab of this one, then a project. Projects are the ones
  # opened from it before, then zoxide's list on that machine, filtered as you
  # type; a typed path opens that folder, and Browse… (this Mac only) opens the
  # system folder picker. The choices are remembered for next time, and so are
  # the projects, per machine.

  # Claude's models are its aliases (default, Opus, Sonnet, Haiku) and Fable by
  # id, with =--effort= from low to max; Codex's are the default and the
  # =gpt-6-astra= its config names, with =model_reasoning_effort= from low to
  # ultra. The agent starts through the login shell as any Herdr agent does, so
  # =claude= still picks the account by folder.

  # The sidebar's =+= buttons, the picker's new-space rows, the leader's =s c= and
  # =s v=, and =cmd-n= all open it. Tab cycles the agent, =ctrl-m= the model,
  # =ctrl-e= the effort, =ctrl-o= browses.

  home.file.".config/herdr-app/mods/launcher" = {
    source = ./herdr-app/launcher;
    recursive = true;
  };

  # A layout that shows it

  # Layouts name their mods, and the shipped =main= layout is also rewritten on
  # every start, so a layout of its own, =herdr-plus=, is derived from it on
  # every switch: the same tree with =agents-plus= in place of =agents=,
  # =spaces-plus= in place of =spaces=, =pane-plus= in place of
  # the =pane= header and =toolbar= in place of =workspace-status=, and quieter
  # pane frames: a tab's only pane has none, and in a split tab the focused pane's
  # outline is the theme's dim colour, one step from the plain border, instead of
  # the accent. Deriving
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
      if ${lib.getExe pkgs.jq} 'walk(if type == "object" and .mod == "agents" then .mod = "agents-plus" elif type == "object" and .mod == "spaces" then .mod = "spaces-plus" elif type == "object" and .mod == "pane" then .mod = "pane-plus" elif type == "object" and .mod == "workspace-status" then .mod = "toolbar" elif type == "object" and has("focus") and has("border") then .lone = false | .focus = { width: 1, color: "dim" } else . end)' \
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

  # Tokyo Night, storm when dark and day when light

  # The same pairing tuicr and the editors use. Herdr ships no Tokyo Night, so
  # the two palettes are theme files beside this module (=herdr-app/themes=):
  # the terminal colors are tokyonight's, and a few panel colors (chrome, border,
  # accent and the agent states) are set from the same palette rather than left
  # to Herdr's derivation. They are copied in rather than linked, since Herdr
  # reads =themes/= as its own folder, and =settings.json= gets a =theme= that
  # follows the system appearance, merged the same way as the keys below.

  home.activation.herdrAppTheme = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    app="$HOME/.config/herdr-app"
    if [ -d "$app" ]; then
      run mkdir -p "$app/themes"
      run install -m 644 ${./herdr-app/themes/tokyonight-storm.json} "$app/themes/tokyonight-storm.json"
      run install -m 644 ${./herdr-app/themes/tokyonight-day.json} "$app/themes/tokyonight-day.json"
      if [ -f "$app/settings.json" ]; then
        tmp="$(mktemp)"
        if ${lib.getExe pkgs.jq} '.theme = {"light": "tokyonight-day", "dark": "tokyonight-storm"}' "$app/settings.json" > "$tmp"; then
          if ! cmp -s "$tmp" "$app/settings.json"; then run install -m 644 "$tmp" "$app/settings.json"; fi
        else
          warnEcho "could not set Herdr's theme in $app/settings.json"
        fi
        rm -f "$tmp"
      fi
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
  # | =cmd-;=       | leader: which-key panel, jump, model and effort, music |
  # | =cmd-n=       | launcher: new session with machine, agent, model, effort |
  # | =cmd-shift-c= | the focused Claude as a chat, and back to its terminal |
  # | =cmd-shift-r= | the focused agent's review in tuicr, and back again   |
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
            "cmd-;" = "mod.open:leader";
            "cmd-n" = "mod.open:launcher";
            "cmd-shift-c" = "agents-plus.chat";
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
