# development emacs plugins notes markview

{
  pkgs,
  ...
}:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      markdown-mode
    ];

  # markdown-command shells out to this. Without it `markdown-export' and the
  # live HTML preview both fail with "pandoc: no such file or directory", which
  # is the kind of breakage that only shows up the first time you reach for it.
  home.packages = [ pkgs.pandoc ];

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

    ;; The third way to read a note, after the rendered look and the raw markup:
    ;; pandoc's HTML in a side window, which is where a table or a block of math
    ;; finally lays out the way it does in the Obsidian app.
    ;;
    ;; eww named explicitly rather than left to the default. markdown-mode picks
    ;; an embedded WebKit when the build has one, and notes from work must not
    ;; open in Emacs' xwidget.
    (setq markdown-live-preview-window-function #'markdown-live-preview-window-eww
          markdown-live-preview-delete-export 'delete-on-destroy)

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
    (defun my/markdown-code-faces ()
      "Keep code, tables and bullets monospaced under a proportional body face."
      (dolist (face '(markdown-code-face
                      markdown-pre-face
                      markdown-inline-code-face
                      markdown-table-face
                      markdown-language-keyword-face))
        (when (facep face)
          (set-face-attribute face nil :inherit 'fixed-pitch))))

    (defun my/markdown-images (enable)
      "Show inline images when ENABLE is non-nil, hide them otherwise.

    Guarded on `display-images-p' on both sides, because a terminal frame cannot
    show an image and asking anyway signals rather than declining: markdown-mode
    raises \"Cannot show images\" on the display side, and the remove side ends in
    a `clear-image-cache' that raises \"Window system frame should be used\".

    Only files get images at all -- a GhostText buffer from a comment box has no
    directory to resolve a relative path against."
      (when (display-images-p)
        (if enable
            (when buffer-file-name
              (ignore-errors (markdown-display-inline-images)))
          (markdown-remove-inline-images))))

    ;; One switch for the whole rendered look, because the three parts are only
    ;; useful together. Hiding the markup while the proportional face and the
    ;; inline images stay put is the state that gets in the way: raw markdown is
    ;; what you reach for when you want to edit the syntax, and then reflowed
    ;; prose and half-page images are still in front of it.
    ;;
    ;; `markdown-hide-markup' is the stored state rather than a variable of our
    ;; own. It is already buffer-local, and SPC T m flips it on its own.
    (defun my/markdown-render (enable)
      "Show the rendered look when ENABLE is non-nil, raw markdown otherwise."
      (setq-local markdown-hide-markup (and enable t))
      (variable-pitch-mode (if enable 1 -1))
      (my/markdown-images enable)
      (font-lock-flush))

    (defun my/markdown-toggle-render ()
      "Flip the buffer between the rendered look and raw markdown."
      (interactive)
      (my/markdown-render (not markdown-hide-markup))
      (message "Markdown %s" (if markdown-hide-markup "rendered" "raw")))

    (defun my/markdown-setup ()
      "Open a markdown buffer in the rendered look."
      (my/markdown-code-faces)
      (my/markdown-render t))

    (add-hook 'markdown-mode-hook #'my/markdown-setup)

    ;; The halves, still separately reachable, for when only one of them is in
    ;; the way.
    (defun my/toggle-markdown-images ()
      "Show or hide inline images."
      (interactive)
      (my/markdown-images (not (bound-and-true-p markdown-inline-image-overlays))))

    (defun my/toggle-markdown-markup ()
      "Show or hide the markdown markup characters, leaving the rest as it is."
      (interactive)
      (setq-local markdown-hide-markup (not markdown-hide-markup))
      (font-lock-flush)
      (message "Markdown markup %s" (if markdown-hide-markup "hidden" "shown")))
  '';
}
