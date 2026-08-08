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
