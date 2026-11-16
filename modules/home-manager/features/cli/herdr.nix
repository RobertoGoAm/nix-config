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
}
