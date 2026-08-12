{
  ...
}:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      focus
      olivetti
    ];

  programs.emacs.extraConfig = ''
    ;;; Twilight — focus.el dims everything outside the block you are editing.
    ;;;
    ;;; twilight.nvim dims by tree-sitter node; focus.el dims by the thing
    ;;; `thing-at-point' calls the enclosing unit, which for code lands on the same
    ;;; defun or block. olivetti comes along for the prose case: centred, narrowed
    ;;; text for markdown and commit messages.

    (require 'focus)
    (setq focus-dimness 20)

    (require 'olivetti)
    (setq olivetti-body-width 100
          olivetti-minimum-body-width 72
          olivetti-style 'fancy)

    (defun my/toggle-twilight ()
      "Toggle the dimmed-surroundings view."
      (interactive)
      (focus-mode 'toggle))

    (defun my/toggle-zen ()
      "Toggle centred prose mode."
      (interactive)
      (olivetti-mode 'toggle))
  '';
}
