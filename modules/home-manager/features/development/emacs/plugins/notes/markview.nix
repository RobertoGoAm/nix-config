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

    (setq markdown-command "pandoc"
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

    ;; Toggling the markup back on is useful while editing raw markdown.
    (defun my/toggle-markdown-markup ()
      "Show or hide the markdown markup characters."
      (interactive)
      (setq-local markdown-hide-markup (not markdown-hide-markup))
      (font-lock-flush)
      (message "Markdown markup %s" (if markdown-hide-markup "hidden" "shown")))
  '';
}
