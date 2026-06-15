{
  programs.nixvim = {
    enable = true;
    defaultEditor = true;

    # Nixvim evaluates plugins against its own nixpkgs instance (not the
    # host's), so system-level allowUnfree does not apply to cmp-spell etc.
    nixpkgs.config.allowUnfree = true;

    imports = [
      ./colorscheme.nix
      ./keybinds.nix
      ./options.nix
      ./plugins
    ];
  };
}
