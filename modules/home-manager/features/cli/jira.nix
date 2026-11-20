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
#   to any status Jira allows from where it is, assign it to yourself, or start
#   Claude on it in a new tab of the same space.

# Both get the project the same way, through =jira-board= (=jira-board.sh=
# beside this module), a small script around Jira's REST API: the ticket key in
# the branch name first (=feature/ABC-123_…= is ABC), then the private folder
# map, the longest folder that contains the checkout winning. The board is the
# project's first scrum board, or a pinned one; its id and columns are cached
# for a day under =~/.cache/jira-board=.

# The site, the login and the folder map are in the private
# =work-extras.nix=, as =jira=: project keys name the clients they belong to,
# and this repository is public. Without that entry nothing here is installed.

# The API token is not in that file or in the store. =jira-board login= asks
# for it and keeps it in the login keychain, under =jira-api-token= and the
# login's name, where both tools read it: create one at id.atlassian.com,
# Security, API tokens.

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

  # The folder map arrives relative to the home folder, so a rename of the home
  # folder does not reach into the private file; here it becomes absolute paths,
  # which is what =jira-board= compares the checkout's folder with.

  boardConfig = pkgs.writeText "jira-board.json" (
    builtins.toJSON {
      inherit (jira) server login;
      folders = lib.mapAttrs' (dir: key: lib.nameValuePair "${home}/${dir}" key) (jira.folders or { });
      boards = jira.boards or { };
    }
  );

  jiraBoard = pkgs.writeShellApplication {
    name = "jira-board";
    runtimeInputs = [
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
  # project gets its own file, =~/.config/.jira/<KEY>.yml=, made the first time
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
      conf=${boardConfig}
      login="$(jq -r .login "$conf")"
      if token="$(/usr/bin/security find-generic-password -s jira-api-token -a "$login" -w 2>/dev/null)"; then
        export JIRA_API_TOKEN="$token"
      fi
      branch="$(git branch --show-current 2>/dev/null || true)"
      key="$(jira-board project "$PWD" "$branch" 2>/dev/null || true)"
      if [ -z "$key" ] || [ -z "''${JIRA_API_TOKEN:-}" ]; then
        exec "$real" "$@"
      fi
      file="$HOME/.config/.jira/$key.yml"
      if [ ! -s "$file" ]; then
        board="$(jira-board meta "$key" | jq -r '.board.name // empty')"
        mkdir -p "$HOME/.config/.jira"
        JIRA_CONFIG_FILE="$file" "$real" init --installation cloud --auth-type basic \
          --server "$(jq -r .server "$conf")" --login "$login" \
          --project "$key" ''${board:+--board "$board"} --force >&2
      fi
      export JIRA_CONFIG_FILE="$file"
      exec "$real" "$@"
    '';
  };
in
lib.mkIf (jira != null) {
  home.packages = [
    jiraCli
    jiraBoard
  ];

  xdg.configFile."jira-board/config.json".source = boardConfig;

  # The board tab

  # The mod draws one column per column of the Jira board, holding the issues
  # whose status the board puts there, in the board's own order; an issue whose
  # status no column claims goes in a last column, so nothing is hidden.
  # Sub-tasks stay off the board, as they sit under their parents in Jira too. A
  # scrum board shows its active sprint; a kanban board shows what is not done,
  # plus what was finished in the last two weeks. The backlog view is the
  # board's backlog as a list. =Mine= narrows both to your issues, and your cards
  # are outlined in the accent colour.

  # It looks again every two minutes and right after any change made from a
  # card's menu. The tab opens from the leader's =k= in the shown space, or
  # with the new space when the launcher's =Jira board= is on.

  home.file.".config/herdr-app/mods/jira" = {
    source = ./herdr-app/jira;
    recursive = true;
  };
}
