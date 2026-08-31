# development emacs plugins code comments

{
  ...
}:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      consult-todo
      evil-nerd-commenter
      hl-todo
      magit-todos
    ];

  programs.emacs.extraConfig = ''
    ;;; Comments — evil-nerd-commenter for the gc operator, hl-todo + magit-todos
    ;;; for todo-comments.nvim.

    ;; evil ships no gc operator of its own, so this is where `gcc' and `gcip' come
    ;; from. It is a real operator, which means it composes with the rotated motions:
    ;; `gcn' comments this line and the one below.
    (require 'evil-nerd-commenter)
    (evil-define-key '(normal visual) 'global
      "gc" #'evilnc-comment-operator
      "gy" #'evilnc-copy-and-comment-operator)

    ;; The keyword set todo-comments.nvim highlights by default.
    (require 'hl-todo)
    (setq hl-todo-keyword-faces
          '(("TODO"  . "#e0af68")
            ("FIXME" . "#f7768e")
            ("BUG"   . "#f7768e")
            ("HACK"  . "#ff9e64")
            ("WARN"  . "#ff9e64")
            ("WARNING" . "#ff9e64")
            ("PERF"  . "#9d7cd8")
            ("NOTE"  . "#7dcfff")
            ("TEST"  . "#9ece6a")
            ("XXX"   . "#f7768e")))
    (global-hl-todo-mode 1)

    ;; TodoTelescope's two halves: consult-todo searches them like any other consult
    ;; source, and magit-todos surfaces them inside the git status buffer.
    (require 'consult-todo)
    (with-eval-after-load 'magit
      (require 'magit-todos)
      (setq magit-todos-exclude-globs '("*.map" "node_modules/*" ".git/*"))
      (magit-todos-mode 1))

    (defun my/todos-project ()
      "Every TODO in the project — TodoTelescope."
      (interactive)
      (if (fboundp 'consult-todo-project)
          (consult-todo-project)
        (consult-todo)))
  '';
}
