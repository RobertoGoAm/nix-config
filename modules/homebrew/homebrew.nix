{
  inputs,
  user,
  ...
}:
{
  nix-homebrew = {
    inherit user;
    enable = true;
    autoMigrate = true;
  };
}
