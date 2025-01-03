{
  pkgs,
  ...
}:
{

  home.packages = with pkgs; [
    # Development
    nixd
    nixfmt-rfc-style

    # Tool
    nerd-fonts.jetbrains-mono

    # Work
    git-credential-manager
  ];
}
