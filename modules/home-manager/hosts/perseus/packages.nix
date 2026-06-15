{
  pkgs,
  ...
}:
let
  privatePath = "/Users/robertogoam/.config/nix-secrets/work-extras.nix";
  private =
    if builtins.pathExists privatePath then
      import privatePath { inherit pkgs; }
    else
      {
        linuxPackages = [ ];
      };
in
{
  home.packages =
    (with pkgs; [
      # Desktop
      gnomeExtensions.forge
      gnomeExtensions.space-bar

      # Development
      ghc
      gcc
      gnumake
      haskell-language-server
      nixd
      nixfmt

      # Internet
      google-chrome

      # Media
      spotify
      vlc

      # Productivity
      gnome-calendar
      obsidian
      remnote

      # Security
      bitwarden-desktop
      libsecret

      # Social
      discord
      telegram-desktop

      # Tool
      fasd
      gnutar
      nanum
      nerd-fonts.jetbrains-mono
      qbittorrent
      xclip

      # Machine-local extras (see ~/.config/nix-secrets/work-extras.nix)
    ])
    ++ private.linuxPackages;
}
