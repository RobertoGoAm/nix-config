{
  # ImageOptim preferences, pinned declaratively. targets.darwin.defaults writes
  # only the keys listed here and leaves the rest of the domain alone, but these
  # keys are reset to these values on every activation.
  #
  # Not expressible as Nix values, so left under the app's own control:
  #   NSTableView Columns v3 Files (data blob)
  #   NSTableView Sort Ordering v2 Files (data blob)
  #   SULastCheckTime (date)
  targets.darwin.defaults."net.pornel.ImageOptim" = {
    "NSTableView Supports v2 Files" = true;
    "NSWindow Frame MainWindow" = "87 11 1200 1104 0 0 1800 1125 ";
    "SUHasLaunchedBefore" = true;
  };
}
