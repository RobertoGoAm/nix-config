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
        (require 'diff-hl-dired)
        (require 'diff-hl-show-hunk)
        (setq diff-hl-margin-symbols-alist
              '((insert  . "│")
                (change  . "│")
                (delete  . "_")
                (unknown . "┆")
                (ignored . "┆"))
              diff-hl-draw-borders nil)
        (global-diff-hl-mode 1)
        (diff-hl-margin-mode 1)
        ;; No diff-hl-flydiff. Live-signs-as-you-type is gitsigns' default and was
        ;; the intent here, but the flydiff path is broken against Emacs 30's vc
        ;; API: it hands `(:working . #<buffer *diff-hl-diff*>)' to something
        ;; expecting a list, so every update on a MODIFIED buffer raised
        ;;
        ;;   Error running timer 'diff-hl-flydiff-update':
        ;;     (wrong-type-argument listp (:working . #<buffer  *diff-hl-diff*>))
        ;;
        ;; and at a 0.1s delay that repeated the whole time you were typing --
        ;; filling *Messages*, and doing the diff work twice for nothing since the
        ;; signs never updated anyway. Reproduced and confirmed fixed by turning it
        ;; off: with flydiff disabled, diff-hl-update on a modified buffer returns
        ;; cleanly. Signs now refresh on save, which is what actually worked before.
        ;; Revisit if diff-hl gains Emacs 30 support upstream.
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
        (global-blamer-mode 1)

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
