{
  config,
  nixgl,
  pkgs,
  ...
}:
{
  nixGL.packages = nixgl.packages;
  nixGL.defaultWrapper = "mesa";
  nixGL.installScripts = [ "mesa" ];

  home.packages = with pkgs; [
    (config.lib.nixGL.wrap ulauncher)
  ];

  systemd.user.services.ulauncher = {
    Unit = {
      Description = "ulauncher application launcher service";
      Documentation = "https://ulauncher.io";
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash -lc 'env WEBKIT_DISABLE_COMPOSITING_MODE=1 ${pkgs.ulauncher}/bin/ulauncher --hide-window --no-window-shadow'";
      Restart = "on-failure";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };

  xdg.configFile = {
    "ulauncher" = {
      recursive = true;
      source = ./config;
    };
  };
}
