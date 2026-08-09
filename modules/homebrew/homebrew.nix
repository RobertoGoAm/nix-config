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

  # No taps. Everything comes from homebrew-core and homebrew-cask, which are
  # reviewed; personal taps are not, and Homebrew refuses to load one without an
  # explicit `brew trust`.

  # rtk: the token-optimising CLI proxy the Claude Code hooks rewrite through.
  # Resolves to homebrew/core — same upstream as the old rtk-ai/tap formula,
  # Apache-2.0 and bottled, and ahead of the version that tap pinned.
  homebrew.brews = [ "rtk" ];

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
