{
  # IINA preferences, pinned declaratively. targets.darwin.defaults writes
  # only the keys listed here and leaves the rest of the domain alone, but these
  # keys are reset to these values on every activation.
  #
  # Not expressible as Nix values, so left under the app's own control:
  #   iinaLastPlayedFilePath (data blob)
  targets.darwin.defaults."com.colliderli.iina" = {
    "MainWindowLastPosition" = "{{91, 165}, {1699, 955}}";
    "NSFullScreenMenuItemEverywhere" = false;
    "NSSplitView Subview Frames NSColorPanelSplitView" = [
      "0.000000, 0.000000, 230.000000, 262.000000, NO, NO"
      "0.000000, 263.000000, 230.000000, 67.000000, NO, NO"
    ];
    "NSToolbar Configuration com.apple.NSColorPanel" = {
      "TB Is Shown" = 1;
    };
    "NSWindow Frame IINAOpenURLWindow" = "612 438 576 262 0 0 1800 1130 ";
    "NSWindow Frame IINAWelcomeWindow" = "580 365 640 400 0 0 1800 1130 ";
    "NSWindow Frame NSColorPanel" = "53 83 250 297 0 0 1800 1130 ";
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
    "iinaLastPlayedFilePosition" = 766.14;
    "softVolume" = 100.0;
  };
}
