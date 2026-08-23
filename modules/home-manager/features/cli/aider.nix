{ lib, pkgs, ... }:
let
  # Same models and the same credential as features/cli/opencode.nix -- see the
  # comments there for the slugs and prices. Kept as two literals rather than
  # imported so each tool's file reads on its own.
  qwen = "openrouter/qwen/qwen3.8-27b";
  strong = "openrouter/anthropic/claude-sonnet-4.5";
  keyFile = "/var/run/secrets/openrouter_api_key";

  aider = pkgs.symlinkJoin {
    name = "aider-wrapped";
    paths = [ pkgs.aider-chat ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/aider \
        --run 'if [ -r "${keyFile}" ]; then export OPENROUTER_API_KEY="$(cat "${keyFile}")"; fi'
    '';
  };
in
{
  # The wrapper only, never pkgs.aider-chat alongside it: two paths claiming
  # bin/aider collide when home-manager builds the profile (buildEnv exit 25),
  # the same trap the antigravity module documents for bin/agy.
  home.packages = [ aider ];

  # Architect mode is the reason aider is here alongside opencode: `model` plans
  # the change and `editor-model` writes the diff, per edit rather than per
  # session. That is a closer fit to "a better model plans, Qwen implements" than
  # a pair of agents each pinned to one model.
  #
  # Not force = true: aider writes nothing to this file at runtime, and leaving
  # it writable means a one-off `--model x` experiment does not fight the config.
  home.file.".aider.conf.yml".text = ''
    # Managed by nix (features/cli/aider.nix).
    architect: true
    model: ${strong}
    editor-model: ${qwen}

    # Ask before touching anything not already in the chat, and never commit on
    # aider's behalf -- commits here are Conventional and scoped by hand.
    auto-commits: false
    dirty-commits: false
    gitignore: false

    # aider maintains its own map of the repo; on a large tree the default budget
    # crowds out the actual conversation.
    map-tokens: 2048
  '';
}
