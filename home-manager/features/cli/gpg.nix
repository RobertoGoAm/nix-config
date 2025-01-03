{
  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
  };

  programs =
    let
      fixGpg =
        /*
      bash
        */
        ''
          gpgconf --launch gpg-agent
        '';
    in
    {
      # Start gpg-agent if it's not running or tunneled in
      # SSH does not start it automatically, so this is needed to avoid having to use a gpg command at startup
      # https://www.gnupg.org/faq/whats-new-in-2.1.html#autostart
      bash.profileExtra = fixGpg;
      fish.loginShellInit = fixGpg;
      zsh.loginExtra = fixGpg;
      nushell.extraLogin = fixGpg;

      gpg = {
        enable = true;
      };
    };
}
