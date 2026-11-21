# Jira from the terminal and from Herdr, one project per checkout

# Work tickets live in Jira, and every work repository belongs to one Jira
# project. Two tools reach it from here:

# - =jira=, the jira-cli command (=jira-cli-go= in nixpkgs): interactive issue
#   tables, the current sprint, epics, and commands to move, assign, comment on
#   and create issues. A wrapper runs it with the project of the folder it is
#   started in, so =jira sprint list --current= in a checkout lists that
#   project's sprint with no flags.
# - A board tab in Herdr (the =jira= mod in =herdr-app/jira=): the project's
#   board in its own columns, the sprint's name and the days left in it, and
#   the backlog. A card opens a menu to open the issue in the browser, move it
#   to any status Jira allows from where it is, assign it to yourself, start
#   Claude on it in a new tab of the same space, or copy it for a Claude
#   session already running. Both hand Claude the whole ticket written out
#   (=jira-board issue=): its fields, description, sub-tasks, linked issues and
#   latest comments, so Claude needs no Jira access of its own. A checkout whose
#   branch names a ticket (=feature/ABC-123_…=) gets that ticket as a chip in
#   the board's header, and the leader's =K= opens the same menu for it from
#   anywhere in the space. =Copy all= in the header copies the whole board
#   instead (=jira-board export=): every issue on the board and in its backlog,
#   each sub-task after its parent, as one tab-separated table with its column,
#   type, status, priority, assignee, age, the three estimates, labels and
#   components, under a few lines saying what the columns mean. It is for
#   handing to Claude to sort, filter or watch, and runs to a few hundred rows.

# Both get the project the same way, through =jira-board= (=jira-board.sh=
# beside this module), a small script around Jira's REST API: the ticket key in
# the branch name first (=feature/ABC-123_…= is ABC), then the private folder
# map, the longest folder that contains the checkout winning. The board is the
# project's first scrum board, or a pinned one; its id and columns are cached
# for a day under =~/.cache/jira-board=.

# The sites, their logins and the folder maps are in the private
# =work-extras.nix=, as =jira.sites=: project keys name the clients they belong to,
# and this repository is public. Without that entry nothing here is installed.

# The API tokens are not in that file or in the store. =jira-board login= asks
# for each site's in turn (=--site <name>= for one) and keeps it in the login
# keychain, under =jira-api-token= and the login's name, where both tools read
# it: create one at id.atlassian.com, Security, API tokens, signed in as that
# login. It has to run in a terminal, as it reads the token hidden. It reads
# the token itself rather than leaving the prompt to =security=, whose prompt
# stops at 128 characters, short of an Atlassian token, and hands it over
# through =security -i= so it never shows in the process list. A scoped token only answers through Atlassian's API gateway
# rather than the site's own address; =login= tries both and remembers which
# one answered.

