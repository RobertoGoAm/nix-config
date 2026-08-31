# cli opencode

{ lib, pkgs, ... }:
let

  # ---- model routing...

  # ---- model routing -------------------------------------------------------
  # Everything runs through OpenRouter, so one credential covers both models.
  # Slugs verified against https://openrouter.ai/api/v1/models — "qwen3.8" is a
  # real family there, distinct from the older "qwen3-8b".

  # Other Qwen 3.8 variants, if the 27b disappoints:
  #   openrouter/qwen/qwen3.8-max         $2.00 / $6.00  per M tokens
  #   openrouter/qwen/qwen3.8-2.4t-a95b   $2.00 / $6.00

  qwen = "openrouter/qwen/qwen3.8-27b"; # $0.40 / $3.00  per M tokens
  strong = "openrouter/anthropic/claude-sonnet-4.5";

  # THE TOGGLE. `strong` splits the work — Qwen implements, a better...

  # THE TOGGLE. `strong` splits the work — Qwen implements, a better model plans.
  # Change to `qwen` to route everything through Qwen, which is the harsher and
  # more honest test of whether it can carry a session alone.

  planModel = strong;

  # opencode reads the key from the environment. It is a sops secret...

  # opencode reads the key from the environment. It is a sops secret because this
  # repo is public; the wrapper below injects it so the key never lands in a
  # shell profile or a config file.

  keyFile = "/var/run/secrets/openrouter_api_key";

  # Wrapped rather than plain pkgs.opencode: --run executes before the...

  # Wrapped rather than plain pkgs.opencode: --run executes before the real
  # binary and its exports survive into it, so the key is scoped to opencode
  # instead of every shell. Missing secret -> unset var and opencode's own auth
  # error, which is clearer than a wrapper failing first.

  opencode = pkgs.symlinkJoin {
    name = "opencode-wrapped";
    paths = [ pkgs.opencode ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/opencode \
        --run 'if [ -r "${keyFile}" ]; then export OPENROUTER_API_KEY="$(cat "${keyFile}")"; fi'
    '';
  };
in
{
  home.packages = [ opencode ];

  # opencode global config. Darwin-only: it registers the OpenPencil...

  # opencode global config. Darwin-only: it registers the OpenPencil MCP server,
  # which reads and writes the document — open/save .fig, create and modify
  # nodes, components and instances, and bind design variables.

  # Run over npx rather than a global `npm install -g @open-pencil/mcp`, so
  # nothing has to be installed outside nix for this file to work. The tradeoff
  # is that the version is not pinned; pin it here if that ever matters.

  # force = true because opencode may rewrite this file at runtime; declare new
  # MCP servers here rather than via the opencode CLI.

  xdg.configFile."opencode/opencode.json" = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    force = true;
    text = builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";

      # Default for anything without its own entry below

      model = qwen;

      # Title generation, summarising, and other incidental calls. Left on...

      # Title generation, summarising, and other incidental calls. Left on the
      # cheap model deliberately: routing these to `strong` would quietly spend
      # most of the budget on work that is not the thing being tested.

      small_model = qwen;

      agent = {

        # Read-only exploration and planning — where a weak model's mistakes...

        # Read-only exploration and planning — where a weak model's mistakes are
        # most expensive, because a bad plan misdirects every edit that follows.

        plan.model = planModel;

        # The implementation loop. This is the model actually under test

        build.model = qwen;
      };

      mcp.openpencil = {

        # -p names the package, then the binary: the package is

        # @open-pencil/mcp but the executable is openpencil-mcp, and plain
        # `npx -y @open-pencil/mcp` fails with "could not determine executable".

        command = [
          "npx"
          "-y"
          "-p"
          "@open-pencil/mcp"
          "openpencil-mcp"
        ];
        enabled = true;
        type = "local";
      };
    };
  };
}
