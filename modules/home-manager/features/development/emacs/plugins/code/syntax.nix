# development emacs plugins code syntax

{
  lib,
  ...
}:
{

  # Every treesit grammar nixpkgs ships, less the CUDA one

  # ~with-all-grammars~ would be the whole set in one word. It is spelled out as a
  # filter instead because ~tree-sitter-cuda~'s pinned source hash no longer matches
  # the tarball GitHub serves for the tag:

  #   specified: sha256-QGNCld6J0eTPDv+VjjtGuv5/6SCJx8iSMECQTN01V6Q=
  #      got:    sha256-s2qrZx5fEu/I6xE2paX/Nlmgvo6T27qqvy1cI8iznAA=

  # A fixed-output derivation that cannot be fetched fails identically for everyone
  # on that nixpkgs, and it takes the whole grammar link farm with it -- which is
  # Emacs, which is the home-manager generation, which is the system. Overriding the
  # hash locally would mean accepting a tarball whose contents nobody here has
  # checked, so the grammar is dropped instead: nothing in this configuration reads
  # CUDA.

  # Back to ~with-all-grammars~ once nixpkgs repins it.

  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      evil-textobj-tree-sitter
      (treesit-grammars.with-grammars (g: lib.attrValues (lib.removeAttrs g [ "tree-sitter-cuda" ])))
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
