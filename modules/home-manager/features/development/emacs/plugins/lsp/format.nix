# development emacs plugins lsp format

{
  lib,
  pkgs,
  ...
}:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      apheleia
    ];

  home.packages = with pkgs; [
    black
    nixfmt
    pgformatter
    prettierd
    stylua
    yamlfmt
  ];

  programs.emacs.extraConfig = ''
        ;;; Format on save — apheleia in place of conform.nvim.
        ;;;
        ;;; apheleia formats in a subprocess and splices the result back without moving
        ;;; point, so unlike a naive before-save-hook it never fights the cursor.

        (require 'apheleia)

        ;; conform lists prettierd before prettier with stop_after_first, and nix
        ;; guarantees prettierd is present, so prettierd is simply the formatter. It
        ;; still honours each project's own prettier config and version.
        (dolist (entry
                 '((prettierd   . ("${lib.getExe pkgs.prettierd}" filepath))
                   (stylua      . ("${lib.getExe pkgs.stylua}" "--stdin-filepath" filepath "-"))
                   (nixfmt      . ("${lib.getExe pkgs.nixfmt}"))
                   (black       . ("${lib.getExe pkgs.black}" "-q" "-"))
                   (yamlfmt     . ("${lib.getExe pkgs.yamlfmt}" "-in"))
                   (pgformatter . ("${pkgs.pgformatter}/bin/pg_format"))))
          (setf (alist-get (car entry) apheleia-formatters) (cdr entry)))

        ;; formattersByFt, mode for mode.
        (dolist (entry '((css-ts-mode        . prettierd)
                         (css-mode           . prettierd)
                         (scss-mode          . prettierd)
                         (less-css-mode      . prettierd)
                         (html-mode          . prettierd)
                         (mhtml-mode         . prettierd)
                         (html-ts-mode       . prettierd)
                         (web-mode           . prettierd)
                         (js-mode            . prettierd)
                         (js-ts-mode         . prettierd)
                         (jsx-mode           . prettierd)
                         (typescript-mode    . prettierd)
                         (typescript-ts-mode . prettierd)
                         (tsx-ts-mode        . prettierd)
                         (json-mode          . prettierd)
                         (json-ts-mode       . prettierd)
                         (markdown-mode      . prettierd)
                         (gfm-mode           . prettierd)
                         (graphql-mode       . prettierd)
                         (lua-mode           . stylua)
                         (lua-ts-mode        . stylua)
                         (nix-mode           . nixfmt)
                         (nix-ts-mode        . nixfmt)
                         (python-mode        . black)
                         (python-ts-mode     . black)
                         (yaml-mode          . yamlfmt)
                         (yaml-ts-mode       . yamlfmt)
                         (sql-mode           . pgformatter)))
          (setf (alist-get (car entry) apheleia-mode-alist) (cdr entry)))

        ;; format_on_save
        (apheleia-global-mode 1)

        (defun my/format-fallback-to-lsp ()
          "Let the language server format buffers apheleia has no formatter for.
    conform's `lspFallback = true', for Go, Haskell, Prisma and anything else whose
    server formats but has no standalone binary here."
          (when (and (bound-and-true-p lsp-mode)
                     (not (alist-get major-mode apheleia-mode-alist)))
            (ignore-errors (lsp-format-buffer))))

        (add-hook 'before-save-hook #'my/format-fallback-to-lsp)

        (defun my/format-buffer ()
          "Format now, without waiting for a save."
          (interactive)
          (if (alist-get major-mode apheleia-mode-alist)
              (apheleia-format-buffer (alist-get major-mode apheleia-mode-alist))
            (if (bound-and-true-p lsp-mode)
                (lsp-format-buffer)
              (message "No formatter for %s" major-mode))))
  '';
}
