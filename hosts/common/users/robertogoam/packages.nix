{pkgs, ...}: {
  users.users.robertogoam.packages = with pkgs; [
    firefox
  ];
}
