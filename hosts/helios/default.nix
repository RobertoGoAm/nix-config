{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix

    ../common/global
    ../common/optional/fail2ban
    ../common/optional/gnome
    ../common/optional/pipewire
    ../common/optional/systemd-boot
    ../common/optional/tlp
    ../common/optional/wireless
    ../common/optional/x11
    ../common/users/robertogoam
  ];

  networking = {
    hostName = "helios";
    networkmanager.enable = true;
  };

  powerManagement.powertop.enable = true;

  programs = {
    dconf.enable = true;
  };

  system.stateVersion = "24.05";
}
