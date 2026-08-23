{
  ...
}:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      doom-modeline
      flycheck
      hide-mode-line
    ];

  programs.emacs.extraConfig = ''
    ;;; Statusline — doom-modeline, rebuilt segment by segment to match the eviline
    ;;; lualine config.
    ;;;
    ;;; doom-modeline's default layout looks nothing like eviline, so this defines
    ;;; the missing segments and composes its own modeline rather than accepting the
    ;;; preset: blue block, mode dot, filesize, filename, position, diagnostics, then
    ;;; encoding, line ending, branch, diff and a closing block. Same glyphs, same
    ;;; colours, same left-and-right split around a filler.

    (require 'cl-lib)
    (require 'doom-modeline)
    ;; The diagnostics segment reads flycheck's error counts, so flycheck has to be
    ;; loaded here rather than only in plugins/lsp/diagnostics.nix further down.
    (require 'flycheck)

    (setq doom-modeline-height 25
          doom-modeline-bar-width 0
          doom-modeline-icon (display-graphic-p)
          ;; lualine `path = 1' — one directory of context, not the whole path.
          doom-modeline-buffer-file-name-style 'relative-from-project
          doom-modeline-minor-modes nil
          doom-modeline-enable-word-count nil
          doom-modeline-buffer-encoding t
          doom-modeline-checker-simple-format nil
          doom-modeline-modal nil
          doom-modeline-percent-position '(-3 "%p")
          ;; trunc(str, 140, 45): the branch name gives up at 45 characters.
          doom-modeline-vcs-max-length 45)

    ;; The lualine theme sets only normal.c and inactive.c, both flat, both on
    ;; #1a1b26 — that exact value is hardcoded in the eviline colors table, so it is
    ;; used verbatim here rather than the storm background.
    (custom-set-faces
     `(mode-line          ((t (:background "#1a1b26" :foreground ,(my/tn 'fg)
                               :box nil :overline nil :underline nil))))
     `(mode-line-active   ((t (:background "#1a1b26" :foreground ,(my/tn 'fg)
                               :box nil :overline nil :underline nil))))
     `(mode-line-inactive ((t (:background "#1a1b26" :foreground ,(my/tn 'fg)
                               :box nil :overline nil :underline nil)))))

    ;; hide_in_width: eviline drops several segments below 80 columns.
    (defun my/wide-window-p ()
      "Non-nil when this window is wide enough for the optional segments."
      (> (window-width) 80))

    (doom-modeline-def-segment my/edge-bar
      (propertize "▊" 'face `(:foreground ,(my/tn 'blue))))

    ;; The mode indicator. eviline colours a glyph by evil state; in the nvim config
    ;; that glyph has been lost to an empty string, so the segment is currently
    ;; invisible there. A filled circle — eviline's own default — is used instead,
    ;; with the same state-to-colour table.
    (doom-modeline-def-segment my/mode-dot
      (let ((color (cond ((evil-insert-state-p)   (my/tn 'green))
                         ((evil-visual-state-p)   (my/tn 'blue))
                         ((evil-replace-state-p)  (my/tn 'violet))
                         ((evil-operator-state-p) (my/tn 'red))
                         ((evil-motion-state-p)   (my/tn 'blue))
                         ((evil-emacs-state-p)    (my/tn 'magenta))
                         (t                       (my/tn 'red)))))
        (propertize " ● " 'face `(:foreground ,color))))

    (doom-modeline-def-segment my/filesize
      (when (and (buffer-file-name) (my/wide-window-p))
        (propertize (concat " " (file-size-human-readable (buffer-size)) " ")
                    'face 'mode-line)))

    (doom-modeline-def-segment my/filename
      (propertize (concat " " (doom-modeline-buffer-file-name) " ")
                  'face `(:foreground ,(my/tn 'magenta) :weight bold)))

    (doom-modeline-def-segment my/progress
      (propertize (format-mode-line '("%p")) 'face `(:foreground ,(my/tn 'fg) :weight bold)))

    ;; The diagnostics segment, with the glyphs the lualine config uses.
    (doom-modeline-def-segment my/diagnostics
      (when (bound-and-true-p flycheck-mode)
        (let* ((counts (flycheck-count-errors flycheck-current-errors))
               (errors (or (alist-get 'error counts) 0))
               (warnings (or (alist-get 'warning counts) 0))
               (infos (or (alist-get 'info counts) 0)))
          (concat
           (when (> errors 0)
             (propertize (format " %d " errors)
                         'face `(:foreground ,(my/tn 'red))))
           (when (> warnings 0)
             (propertize (format " %d " warnings)
                         'face `(:foreground ,(my/tn 'yellow))))
           (when (> infos 0)
             (propertize (format " %d " infos)
                         'face `(:foreground ,(my/tn 'cyan))))))))

    (doom-modeline-def-segment my/encoding
      (when (and (my/wide-window-p) buffer-file-coding-system)
        (propertize (concat " " (upcase (symbol-name
                                        (coding-system-base buffer-file-coding-system))) " ")
                    'face `(:foreground ,(my/tn 'green) :weight bold))))

    (doom-modeline-def-segment my/fileformat
      (when (and (my/wide-window-p) buffer-file-coding-system)
        (propertize
         (format " %s "
                 (pcase (coding-system-eol-type buffer-file-coding-system)
                   (1 "DOS") (2 "MAC") (_ "UNIX")))
         'face `(:foreground ,(my/tn 'green) :weight bold))))

    ;; The branch name is read out of `vc-mode', which vc keeps up to date for free —
    ;; asking git per redisplay would be the expensive way to learn the same thing.
    (doom-modeline-def-segment my/branch
      (when (and (buffer-file-name) (stringp vc-mode))
          ;; substring-no-properties first. vc-mode is a PROPERTIZED string, and
          ;; string-trim / replace-regexp-in-string carry its property ranges onto
          ;; a shorter string -- so truncate-string-to-width was handed a string
          ;; whose properties ran past its end and raised "Args out of range" on
          ;; every redisplay of a buffer with a long branch name.
          (let ((branch (substring-no-properties
                         (string-trim
                          (replace-regexp-in-string "\\`[ ]*Git[:-]" "" vc-mode)))))
          (unless (string-empty-p branch)
            (propertize (concat "  "
                                (truncate-string-to-width
                                 branch doom-modeline-vcs-max-length nil nil "…")
                                " ")
                        'face `(:foreground ,(my/tn 'violet) :weight bold))))))

    ;; The diff counts gitsigns feeds lualine. diff-hl already knows them, but
    ;; asking it per redisplay would run git on every keystroke, so they are
    ;; recomputed only when diff-hl itself refreshes.
    (defvar-local my/diff-counts nil
      "Cached (added changed removed) line counts for this buffer.")

    ;; Counted from diff-hl's OVERLAYS, not from `diff-hl-changes'.
    ;;
    ;; diff-hl-changes returns an alist -- ((:working . CHANGES) (:reference
    ;; . CHANGES)) -- and this function used to iterate it as though it were the
    ;; change list itself, so `nth' was applied to the cons and every modified
    ;; file raised
    ;;
    ;;   (wrong-type-argument listp (:working . " *diff-hl* "))
    ;;
    ;; surfacing as "Error running timer 'diff-hl--update-buffer'". It fired on
    ;; every file with uncommitted changes -- which is every file being worked on.
    ;;
    ;; Reading the alist correctly would not be enough either: :working is a
    ;; BUFFER while the diff is still being resolved asynchronously, and the
    ;; entries are (line inserts deletes type), with type at index 3 rather than
    ;; the 2 assumed here. The overlays are the resolved answer and already carry
    ;; their type, so counting those is both correct and immune to the format.
    (defun my/diff-refresh-counts (&rest _)
      "Recompute `my/diff-counts' from diff-hl's overlays."
      (setq my/diff-counts
            (let ((added 0) (changed 0) (removed 0))
              (dolist (o (overlays-in (point-min) (point-max)))
                (when (overlay-get o 'diff-hl-hunk)
                  (let ((lines (max 1 (count-lines (overlay-start o) (overlay-end o)))))
                    (pcase (overlay-get o 'diff-hl-hunk-type)
                      ('insert (cl-incf added lines))
                      ('change (cl-incf changed lines))
                      ('delete (cl-incf removed 1))))))
              (list added changed removed))))

    (with-eval-after-load 'diff-hl
      ;; After the overlays are drawn, not after diff-hl-update: the update
      ;; schedules async work, so at that point there is nothing to count yet.
      (advice-add 'diff-hl--update-overlays :after #'my/diff-refresh-counts))

    (doom-modeline-def-segment my/diff
      (when (and my/diff-counts (my/wide-window-p))
        (cl-destructuring-bind (added changed removed) my/diff-counts
          (concat
           (when (> added 0)
             (propertize (format " %d " added)
                         'face `(:foreground ,(my/tn 'green))))
           (when (> changed 0)
             (propertize (format "󰝤 %d " changed)
                         'face `(:foreground ,(my/tn 'orange))))
           (when (> removed 0)
             (propertize (format " %d " removed)
                         'face `(:foreground ,(my/tn 'red))))))))

    (doom-modeline-def-modeline 'my/eviline
      '(my/edge-bar my/mode-dot my/filesize my/filename buffer-position
        my/progress my/diagnostics)
      '(my/encoding my/fileformat my/branch my/diff my/edge-bar))

    (defun my/set-eviline ()
      "Install the eviline layout as the default modeline."
      (doom-modeline-set-modeline 'my/eviline 'default))

    (add-hook 'doom-modeline-mode-hook #'my/set-eviline)
    (doom-modeline-mode 1)
    (my/set-eviline)

    ;; disabled_filetypes: help, the file tree and the terminal get no modeline at
    ;; all — which is also hide_inactive_statusline's spirit, less clutter.
    (require 'hide-mode-line)
    (dolist (hook '(treemacs-mode-hook
                    vterm-mode-hook
                    help-mode-hook
                    dashboard-mode-hook
                    lsp-treemacs-error-list-mode-hook))
      (add-hook hook #'hide-mode-line-mode))
  '';
}
