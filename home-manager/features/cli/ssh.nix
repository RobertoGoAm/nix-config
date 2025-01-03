{
  services = {
    fail2ban = {
      enable = true;
    };

    openssh = {
      enable = true;
      settings = {
        # Harden
        PasswordAuthentication = false;
        PermitRootLogin = "no";

        # Automatically remove stale sockets
        StreamLocalBindUnlink = "yes";

        X11Forwarding = true;
      };
    };
  };

  programs.ssh = {
    enable = true;
  };
}