{
  config,
  lib,
  pkgs,
  ...
}:
let
  home = config.home.homeDirectory;
  privatePath = "${home}/.config/nix-secrets/work-extras.nix";
  private = if builtins.pathExists privatePath then import privatePath { inherit pkgs; } else { };
  jira = private.jira or null;

  # There can be more than one Jira site, each signed into with its own account:
  # the employer's and a client's, say. Each site names the folders it owns
  # (=roots=) and its folder map, all relative to the home folder so a rename of
  # the home folder does not reach into the private file; here they become
  # absolute paths, which is what =jira-board= compares the checkout's folder
  # with. The longest folder that contains the checkout decides the site, a root
  # or a mapped folder alike, so a client's repository checked out under the
  # employer's folder still goes to the client's Jira by mapping it there.

  boardConfig = pkgs.writeText "jira-board.json" (
    builtins.toJSON {
      sites = lib.mapAttrs (_: site: {
        inherit (site) server login;
        roots = map (dir: "${home}/${dir}") (site.roots or [ ]);
        folders = lib.mapAttrs' (dir: key: lib.nameValuePair "${home}/${dir}" key) (site.folders or { });
        boards = site.boards or { };
      }) (jira.sites or { });
    }
  );

  jiraBoard = pkgs.writeShellApplication {
    name = "jira-board";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
      pkgs.findutils
      pkgs.gnugrep
    ];
    bashOptions = [
      "nounset"
      "pipefail"
    ];
    text = builtins.readFile ./jira-board.sh;
  };

  # The jira wrapper

  # jira-cli keeps one project and one board per config file, and makes that
  # file with =jira init=, which asks Jira for the project's fields. So each
  # project gets its own file, =~/.config/.jira/<site>-<KEY>.yml=, made the first time
  # =jira= runs in one of its checkouts, with the board =jira-board= picked;
  # =JIRA_CONFIG_FILE= points jira-cli at it. Outside any project it runs as
  # itself, on its default file. The token goes in through =JIRA_API_TOKEN= for
  # that one process.

  jiraCli = pkgs.writeShellApplication {
    name = "jira";
    runtimeInputs = [
      jiraBoard
      pkgs.git
      pkgs.jq
    ];
    text = ''
      real=${lib.getExe' pkgs.jira-cli-go "jira"}
      branch="$(git branch --show-current 2>/dev/null || true)"
      here="$(jira-board project "$PWD" "$branch" 2>/dev/null || true)"
      key="$(jq -r '.key // empty' <<<"''${here:-null}")"
      if [ -z "$key" ]; then
        exec "$real" "$@"
      fi
      site="$(jq -r .site <<<"$here")"
      login="$(jq -r .login <<<"$here")"
      if token="$(/usr/bin/security find-generic-password -s jira-api-token -a "$login" -w 2>/dev/null)"; then
        export JIRA_API_TOKEN="$token"
      else
        exec "$real" "$@"
      fi
      file="$HOME/.config/.jira/$site-$key.yml"
      if [ ! -s "$file" ]; then
        board="$(jira-board --site "$site" meta "$key" | jq -r '.board.name // empty')"
        mkdir -p "$HOME/.config/.jira"
        JIRA_CONFIG_FILE="$file" "$real" init --installation cloud --auth-type basic \
          --server "$(jq -r .server <<<"$here")" --login "$login" \
          --project "$key" ''${board:+--board "$board"} --force >&2
      fi
      export JIRA_CONFIG_FILE="$file"
      exec "$real" "$@"
    '';
  };

  jiraDigest = pkgs.writeShellApplication {
    name = "jira-digest";
    runtimeInputs = [
      jiraBoard
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnused
      pkgs.jq
      pkgs.terminal-notifier
    ];
    bashOptions = [
      "nounset"
      "pipefail"
    ];
    text = builtins.readFile ./jira-digest.sh;
  };
in
lib.mkIf (jira != null) {
  home.packages = [
    jiraCli
    jiraBoard
    jiraDigest
  ];

  xdg.configFile."jira-board/config.json".source = boardConfig;

  # The board tab

  # The mod draws one column per column of the Jira board, holding the issues
  # whose status the board puts there, in the board's own order; an issue whose
  # status no column claims goes in a last column, so nothing is hidden.
  # Rows follow the board's swimlanes when it has them. Custom swimlanes are
  # JQL queries, so =jira-board= asks Jira which of the shown issues each one
  # matches, and an issue goes to the first lane that takes it, the default lane
  # holding the rest, as Jira does; swimlanes by assignee are grouped here, yours
  # first. Jira keeps swimlanes out of its public API, so they come from the
  # board's settings in the API its own web app uses, and a board whose settings
  # cannot be read shows as one lane. Each column is drawn as a panel running the height of the board, the lanes
  # crossing it, so a card's column reads at a glance however far down it is. The
  # column headers sit once above the
  # lanes with the counts across all of them; a lane folds from its header, and
  # an empty one is left out.

  # The board scrolls both ways under headers that stay put: the column headers
  # stay at the top, and the lane being looked at keeps its header pinned under
  # them once its own has scrolled away; sideways, the lane headers stay at the
  # left edge while the columns move. Herdr's scroll areas do not say where
  # they are, which a pinned header needs, so the board scrolls itself: it
  # reads the wheel and trackpad, and moves the lanes under the headers by what
  # they report, measured lane by lane. The backlog's column titles stay above
  # its list the same way. A filter in the header narrows both views to the
  # issues whose key, title, assignee, status, priority, type or sub-tasks hold
  # every word typed; Escape clears it.

  # A card shows the issue's priority, the remaining and the original estimate
  # (red once the time logged passes the original), and its age since it was
  # created. Sub-tasks do not get cards of their own: they are stacked inside
  # their parent's card, folded to a count of how many there are and how many
  # are done, and unfold to a row each with its status, which opens the same
  # menu as a card. Jira returns them with the parent, so a parent shows all of
  # its sub-tasks even when the board leaves them off. The backlog lists the
  # same priority, estimate, age and sub-task count per row. A
  # scrum board shows its active sprint; a kanban board shows what is not done,
  # plus what was finished in the last two weeks. Jira hands issues over a
  # hundred at a time, so the board and the backlog are read page by page, all of
  # them, rather than the first page only. The backlog view is the
  # board's backlog as a list. =Mine= narrows both to your issues, and your cards
  # are outlined in the accent colour. A blocked issue stands out in red: one
  # flagged in Jira (the impediment flag), or one whose status reads as blocked
  # (=BLOCKED=, =Bloqueado=, =On hold=, =En espera=). Its card gets a red edge
  # and says why, its column's header counts the blocked ones, and in the
  # backlog its key turns red behind a flag.

  # Each answer is kept with a file name of its own before it replaces the
  # kept one, so two tabs fetching the same project at once do not trip over
  # each other's write.

  # Every space on this computer whose folder has a Jira project gets two of
  # these tabs, =Kanban= and =Backlog=, and every space a =Notes= tab running
  # =notes= (=notes.org=) on its folder, opened behind the others by the
  # =requests= panel, which is always loaded and looks at the spaces once a
  # minute. Their names carry the project, =Kanban · shop-api (ABC)= or
  # =Notes · nix-config=, so the picker finds them by repository or Jira key; a
  # tab with the bare name is renamed. A space's project is its repository's
  # main checkout, as =spaces-plus= records it, rather than the space's own
  # folder, which is wherever its first terminal started. A tab closed by hand
  # stays closed for that space (=jira.auto= in
  # Herdr's shared state remembers which ones were opened); the leader's =k=
  # brings the Kanban back. A space made from the new-space dialog gets only the
  # ones ticked there: the dialog leaves the others under =companions.pending=,
  # keyed by the space's folder, and the panel counts them as opened already when
  # it first meets the space, which it looks for every five seconds, so the tabs
  # come up moments after the space rather than up to a minute later.

  # Each tab looks again every two minutes, and at once after a change made
  # from a card's menu or a click on its refresh. Two tabs on one project, or
  # several spaces on one, share what =jira-board view= fetched for ninety
  # seconds, so the tabs cost Jira a request per project, not per tab; a change
  # or a refresh asks with =--fresh=.

  home.file.".config/herdr-app/mods/jira" = {
    source = ./herdr-app/jira;
    recursive = true;
  };

  # The daily digest

  # A board with a few hundred tickets, shared by several repositories, is more
  # than anyone reads each morning, and only the tickets that touch our part of
  # the system matter: the frontend and the BFF, say, while the core backend is
  # another team's. =jira-digest= (=jira-digest.sh= beside this module) writes a
  # note a day per board into the Obsidian vault with those tickets only, in a
  # table per part (priority, age, the remaining and original estimate, assignee,
  # status, where on the board, and why it counts), and above them what is new
  # on the board since the last note and what moved: column, status, priority,
  # assignee or remaining estimate. It runs per board rather than per
  # repository, so the repositories that share one get one note and one pass.

  # Which part a ticket touches is a judgement, not a label lookup: titles carry
  # tags only sometimes, and a sub-task often touches one part of a parent that
  # touches two. So Claude decides, headless and on the work account
  # (=claude -p=, =CLAUDE_ACCOUNT=work=, =claude.org=), forty tickets at a time,
  # from each ticket's title, labels, components, parent and description, and
  # from the list of the stream's repositories, each with the stack its manifest
  # shows (=composer.json= is PHP, a =nuxt.config= is Nuxt, a Capacitor config or
  # Capacitor or Cordova among its packages is a mobile app around its web front),
  # read from the
  # digest's folder of checkouts each morning so a repository cloned since counts
  # without a config change, and from the stream's list of projects, the
  # titles of the children of a Confluence page the digest names, read the same
  # way (=jira-board children=). The ticket text is what
  # =jira-board texts= reads, a hundred at a time; Claude may also read the ticket or
  # the pages it links through the Atlassian connector when that is connected,
  # with only its reading tools allowed. Its verdicts are kept with the time the
  # ticket last changed in Jira, so each morning it is asked only about tickets
  # that are new or were edited since; the first run sorts the whole board, and
  # so does the first after the project's notes or parts change in the config,
  # as the verdicts were given against the old ones. A
  # ticket it could not sort is left out of that note, said so, and tried again
  # the next time.

  # The boards, the folder in the vault each note goes to, the parts and a few
  # lines about the project for Claude (which repositories are which, what the
  # core backend is written in, what the ticket tags mean) are client knowledge,
  # so they live in the private =work-extras.nix= as =jira.digests=.

  # It runs at 9:40 on weekdays, or when the Mac wakes after that, and a
  # notification opens the note in Obsidian. Running =jira-digest= by hand
  # writes the notes at once and counts as that day's: the 9:40 run
  # (=--scheduled=) skips a day that already has them. A run in which Claude
  # sorted nothing at all is a failure rather than a quiet board: it says so in a
  # notification, writes no note, leaves the last snapshot to compare with, and
  # does not count as the day's. The prompt goes to =claude -p= on its standard
  # input, as =--allowedTools= would take a prompt given after it for one more
  # tool.

  xdg.configFile."jira-digest/config.json".text = builtins.toJSON {
    vault = "${home}/Documents/robertogoam";
    digests = jira.digests or [ ];
  };

  launchd.agents.jira-digest = lib.mkIf ((jira.digests or [ ]) != [ ]) {
    enable = true;
    config = {
      ProgramArguments = [
        (lib.getExe jiraDigest)
        "--scheduled"
      ];
      StartCalendarInterval =
        map
          (day: {
            Weekday = day;
            Hour = 9;
            Minute = 40;
          })
          [
            1
            2
            3
            4
            5
          ];
      EnvironmentVariables.PATH = "/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin:/usr/bin:/bin";
      ProcessType = "Background";
      StandardOutPath = "${home}/Library/Logs/jira-digest.out.log";
      StandardErrorPath = "${home}/Library/Logs/jira-digest.err.log";
    };
  };
}
