{
  # Managed through the module rather than home.packages so uv's settings have a
  # typed home when they are needed; nothing is declared yet, and with settings
  # empty the module writes no config file.
  programs.uv.enable = true;
}
