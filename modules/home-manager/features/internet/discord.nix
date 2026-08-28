# Window geometry and hardware decoding

# Nothing subtle here: the settings block is the state Discord would otherwise
# write for itself on first run, pinned so a fresh machine opens the same
# window on the same display.

{ pkgs, ... }:
{
  programs.discord = {
    enable = true;
    settings = {
      BACKGROUND_COLOR = "#121214";
      IS_MAXIMIZED = false;
      IS_MINIMIZED = true;
      WINDOW_BOUNDS = {
        height = 1108;
        width = 1665;
        x = 125;
        y = 50;
      };
      asyncVideoInputDeviceInit = false;
      chromiumSwitches = { };
      enableHardwareAcceleration = true;
      offloadAdmControls = true;
    };
  };
}
