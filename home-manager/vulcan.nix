{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  system,
  ...
}:
{
  nixpkgs = {
    overlays = [
      outputs.overlays.apple-silicon
    ];

    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };

  home = {
    homeDirectory = "/Users/robertogoam";
    stateVersion = "24.11";
    username = "robertogoam";

    packages = with pkgs; [
      # Development
      nixd
      nixfmt-rfc-style

      # Tool
      nerd-fonts.jetbrains-mono

      # Work
      git-credential-manager
    ];
  };

  programs.home-manager.enable = true;

  imports = [
    inputs.nixvim.homeManagerModules.nixvim
    ./features/cli
    ./features/development/git.nix
    ./features/development/java.nix
    ./features/development/nvim
    ./features/development/vscode
    ./features/internet/chromium.nix
    ./features/internet/firefox.nix
    ./features/media/yt-dlp.nix
  ];
}
