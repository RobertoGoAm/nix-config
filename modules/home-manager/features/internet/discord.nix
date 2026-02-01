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
