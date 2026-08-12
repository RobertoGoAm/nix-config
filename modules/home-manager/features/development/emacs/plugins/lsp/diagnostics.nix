{
  lib,
  pkgs,
  ...
}:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      consult-flycheck
      flycheck
      flycheck-projectile
    ];

  home.packages = with pkgs; [
    statix
    yamllint
  ];

  programs.emacs.extraConfig = ''
        ;;; Diagnostics — flycheck feeds lsp-mode, and lsp-treemacs plays the part of
        ;;; trouble.nvim's list.

        (require 'flycheck)
        (require 'consult-flycheck)
        ;; The project-wide error list `my/diagnostics-list' falls back to.
        (require 'flycheck-projectile)

        ;; none-ls runs with updateInInsert = false, so nothing re-lints mid-keystroke.
        ;; Checking on save and on mode-enable is the closest equivalent and stops the
        ;; sideline flickering while you type.
        (setq flycheck-check-syntax-automatically '(save mode-enabled)
              flycheck-display-errors-delay 0.3
              flycheck-help-echo-function nil
              ;; Terminal frames have no fringe to draw a sign in.
              flycheck-indication-mode (if (display-graphic-p) 'left-fringe 'left-margin))
        (global-flycheck-mode 1)

        ;; The gutter glyphs, matching the diagnostics symbols the statusline uses.
        (setq flycheck-error-list-format
              `[("Line" 5 flycheck-error-list-entry-< :right-align t)
                ("Col" 3 nil :right-align t)
                ("Level" 8 flycheck-error-list-entry-level-<)
                ("ID" 6 t)
                (,(flycheck-error-list-make-last-column "Message" 'Checker) 0 t)])

        ;; statix, as none-ls runs it for nix — code smells and the fixes for them.
        ;; --format=errfmt gives one finding per line, which is what this pattern reads;
        ;; a format change upstream shows up as "no findings", never as an error.
        ;; Checked against the saved file rather than stdin: statix resolves imports
        ;; relative to the file, and flycheck only runs on save here anyway.
        (flycheck-define-checker my/nix-statix
          "A nix linter using statix."
          :command ("${lib.getExe pkgs.statix}" "check" "--format=errfmt" source-original)
          :predicate (lambda () (and buffer-file-name (not (buffer-modified-p))))
          :error-patterns
          ((warning line-start (file-name) ">" line ":" column ":"
                    (id (one-or-more (not (any ":")))) ":"
                    (message (one-or-more not-newline)) line-end))
          :modes (nix-mode nix-ts-mode))
        (add-to-list 'flycheck-checkers 'my/nix-statix)

        ;; yamllint, also from the none-ls source list. flycheck ships the checker; it
        ;; only needs the binary, which arrives in home.packages above.
        (setq flycheck-yamllintrc ".yamllint")

        (defun my/diagnostics-list ()
          "Project-wide diagnostics list — the `Trouble' reflex.
    Prefers lsp-treemacs when a server is attached (it groups by file and follows the
    workspace) and falls back to flycheck's own project list otherwise."
          (interactive)
          (if (bound-and-true-p lsp-mode)
              (lsp-treemacs-errors-list)
            (flycheck-projectile-list-errors)))

        (defun my/diagnostics-buffer ()
          "Diagnostics for this buffer, as a searchable list."
          (interactive)
          (consult-flycheck))

        (defun my/diagnostic-at-point ()
          "Explain the diagnostic under the cursor — vim.diagnostic.open_float()."
          (interactive)
          (if (and (bound-and-true-p lsp-ui-mode) (lsp-ui-doc--visible-p))
              (lsp-ui-doc-hide)
            (or (ignore-errors (flycheck-display-error-at-point))
                (message "No diagnostic at point"))))

        (defun my/diagnostic-explain ()
          "Full explanation for the diagnostic under the cursor."
          (interactive)
          (or (ignore-errors (flycheck-explain-error-at-point))
              (ignore-errors (flycheck-display-error-at-point))
              (message "No diagnostic at point")))
  '';
}
