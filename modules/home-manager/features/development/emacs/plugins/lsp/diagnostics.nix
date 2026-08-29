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
      flycheck-posframe
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

        ;; Errors in a popup at point, now that the sideline is off.
        ;;
        ;; lsp-ui-doc carries hover information -- types and signatures -- and
        ;; never diagnostics, so turning the sideline off would otherwise have
        ;; left errors visible only as a fringe mark until asked for. posframe
        ;; puts the message beside the cursor on the same terms.
        ;;
        ;; Asked per buffer, never once at load.
        ;;
        ;; This config runs Emacs as `emacs --fg-daemon', and a daemon has no
        ;; graphical frame when its init is read. `(display-graphic-p)' is
        ;; therefore nil at that moment, so a (when (display-graphic-p) ...)
        ;; wrapper around this block skipped it for the entire life of the
        ;; daemon -- for GUI frames opened later too. The mode was never hooked,
        ;; the border and inhibit functions never set, and diagnostics had
        ;; nowhere to be displayed however many of them arrived. Verified
        ;; against the running daemon: flycheck-mode-hook held only
        ;; flycheck-mode-set-explicitly and the border width was still 0.
        ;;
        ;; flycheck-mode-hook runs inside the buffer, in the frame showing it,
        ;; so the question gets a real answer there -- and the right one for a
        ;; GUI frame and an `emacsclient -nw' frame against the same daemon.
        (require 'flycheck-posframe)
        (setq flycheck-posframe-border-width 1
              ;; Not while typing: a popup that reappears on every keystroke in
              ;; a half-written expression is noise, and the error it reports is
              ;; usually about the half you have not finished writing.
              flycheck-posframe-inhibit-functions
              (list (lambda (&rest _) (bound-and-true-p company-backend))
                    (lambda (&rest _) (bound-and-true-p corfu--total))
                    #'evil-insert-state-p))

        (defun my/flycheck-display-setup ()
          "Pick how diagnostics are shown, from the frame this buffer is in.
    posframe needs a child frame, which a terminal cannot make; there the
    fringe is unavailable too, so the indicator moves to the margin."
          (setq-local flycheck-indication-mode
                      (if (display-graphic-p) 'left-fringe 'left-margin))
          (when (display-graphic-p)
            (flycheck-posframe-mode 1)))

        (add-hook 'flycheck-mode-hook #'my/flycheck-display-setup)
        ;; The project-wide error list `my/diagnostics-list' falls back to.
        (require 'flycheck-projectile)

        ;; idle-change is not a preference here, it is what makes LSP diagnostics
        ;; appear at all.
        ;;
        ;; With lsp-diagnostics-provider :flycheck the server pushes diagnostics
        ;; and lsp-diagnostics--flycheck-report decides whether to surface them:
        ;;
        ;;   (when (and (or (memq 'idle-change flycheck-check-syntax-automatically)
        ;;                  (and (memq 'save flycheck-check-syntax-automatically)
        ;;                       (not (buffer-modified-p))))
        ;;              lsp--cur-workspace)
        ;;
        ;; This list was '(save mode-enabled), so the only branch that could fire
        ;; needed an UNMODIFIED buffer. Every publish that arrived while the
        ;; buffer was dirty -- which is every publish caused by the edit you just
        ;; made -- was dropped on the floor. Errors effectively never showed:
        ;; not on the fringe, not in the posframe, not in the modeline count.
        ;;
        ;; The original reasoning (match none-ls's updateInInsert = false, do not
        ;; flicker while typing) still holds, and is now enforced where it
        ;; belongs instead: the idle delay below waits for a pause, and the
        ;; posframe's inhibit functions keep it quiet during insert state and
        ;; completion.
        (setq flycheck-check-syntax-automatically '(save mode-enabled idle-change)
              ;; Long enough to be a pause rather than a gap between keystrokes.
              flycheck-idle-change-delay 0.8
              flycheck-display-errors-delay 0.3
              flycheck-help-echo-function nil)
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
