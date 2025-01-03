{
  programs.nixvim = {
    enable = true;
    defaultEditor = true;

    imports = [
      ./colorscheme.nix
      ./keybinds.nix
      ./options.nix
      ./plugins
    ];
  };
}
