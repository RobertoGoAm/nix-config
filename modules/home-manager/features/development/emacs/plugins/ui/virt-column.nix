{
  ...
}:
{
  programs.emacs.extraConfig = ''
    ;;; Column guides — display-fill-column-indicator, the built-in.
    ;;;
    ;;; This is the one honest downgrade in the UI layer: virt-column draws guides at
    ;;; 80, 120 and 140, while Emacs' indicator is a single column because it is
    ;;; implemented as a display property on the fill column itself, not as overlays.
    ;;; The first guide is the one that matters, so 80 is drawn properly and the
    ;;; other two are left out rather than faked with something that would fight
    ;;; `truncate-lines'.

    (setq-default fill-column 80)
    (custom-set-faces
     `(fill-column-indicator ((t (:foreground ,(my/tn 'bg-hl) :background unspecified)))))

    ;; The exclude list, matching the virt-column settings: no guides in the popups,
    ;; the terminal, help buffers, or prose.
    (defvar my/fill-column-excluded-modes
      '(dashboard-mode
        gfm-mode
        git-commit-mode
        help-mode
        lsp-treemacs-error-list-mode
        man-common
        markdown-mode
        special-mode
        term-mode
        text-mode
        treemacs-mode
        vterm-mode)
      "Modes that never draw a column guide.")

    (defun my/maybe-fill-column-indicator ()
      "Draw the guide unless this mode is excluded."
      (unless (or (apply #'derived-mode-p my/fill-column-excluded-modes)
                  (minibufferp))
        (display-fill-column-indicator-mode 1)))

    (add-hook 'prog-mode-hook #'my/maybe-fill-column-indicator)
    (add-hook 'conf-mode-hook #'my/maybe-fill-column-indicator)
  '';
}
