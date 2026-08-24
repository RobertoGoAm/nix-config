{
  ...
}:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      blamer
      browse-at-remote
      diff-hl
      forge
      git-link
      git-timemachine
      magit
    ];

  programs.emacs.extraConfig = ''
        ;;; Git — magit in place of fugitive, diff-hl in place of gitsigns, forge for
        ;;; GitHub and GitLab.
        ;;;
        ;;; This is the layer where Emacs is simply ahead: magit replaces fugitive, GV,
        ;;; merginal and git-messenger at once, with a real staging interface rather than
        ;;; a wrapper over the CLI. So the SPC g keys keep their nvim meanings and get
        ;;; better implementations underneath.

        ;; Not required at startup. magit-status and the rest are autoloaded, and
        ;; loading magit eagerly costs ~1.8s of every launch (magit-core, -diff,
        ;; -process, -transient, with-editor and git-commit all come with it) for
        ;; something not needed until you actually open a git buffer. The settings
        ;; below are plain setq of defcustoms, which do not pull it in.
        (setq magit-diff-refine-hunk 'all
              magit-save-repository-buffers 'dontask
              magit-display-buffer-function #'magit-display-buffer-fullframe-status-v1
              magit-bury-buffer-function #'magit-restore-window-configuration
              ;; The commit buffer gets the prose layout from ui/linenumbers.nix.
              magit-commit-show-diff t
              git-commit-summary-max-length 72)

        ;; forge covers both hosts the workflow uses. Both need a token in ~/.authinfo.gpg
        ;; before the first pull:
        ;;   machine api.github.com login <user>^forge password <token>
        ;;   machine gitlab.com/api/v4 login <user>^forge password <token>
        ;; Deliberately not automated — a PAT does not belong in a public repo, and the
        ;; gh and glab CLIs already hold their own credentials.
        ;; forge-add-default-bindings has to be nil *before* forge loads: evil-collection
        ;; has already rebuilt magit-dispatch, so forge's attempt to splice itself in
        ;; fails with "o not found". Its commands live on SPC g f instead.
        (setq forge-add-default-bindings nil)
        (with-eval-after-load 'magit
          (require 'forge))

        ;; gitsigns' gutter. diff-hl draws in the fringe by default, but margin mode takes
        ;; literal characters, which is how these end up being the exact glyphs the
        ;; gitsigns `signs' table specifies — and it works identically in the terminal,
        ;; where there is no fringe at all.
        ;; diff-hl splits its optional modes across separate files, and requiring the
        ;; parent does not pull them in — each of these is a `require', not a nicety.
        (require 'diff-hl)
        (require 'diff-hl-margin)
        (require 'diff-hl-flydiff)
        (require 'diff-hl-dired)
        (require 'diff-hl-show-hunk)
        (setq diff-hl-margin-symbols-alist
              '((insert  . "│")
                (change  . "│")
                (delete  . "_")
                (unknown . "┆")
                (ignored . "┆"))
              diff-hl-draw-borders nil)
        ;; Neither diff-hl nor blamer runs on a remote buffer.
        ;;
        ;; Both shell out to git per redisplay, which over tramp is a round trip
        ;; into the container for every refresh -- and both then break on the
        ;; result. diff-hl raised
        ;;   Error running timer 'diff-hl--update-buffer':
        ;;     (wrong-type-argument listp (:working . " *diff-hl* "))
        ;; on every save under /docker:, and blamer failed mid-format, leaving its
        ;; overlays behind so each redisplay stacked another copy of the blame
        ;; text along the line until it pushed the code off screen.
        ;;
        ;; The container is a mount of the host checkout, so the host buffer shows
        ;; the same git state anyway: nothing is lost by keeping these local.
        (defun my/vc-local-buffer-p ()
          "Non-nil when this buffer is a local file, not one over tramp."
          (and buffer-file-name (not (file-remote-p buffer-file-name))))

        (defun my/diff-hl-unless-remote ()
          (when (my/vc-local-buffer-p) (diff-hl-mode 1)))

        (define-globalized-minor-mode my/global-diff-hl-mode
          diff-hl-mode my/diff-hl-unless-remote)

        (my/global-diff-hl-mode 1)
        (diff-hl-margin-mode 1)
        ;; Live signs as you type -- gitsigns' default behaviour.
        ;;
        ;; This was switched off earlier on a misdiagnosis. The
        ;; (wrong-type-argument listp (:working . ...)) errors blamed on flydiff
        ;; came from my/diff-refresh-counts in ui/statusline.nix, which is advised
        ;; onto diff-hl's update and mis-read its return value; flydiff only made
        ;; it fire more often. With that fixed, live diffing works.
        (setq diff-hl-flydiff-delay 0.3)
        (diff-hl-flydiff-mode 1)
        ;; Keep the gutter honest after a magit stage or commit.
        (add-hook 'magit-pre-refresh-hook #'diff-hl-magit-pre-refresh)
        (add-hook 'magit-post-refresh-hook #'diff-hl-magit-post-refresh)
        (add-hook 'dired-mode-hook #'diff-hl-dired-mode)

        ;; current_line_blame, formatted exactly as the gitsigns formatter reads:
        ;; three spaces, author, relative time, a bullet, then the commit summary, at the
        ;; end of the line, after a 100ms delay.
        (require 'blamer)
        (setq blamer-idle-time 0.1
              blamer-min-offset 3
              blamer-type 'visual
              blamer-prettify-time-p t
              blamer-author-formatter "   %s, "
              blamer-datetime-formatter "%s • "
              blamer-commit-formatter "%s")
        (custom-set-faces
         `(blamer-face ((t (:foreground ,(my/tn 'comment) :slant italic :height 0.9)))))
        (defun my/blamer-unless-remote ()
          (when (my/vc-local-buffer-p) (blamer-mode 1)))

        (define-globalized-minor-mode my/global-blamer-mode
          blamer-mode my/blamer-unless-remote)

        (my/global-blamer-mode 1)

        ;; Clear blamer's overlays when a formatter rewrites the buffer.
        ;;
        ;; blamer tracks its overlays in one global list -- blamer--overlays is a
        ;; plain defvar, never buffer-local -- and blamer--try-render only clears
        ;; it when the line number, the line length or the window width has
        ;; changed. Format-on-save replaces the buffer's contents underneath it,
        ;; usually leaving point on the same line at the same length, so none of
        ;; those trigger: the previous overlay is orphaned rather than deleted and
        ;; a fresh one is drawn beside it. Do it a few times and the blame text
        ;; stacks along the line and pushes the code out of view.
        ;;
        ;; They are overlays, not buffer text, so nothing was ever written to the
        ;; file -- reopening the buffer already cleared them. This just stops them
        ;; accumulating in the first place.
        (with-eval-after-load 'apheleia
          (add-hook 'apheleia-post-format-hook #'blamer--clear-overlay))

        ;; Enforce "one blame at a time" rather than trusting blamer to do it.
        ;;
        ;; blamer-type is 'visual, so exactly one overlay should ever exist. In
        ;; practice they accumulate: traverse four lines, pause, and four blames
        ;; are on screen at once. blamer clears via blamer--overlays, a registry
        ;; it maintains itself, and anything that misses that list -- a render
        ;; from the idle timer while another buffer is current, a second timer
        ;; that outlived its cancel -- leaks an overlay nothing will ever delete.
        ;;
        ;; So sweep the buffer instead of reading the registry: before drawing,
        ;; delete every overlay whose displayed string carries blamer-face. That
        ;; is blamer's own face, set just below, so it identifies its overlays
        ;; without depending on bookkeeping that has already proven unreliable.
        (defun my/blamer-sweep (&rest _)
          "Delete every blamer overlay in this buffer."
          (dolist (o (overlays-in (point-min) (point-max)))
            (let ((str (or (overlay-get o 'after-string) (overlay-get o 'before-string))))
              (when (and (stringp str) (> (length str) 0))
                (let ((face (get-text-property 0 'face str)))
                  (when (or (eq face 'blamer-face)
                            (and (listp face) (memq 'blamer-face face)))
                    (delete-overlay o)))))))

        (with-eval-after-load 'blamer
          (advice-add 'blamer--render :before #'my/blamer-sweep))

        ;; blamer--overlays is deliberately NOT made buffer-local, though it
        ;; looks like it should be. blamer keeps blamer-idle-timer,
        ;; blamer--previous-line-number and the overlay list all global: the
        ;; design is one active blame at a time, process-wide. Making only the
        ;; list buffer-local breaks that pairing -- the render runs from an idle
        ;; timer, and any firing where a different buffer is current registers
        ;; the overlay in a list the real buffer's clear never reads, leaking one
        ;; per render. Traversing four lines then pausing left four blames on
        ;; screen at once.

        ;; GBrowse and GO: open the current line, or the repository, on the forge.
        (require 'browse-at-remote)
        (setq browse-at-remote-prefer-symbolic nil)

        (defun my/git-browse-repo ()
          "Open the repository's home page on its forge — the GO reflex.
    forge knows the remote's web URL directly; browse-at-remote is the fallback, though
    it opens the current file rather than the repository root."
          (interactive)
          (cond
           ((fboundp 'forge-browse-remote) (forge-browse-remote))
           ((fboundp 'browse-at-remote) (call-interactively #'browse-at-remote))
           (t (message "No forge remote to browse"))))

        (defun my/git-add-all ()
          "Stage every modified and untracked file — `Git add .'."
          (interactive)
          (magit-with-toplevel
            (magit-run-git "add" "--all" "."))
          (magit-refresh)
          (message "Staged everything"))

        (defun my/git-stage-hunk ()
          "Stage the hunk at point.
    diff-hl renamed this command between releases, so try the current name first and
    fall back to staging the file through magit."
          (interactive)
          (cond
           ((fboundp 'diff-hl-stage-dwim) (diff-hl-stage-dwim))
           ((fboundp 'diff-hl-stage-current-hunk) (diff-hl-stage-current-hunk))
           (t (magit-stage-buffer-file))))

        (defun my/git-toggle-signs ()
          "Toggle the git gutter."
          (interactive)
          (if diff-hl-mode (diff-hl-mode -1) (diff-hl-mode 1))
          (message "Git gutter %s" (if diff-hl-mode "on" "off")))

        (defun my/git-toggle-blame ()
          "Toggle the inline current-line blame."
          (interactive)
          (if (bound-and-true-p blamer-mode) (blamer-mode -1) (blamer-mode 1)))
  '';
}
