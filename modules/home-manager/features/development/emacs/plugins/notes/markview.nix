{
  ...
}:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      markdown-mode
    ];

  programs.emacs.extraConfig = ''
    ;;; Markdown — markdown-mode in place of markview.nvim.
    ;;;
    ;;; markview renders markup inline: headings styled, emphasis markers hidden,
    ;;; code blocks boxed. markdown-mode does the same through `markdown-hide-markup'
    ;;; plus its own faces, and unlike markview it also knows how to follow and
    ;;; create links, which is what makes the obsidian layer above it work.

    (require 'markdown-mode)

    ;; setq-default, not setq. markdown-hide-markup, markdown-hide-urls and
    ;; markdown-enable-math are automatically buffer-local, so a plain `setq' here
    ;; only bound them in whatever buffer init happened to be in and left the
    ;; global default untouched -- which is why hide-markup read nil in every
    ;; markdown buffer and the inline-rendered look never actually appeared.
    ;; setq-default is identical to setq for the non-local ones in this list.
    (setq-default markdown-command "pandoc"
          markdown-enable-math t
          markdown-enable-wiki-links t
          markdown-wiki-link-search-type '(project)
          markdown-fontify-code-blocks-natively t
          markdown-hide-urls nil
          ;; The inline-rendered look: emphasis and heading markers stay out of the
          ;; way until the cursor is on them.
          markdown-hide-markup t
          markdown-header-scaling t
          markdown-list-item-bullets '("•" "◦" "▪" "▫"))

    ;; GitHub-flavoured markdown for READMEs and for the GhostText buffers that come
    ;; back from GitHub and GitLab comment boxes.
    (add-to-list 'auto-mode-alist '("README\\.md\\'" . gfm-mode))
    (add-to-list 'auto-mode-alist '("\\.markdown\\'" . markdown-mode))

    ;; The two things markdown-hide-markup alone does not give you, and the two
    ;; that make Obsidian's editor feel different: images shown in place, and
    ;; prose in a proportional face while code stays monospaced.
    ;;
    ;; variable-pitch has to be applied per-face rather than by turning on
    ;; variable-pitch-mode wholesale -- that would reflow code blocks, tables and
    ;; the list bullets above, where column alignment is the whole point.
    (defun my/markdown-prose-faces ()
      "Proportional prose, monospaced code, inside a markdown buffer."
      (variable-pitch-mode 1)
      (dolist (face '(markdown-code-face
                      markdown-pre-face
                      markdown-inline-code-face
                      markdown-table-face
                      markdown-language-keyword-face))
        (when (facep face)
          (set-face-attribute face nil :inherit 'fixed-pitch))))

    (add-hook 'markdown-mode-hook #'my/markdown-prose-faces)

    ;; Images inline, as in the Obsidian editor. Only on files: a GhostText buffer
    ;; from a comment box has no directory to resolve relative paths against.
    (defun my/markdown-show-images ()
      "Display inline images when the buffer is a file."
      (when buffer-file-name
        (ignore-errors (markdown-display-inline-images))))

    (add-hook 'markdown-mode-hook #'my/markdown-show-images)

    (defun my/toggle-markdown-images ()
      "Show or hide inline images."
      (interactive)
      (if (bound-and-true-p markdown-inline-image-overlays)
          (markdown-remove-inline-images)
        (markdown-display-inline-images)))

    ;; Toggling the markup back on is useful while editing raw markdown.
    (defun my/toggle-markdown-markup ()
      "Show or hide the markdown markup characters."
      (interactive)
      (setq-local markdown-hide-markup (not markdown-hide-markup))
      (font-lock-flush)
      (message "Markdown markup %s" (if markdown-hide-markup "hidden" "shown")))
  '';
}
