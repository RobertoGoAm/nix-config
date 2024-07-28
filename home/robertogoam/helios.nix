{pkgs, ...}: {
  imports = [
    ./global
    ./features/desktop/gnome
    ./features/desktop/wireless
    ./features/productivity
    ./features/security
  ];
}
