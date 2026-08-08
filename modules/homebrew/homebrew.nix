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

  # No taps. Everything here comes from homebrew-core and homebrew-cask, which
  # are reviewed; personal taps are not, and Homebrew refuses to load them
  # without an explicit `brew trust`. The two pencil taps carried nothing
  # installed once pencil moved to the official cask, and rtk landed in
  # homebrew-core, so none of them earn their keep.

  # rtk: the token-optimising CLI proxy the Claude Code hooks rewrite through.
  # Resolves to homebrew/core/rtk — the same project as the old rtk-ai/tap
  # formula (same upstream, Apache-2.0, bottled) and ahead of the version the
  # tap was pinning.
  #
  # mas: the App Store CLI. brew bundle cannot process the `mas` lines the
  # masApps option generates without it, and the Brewfile lists brews before
  # mas entries, so declaring it here is enough to bootstrap itself.
  homebrew.brews = [
    "mas"
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
