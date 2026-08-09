{
  inputs,
  user,
  ...
}:
{
  nix-homebrew = {
    inherit user;
    enable = true;
    autoMigrate = true;
  };

  # One tap, and only because OpenPencil ships nowhere else. Everything else
  # comes from homebrew-core and homebrew-cask, which are reviewed; a personal
  # tap is not, and Homebrew refuses to load one without `brew trust
  # zseven-w/openpencil` — run once per machine.
  #
  # It must stay tap-qualified in the cask list: homebrew-cask has an unrelated
  # project under the same `openpencil` token (net.dannote.open-pencil, a
  # Figma-compatible editor), and the bare name resolves to that one.
  homebrew.taps = [ "zseven-w/openpencil" ];

  # op: the OpenPencil CLI, which drives the editor over its HTTP MCP transport.
  # rtk: the token-optimising CLI proxy the Claude Code hooks rewrite through.
  # rtk resolves to homebrew/core — same upstream as the old rtk-ai/tap formula,
  # Apache-2.0 and bottled, and ahead of the version that tap pinned.
  homebrew.brews = [
    "op"
    "rtk"
  ];

  # Declaring a cask only ever installed it; rebuilds left the version alone and
  # the apps drifted until each one nagged about its own update. Refresh the tap
  # metadata first, then upgrade, so a rebuild converges casks the way it already
  # converges everything else. Casks marked `auto_updates` upstream are skipped
  # unless they opt in with `greedy = true`.
  #
  # cleanup is deliberately left at "none": undeclared casks are still installed
  # by hand on these machines, and "uninstall" would remove all of them.
  homebrew.onActivation = {
    autoUpdate = true;
    upgrade = true;
  };
}
