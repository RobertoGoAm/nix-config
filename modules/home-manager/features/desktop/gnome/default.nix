{
  dconf.settings = {
    # Extensions
    "org/gnome/shell" = {
      disable-user-extensions = false;
      disabled-extensions = [
        "disabled"
      ];
      enabled-extensions = [
        "forge@jmmaranan.com"
        "sp-tray@sp-tray.esenliyim.github.com"
      ];
    };

    "/org/gnome/shell/extensions/forge/" = {
      keybindings = {
        window-focus-up = [ "<Alt>e" ];
        window-focus-left = [ "<Alt>h" ];
        window-focus-right = [ "<Alt>i" ];
        window-focus-down = [ "<Alt>n" ];

        window-move-up = [ "<Alt><Shift>e" ];
        window-move-left = [ "<Alt><Shift>h" ];
        window-move-right = [ "<Alt><Shift>i" ];
        window-move-down = [ "<Alt><Shift>n" ];
      };
    };
  };
}
