{ lib, ... }:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      org
      evil-org
    ];

  # Org is here for the agenda, not for notes. Notes stay in Obsidian markdown
  # (plugins/notes/obsidian.nix) -- that is where the vault, the templates and
  # the links already are, and moving them would buy nothing. What Obsidian has
  # no answer for is a timed agenda, which is what the calendar work needs to
  # land in, so org owns dates and tasks and nothing else.
  programs.emacs.extraConfig = lib.mkOrder 1450 ''
    ;;; Org -- agenda and capture only.

    ;; Neither is required at startup. org autoloads on .org files and on the
    ;; agenda/capture commands below, and evil-org costs ~1.9s to load -- by far
    ;; the most expensive require in this config -- for something no buffer needs
    ;; until an org buffer exists. Loading it from org-mode-hook moves that cost
    ;; to the first org file of the session and off every launch.
    (with-eval-after-load 'org
      (require 'evil-org)
      (add-hook 'org-mode-hook #'evil-org-mode))

    ;; Under Documents, not ~/org: the restic agent backs up Documents every 30
    ;; minutes (features/backup/restic) and nothing outside its path list, and on
    ;; macOS Documents is also what iCloud syncs. Agenda files are the one thing
    ;; here that is genuinely irreplaceable, so they live where both already look.
    ;; Plain setq, so none of this pulls org in early; org reads these when it loads.
    (setq org-directory (expand-file-name "~/Documents/org")
          ;; Every .org in ~/org, so a calendar sync can drop files in without a
          ;; config change. Missing directory is not an error: the agenda simply
          ;; has nothing in it until something writes there.
          org-agenda-files (list org-directory)
          org-default-notes-file (expand-file-name "inbox.org" org-directory)
          org-startup-indented t
          org-startup-folded 'content
          org-log-done 'time
          org-log-into-drawer t
          ;; The agenda is the thing being opened all day; give it the frame
          ;; rather than a split, and put it back on quit.
          org-agenda-window-setup 'current-window
          org-agenda-restore-windows-after-quit t
          org-agenda-span 'day
          org-agenda-start-on-weekday nil
          org-todo-keywords '((sequence "TODO(t)" "NEXT(n)" "WAIT(w@/!)"
                                        "|" "DONE(d!)" "CANCELLED(c@)")))

    (unless (file-directory-p org-directory)
      (make-directory org-directory t))

    (setq org-capture-templates
          '(("t" "Task" entry (file+headline org-default-notes-file "Tasks")
             "* TODO %?\n  %U\n  %a")
            ("n" "Note" entry (file+headline org-default-notes-file "Notes")
             "* %?\n  %U")
            ("m" "Meeting" entry (file+headline org-default-notes-file "Meetings")
             "* %? :meeting:\n  %^{When}T\n  %a")))

    ;;; Meet links out of the agenda. Calendar entries carry their join URL in the
    ;;; body or a LOCATION property, so "join my next call" is a scan of today's
    ;;; agenda rather than a trip to the browser to look it up.
    (defun my/agenda-next-meet-url ()
      "Return the first Google Meet URL in today's agenda entries, or nil."
      (let ((url nil))
        (dolist (file (org-agenda-files) url)
          (when (and (not url) (file-readable-p file))
            (with-temp-buffer
              (insert-file-contents file)
              (goto-char (point-min))
              (when (re-search-forward "https://meet\\.google\\.com/[a-z-]+" nil t)
                (setq url (match-string 0))))))))

    (defun my/org-agenda-today ()
      "Open the day view."
      (interactive)
      (org-agenda nil "a"))

    (defun my/org-inbox ()
      "Open the capture inbox."
      (interactive)
      (find-file org-default-notes-file))

    (defun my/org-todos ()
      "Open the global TODO list."
      (interactive)
      (org-todo-list))
  '';
}
