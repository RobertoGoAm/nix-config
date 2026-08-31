# development emacs plugins ui icons

{
  ...
}:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      nerd-icons
    ];

  programs.emacs.extraConfig = ''
    ;;; Icons — nerd-icons in place of nvim-web-devicons.
    ;;;
    ;;; Both read the same glyphs out of the same font, so file-type icons look
    ;;; identical to nvim. The font arrives from
    ;;; hosts/prometheus/packages.nix (nerd-fonts.jetbrains-mono); unlike
    ;;; nerd-icons' usual M-x nerd-icons-install-fonts dance, nix has already put it
    ;;; in place.

    (require 'nerd-icons)
    (setq nerd-icons-font-family "JetBrainsMono Nerd Font"
          nerd-icons-scale-factor 1.0)
  '';
}
