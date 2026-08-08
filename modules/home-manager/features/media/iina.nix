{
  # IINA preferences, pinned declaratively. targets.darwin.defaults writes
  # only the keys listed here and leaves the rest of the domain alone, but these
  # keys are reset to these values on every activation.
  #
  # Not expressible as Nix values, so left under the app's own control:
  #   iinaLastPlayedFilePath (data blob)
  #
  # Runtime state is deliberately left out — window frames, resume
  # positions, last-used tools and update-check stamps. Pinning those
  # resets them on every activation and makes the file churn on every
  # regeneration without a setting having changed:
  #   MainWindowLastPosition
  #   NSSplitView Subview Frames NSColorPanelSplitView
  #   NSToolbar Configuration com.apple.NSColorPanel
  #   NSWindow Frame IINAOpenURLWindow
  #   NSWindow Frame IINAWelcomeWindow
  #   NSWindow Frame NSColorPanel
  #   iinaLastPlayedFilePosition
  targets.darwin.defaults."com.colliderli.iina" = {
    "NSFullScreenMenuItemEverywhere" = false;
    "PluginEnabled.io.iina.opensub" = true;
    "PluginEnabled.io.iina.user-script" = true;
    "PluginEnabled.io.iina.ytdl" = true;
    "PluginOrder" = [
      "io.iina.ytdl"
      "io.iina.opensub"
      "io.iina.user-script"
    ];
    "SUAutomaticallyUpdate" = false;
    "SUEnableAutomaticChecks" = false;
    "SUHasLaunchedBefore" = true;
    "SUSendProfileInfo" = false;
    "controlBarPositionHorizontal" = 0.5;
    "controlBarPositionVertical" = 0.10000000149011612;
    "softVolume" = 100.0;
  };
}
