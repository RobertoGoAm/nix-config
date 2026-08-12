{
  ...
}:
{
  programs.emacs.extraConfig = ''
    ;;; Line numbers — numbertoggle's behaviour, and the prose-filetype layout.

    ;; Supplies the hanging indent on wrapped prose lines (nvim's breakindent).
    (require 'adaptive-wrap)

    ;; numbertoggle: relative numbers while you are moving, absolute while you are
    ;; typing. nvim gets this by flipping 'relativenumber'; here it is the same flip
    ;; on the evil insert-state hooks.
    (add-hook 'evil-insert-state-entry-hook
              (lambda () (setq-local display-line-numbers t)))
    (add-hook 'evil-insert-state-exit-hook
              (lambda () (setq-local display-line-numbers 'relative)))

    ;; Prose filetypes get no gutter at all — no numbers, no fold indicators — and
    ;; soft wrap at word boundaries with a hanging indent. Same three filetypes as
    ;; the nvim FileType autocmd: markdown, text and git commit messages.
    (defun my/prose-setup ()
      "The prose layout: no gutter, soft wrap, hanging indent."
      (setq-local display-line-numbers nil
                  truncate-lines nil
                  word-wrap t)
      (visual-line-mode 1)
      (adaptive-wrap-prefix-mode 1)
      (when (fboundp 'treesit-fold-indicators-mode)
        (treesit-fold-indicators-mode -1))
      (when (fboundp 'highlight-indent-guides-mode)
        (highlight-indent-guides-mode -1)))

    (dolist (hook '(markdown-mode-hook
                    gfm-mode-hook
                    text-mode-hook
                    git-commit-setup-hook))
      (add-hook hook #'my/prose-setup))
  '';
}
