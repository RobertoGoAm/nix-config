{ pkgs
, ...
}:
{
  home.packages = with pkgs; [
    ulauncher
  ];

  systemd.user.services.ulauncher = {
    Unit = {
      Description = "ulauncher application launcher service";
      Documentation = "https://ulauncher.io";
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash -lc '${pkgs.ulauncher}/bin/ulauncher --hide-window --no-window-shadow'";
      Restart = "on-failure";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
