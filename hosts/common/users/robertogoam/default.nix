{
  pkgs,
  config,
  ...
}: {
  users.mutableUsers = false;
  users.users.robertogoam = {
    isNormalUser = true;
    extraGroups = ifTheyExist [
      "audio"
      "deluge"
      "docker"
      "git"
      "libvirtd"
      "lxd"
      "mysql"
      "network"
      "plugdev"
      "podman"
      "video"
      "wheel"
      "wireshark"
    ];
    hashedPasswordFile = config.sops.secrets.robertogoam-password.path;
  };

  sops.secrets.robertogoam-password = {
    sopsFile = ../../secrets.yaml;
    neededForUsers = true;
  };

  home-manager.users.robertogoam = import ../../../../home/robertogoam/${config.networking.hostName}.nix;
}
