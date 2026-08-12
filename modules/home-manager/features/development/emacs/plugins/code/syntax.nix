{
  ...
}:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      evil-textobj-tree-sitter
      treesit-grammars.with-all-grammars
    ];

  programs.emacs.extraConfig = ''
    ;;; Syntax — Emacs 30's built-in treesit, with the grammars from nixpkgs, and
    ;;; evil-textobj-tree-sitter for the nvim-treesitter-textobjects keymap.

    (require 'treesit)
    ;; highlight.enable, at the richest level treesit offers. Level 3 is the default;
    ;; 4 adds the finer distinctions (property vs variable, operators, brackets) that
    ;; nvim-treesitter shows.
    (setq treesit-font-lock-level 4)

    ;; The textobject keymap, verbatim from the treesitter-textobjects select block.
    ;; `lookahead' is treesit-textobj's default: the cursor need not already be
    ;; inside the node.
    (require 'evil-textobj-tree-sitter)

    ;; Written out one key at a time rather than looped, because
    ;; `evil-textobj-tree-sitter-get-textobj' is a macro: it builds the query name
    ;; from its *unevaluated* argument, so a computed `(concat ...)' never reaches it
    ;; as a string. Each group has to be a literal here.
    (define-key evil-outer-text-objects-map "a"
                (evil-textobj-tree-sitter-get-textobj "parameter.outer"))
    (define-key evil-inner-text-objects-map "a"
                (evil-textobj-tree-sitter-get-textobj "parameter.inner"))
    (define-key evil-outer-text-objects-map "f"
                (evil-textobj-tree-sitter-get-textobj "function.outer"))
    (define-key evil-inner-text-objects-map "f"
                (evil-textobj-tree-sitter-get-textobj "function.inner"))
    (define-key evil-outer-text-objects-map "c"
                (evil-textobj-tree-sitter-get-textobj "class.outer"))
    (define-key evil-inner-text-objects-map "c"
                (evil-textobj-tree-sitter-get-textobj "class.inner"))
    (define-key evil-outer-text-objects-map "i"
                (evil-textobj-tree-sitter-get-textobj "conditional.outer"))
    (define-key evil-inner-text-objects-map "i"
                (evil-textobj-tree-sitter-get-textobj "conditional.inner"))
    (define-key evil-outer-text-objects-map "l"
                (evil-textobj-tree-sitter-get-textobj "loop.outer"))
    (define-key evil-inner-text-objects-map "l"
                (evil-textobj-tree-sitter-get-textobj "loop.inner"))

    ;; "at" = @comment.outer. The nvim map has no inner counterpart for comments.
    (define-key evil-outer-text-objects-map "t"
                (evil-textobj-tree-sitter-get-textobj "comment.outer"))

    ;; The treesitter `move' block: ]m/[m to a function, ]M/[M to its end, and the
    ;; bracket pairs for classes.
    (evil-define-key '(normal visual) 'global
      (kbd "]m") (lambda () (interactive)
                   (evil-textobj-tree-sitter-goto-textobj "function.outer"))
      (kbd "[m") (lambda () (interactive)
                   (evil-textobj-tree-sitter-goto-textobj "function.outer" t))
      (kbd "]M") (lambda () (interactive)
                   (evil-textobj-tree-sitter-goto-textobj "function.outer" nil t))
      (kbd "[M") (lambda () (interactive)
                   (evil-textobj-tree-sitter-goto-textobj "function.outer" t t))
      (kbd "]]") (lambda () (interactive)
                   (evil-textobj-tree-sitter-goto-textobj "class.outer"))
      (kbd "[[") (lambda () (interactive)
                   (evil-textobj-tree-sitter-goto-textobj "class.outer" t))
      (kbd "][") (lambda () (interactive)
                   (evil-textobj-tree-sitter-goto-textobj "class.outer" nil t))
      (kbd "[]") (lambda () (interactive)
                   (evil-textobj-tree-sitter-goto-textobj "class.outer" t t)))
  '';
}
