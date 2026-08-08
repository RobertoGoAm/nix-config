{
  # Vorssaint preferences, pinned declaratively. targets.darwin.defaults writes
  # only the keys listed here and leaves the rest of the domain alone, but these
  # keys are reset to these values on every activation.
  #
  # Not expressible as Nix values, so left under the app's own control:
  #   shelfItems (data blob)
  targets.darwin.defaults."com.vorssaint.utils" = {
    "NSStatusItem Preferred Position VorssaintMenuBarItem" = 472.0;
    "defaultDurationMinutes" = 0;
    "featureAvailable.appUpdates" = true;
    "featureAvailable.autoQuit" = true;
    "featureAvailable.brightness" = true;
    "featureAvailable.cameraPreview" = true;
    "featureAvailable.cleaner" = true;
    "featureAvailable.cleaningMode" = true;
    "featureAvailable.clipboardHistory" = false;
    "featureAvailable.colorPicker" = true;
    "featureAvailable.commandBar" = false;
    "featureAvailable.dockClick" = true;
    "featureAvailable.dockPreview" = true;
    "featureAvailable.extraBrightness" = true;
    "featureAvailable.finderCutPaste" = true;
    "featureAvailable.finderRename" = false;
    "featureAvailable.homebrew" = true;
    "featureAvailable.keepAwake" = true;
    "featureAvailable.keyboardDebounce" = false;
    "featureAvailable.mediaTools" = true;
    "featureAvailable.micMute" = true;
    "featureAvailable.middleClick" = false;
    "featureAvailable.mixer" = true;
    "featureAvailable.monitorCPU" = true;
    "featureAvailable.monitorDisk" = true;
    "featureAvailable.monitorGPU" = true;
    "featureAvailable.monitorMemory" = true;
    "featureAvailable.monitorNetwork" = true;
    "featureAvailable.monitorPower" = true;
    "featureAvailable.mouseButtonShortcuts" = false;
    "featureAvailable.mouseNavigation" = false;
    "featureAvailable.musicBlock" = true;
    "featureAvailable.pastePlain" = true;
    "featureAvailable.quickLauncher" = true;
    "featureAvailable.quickToggles" = true;
    "featureAvailable.radialMenu" = false;
    "featureAvailable.scratchpad" = true;
    "featureAvailable.screenOCR" = true;
    "featureAvailable.screenRecorder" = true;
    "featureAvailable.screenshot" = true;
    "featureAvailable.scrollInverter" = false;
    "featureAvailable.shelf" = true;
    "featureAvailable.smoothScroll" = false;
    "featureAvailable.soundOutputSwitcher" = false;
    "featureAvailable.superKey" = false;
    "featureAvailable.switcher" = true;
    "featureAvailable.textSnippets" = false;
    "featureAvailable.uninstaller" = true;
    "featureAvailable.urlCleaner" = true;
    "featureAvailable.windowLayout" = false;
    "featureAvailable.windowMaximizer" = true;
    "featuresOnboardingVersion" = 4;
    "hasOnboarded" = true;
    "keepAwakeActiveIcon" = "vorssaint";
    "keepAwakeIconTint" = "orange";
    "keepAwakeMouseJiggleIntervalMinutes" = 5;
    "lastUpdateIntroVersion" = "3.3.0";
    "onboardingStep" = 0;
    "panelCollapsedResetVersion" = "2.15.1";
    "supportUpdateIntroVersion" = "3.3.0";
    "updateHighlightsSeenVersion" = "3.3.0";
  };
}
