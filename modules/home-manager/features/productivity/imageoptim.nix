{
  # ImageOptim preferences, pinned declaratively. targets.darwin.defaults writes
  # only the keys listed here and leaves the rest of the domain alone, but these
  # keys are reset to these values on every activation.
  #
  # Not expressible as Nix values, so left under the app's own control:
  #   NSTableView Columns v3 Files (data blob)
  #   NSTableView Sort Ordering v2 Files (data blob)
  #   SULastCheckTime (date)
  #
  # Runtime state is deliberately left out — window frames, resume
  # positions, last-used tools and update-check stamps. Pinning those
  # resets them on every activation and makes the file churn on every
  # regeneration without a setting having changed:
  #   NSWindow Frame MainWindow
  targets.darwin.defaults."net.pornel.ImageOptim" = {
    "NSTableView Supports v2 Files" = true;
    "SUHasLaunchedBefore" = true;
  };
}
