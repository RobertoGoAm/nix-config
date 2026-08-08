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

  # Third-party taps, declared so a fresh machine reproduces them. Two carry
  # nothing installed any more — pencil now comes from the official cask — but
  # they are recorded rather than silently dropped.
  #
  # rtk-ai/tap is untrusted in Homebrew's sense (a personal tap, unreviewed), so
  # `brew bundle` refuses to load its formula until `brew trust rtk-ai/tap` is
  # run once per machine. rtk is our own tool and sits in the Claude Code hook
  # path, so that trust is deliberate, not incidental.
  homebrew.taps = [
    "open-pencil/tap"
    "rtk-ai/tap"
    "zseven-w/openpencil"
  ];

  # rtk: the token-optimising CLI proxy the Claude Code hooks rewrite through.
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
