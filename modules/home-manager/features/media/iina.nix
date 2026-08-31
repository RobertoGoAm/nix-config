# media iina

{ config, ... }:
{

  # com.colliderli.iina preferences, pinned declaratively....

  # com.colliderli.iina preferences, pinned declaratively. targets.darwin.defaults
  # writes only the keys listed here and leaves the rest of the domain
  # alone, but these keys are reset to these values on every activation.

  # Generated — change the setting in the app, then re-run:
  #   nix run .#pin-prefs -- com.colliderli.iina <this file>

  # Not expressible as Nix values, left to the app:
  #   iinaLastPlayedFilePath (data blob)

  # Runtime state, deliberately excluded:
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
    "controlBarPositionVertical" = 0.1;
    "softVolume" = 100.0;
  };
}
