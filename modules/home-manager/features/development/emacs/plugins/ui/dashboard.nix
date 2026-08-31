# development emacs plugins ui dashboard

{
  ...
}:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      dashboard
    ];

  # The nvim dashboard spells NIXVIM in ANSI Shadow block letters; this...

  # The nvim dashboard spells NIXVIM in ANSI Shadow block letters; this is the same
  # font saying EMACS. dashboard.el reads its banner from a file rather than a list
  # of strings, so it lands next to the rest of the generated config.

  home.file.".config/emacs/banner.txt".text = ''
    ███████╗███╗   ███╗ █████╗  ██████╗███████╗
    ██╔════╝████╗ ████║██╔══██╗██╔════╝██╔════╝
    █████╗  ██╔████╔██║███████║██║     ███████╗
    ██╔══╝  ██║╚██╔╝██║██╔══██║██║     ╚════██║
    ███████╗██║ ╚═╝ ██║██║  ██║╚██████╗███████║
    ╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝╚══════╝
  '';

  programs.emacs.extraConfig = ''
    ;;; Dashboard — dashboard.el in place of dashboard.nvim's "hyper" theme.

    (require 'dashboard)

    (setq dashboard-startup-banner (expand-file-name "banner.txt" user-emacs-directory)
          dashboard-banner-logo-title "Made with ❤️"
          dashboard-center-content t
          dashboard-vertically-center-content t
          dashboard-show-shortcuts nil
          dashboard-set-heading-icons t
          dashboard-set-file-icons t
          dashboard-icon-type 'nerd-icons
          ;; mru.limit = 20, and project.enable = true.
          ;; bookmarks is gone: it has never had an entry, so it only ever
          ;; rendered "--- No items ---". backup and unread are custom
          ;; generators defined below.
          dashboard-items '((backup   . 1)
                            (unread   . 1)
                            (config   . 1)
                            (claude   . 5)
                            (recents  . 12)
                            (projects . 8)
                            (bookmarks . 5))
          ;; change_to_vcs_root = true
          dashboard-projects-switch-function #'projectile-persp-switch-project
          dashboard-projects-backend 'projectile)

    ;; projectile-persp-switch-project only exists with persp-mode; fall back to the
    ;; plain switch so the dashboard never errors on a project entry.
    (unless (fboundp 'projectile-persp-switch-project)
      (setq dashboard-projects-switch-function #'projectile-switch-project-by-name))

    ;; This also points `initial-buffer-choice' at the dashboard, which is what makes
    ;; it appear in frames the daemon creates later rather than only the first one.
    ;; Setting that variable by hand as well is what makes `emacsclient file' open the
    ;; dashboard instead of the file, so it is deliberately left to dashboard.el.
    ;; Two custom sections, each answering a question the editor is otherwise
    ;; silent about.
    ;;
    ;; Backup age, because restic has twice stopped for days unnoticed -- once
    ;; while still pinging its dead-man switch. The SwiftBar collector already
    ;; caches the last snapshot time, so this reads that file rather than
    ;; talking to the repository again.
    ;;
    ;; Unread mail, because mu4e only reports it while running, and a home
    ;; screen is exactly where you want what arrived while you were not
    ;; looking. Shelling out to mu keeps it independent of mu4e being loaded.
    ;;
    ;; Both bodies are wrapped in condition-case: a generator that signals
    ;; takes the whole dashboard with it, and this is the first buffer of
    ;; every session.
    (defun my/dashboard-backup (_list-size)
      "Insert how long ago restic last completed."
      (dashboard-insert-heading "Backup:" nil)
      (insert "\n    ")
      (insert
       (condition-case nil
           (let* ((f (expand-file-name "swiftbar-status/backup"
                                       (or (getenv "TMPDIR") "/tmp")))
                  (ts (and (file-readable-p f)
                           (string-trim (with-temp-buffer
                                          (insert-file-contents f)
                                          (buffer-string))))))
             (if (or (null ts) (string-empty-p ts))
                 "no snapshot recorded"
               (let* ((age (float-time (time-subtract (current-time)
                                                      (encode-time (iso8601-parse ts)))))
                      (h (/ age 3600)))
                 (cond ((< h 1) (format "%.0f minutes ago" (/ age 60)))
                       ((< h 24) (format "%.0f hours ago" h))
                       (t (propertize (format "%.0f DAYS ago" (/ h 24))
                                      (quote face) (quote error)))))))
         (error "unreadable")))
      (insert "\n"))

    (defun my/dashboard-unread (_list-size)
      "Insert the number of unread messages mu knows about."
      (dashboard-insert-heading "Unread mail:" nil)
      (insert "\n    ")
      (insert
       (condition-case nil
           (let ((n (string-to-number
                     (shell-command-to-string
                      "mu find --fields m flag:unread 2>/dev/null | wc -l"))))
             (if (> n 0) (format "%d unread" n) "nothing unread"))
         (error "mu index unavailable")))
      (insert "\n"))

    (defun my/dashboard-config (_list-size)
      "Insert the state of the nix config: uncommitted, unpushed, drifted."
      (dashboard-insert-heading "nix-config:" nil)
      (insert "\n    ")
      (insert
       (condition-case nil
           (let* ((default-directory (expand-file-name "~/nix-config"))
                  (dirty (string-to-number
                          (shell-command-to-string "git status --porcelain 2>/dev/null | wc -l")))
                  (ahead (string-to-number
                          (shell-command-to-string
                           "git rev-list --count @{u}..HEAD 2>/dev/null || echo 0")))
                  (parts (delq nil
                               (list (when (> dirty 0) (format "%d uncommitted" dirty))
                                     (when (> ahead 0) (format "%d unpushed" ahead))))))
             (if parts (propertize (string-join parts ", ") (quote face) (quote warning))
               "clean"))
         (error "unavailable")))
      (insert "\n"))

    (defun my/dashboard-claude (list-size)
      "Insert the most recent Claude conversations, newest first."
      (dashboard-insert-heading "Claude sessions:" nil)
      (insert "\n")
      (condition-case nil
          (let ((rows (seq-take (my/claude--sessions) (or list-size 5))))
            (if (null rows)
                (insert "    none recorded\n")
              (dolist (r rows)
                (insert (format "    %-16s %-22s %s\n"
                                (nth 0 r)
                                (truncate-string-to-width (nth 1 r) 22)
                                (truncate-string-to-width (nth 3 r) 60))))))
        (error (insert "    index unavailable\n"))))

    (add-to-list (quote dashboard-item-generators) (quote (backup . my/dashboard-backup)))
    (add-to-list (quote dashboard-item-generators) (quote (unread . my/dashboard-unread)))
    (add-to-list (quote dashboard-item-generators) (quote (config . my/dashboard-config)))
    (add-to-list (quote dashboard-item-generators) (quote (claude . my/dashboard-claude)))

    (dashboard-setup-startup-hook)

    ;; And again for every client frame.
    ;;
    ;; `dashboard-setup-startup-hook' points `initial-buffer-choice' at the
    ;; dashboard, which is the whole mechanism -- but a daemon consumes that
    ;; once, at its own startup, long before any frame exists. Every later
    ;; `emacsclient -c' frame therefore opens on *scratch*, which is what a GUI
    ;; frame against the daemon has been showing instead of the banner.
    ;;
    ;; Only when the frame would otherwise show *scratch*: opening a file with
    ;; `emacsclient -c somefile' must land on the file, not on the dashboard.
    (defun my/dashboard-home ()
      "Switch to the dashboard, building it only if it is not there.

    `dashboard-open' regenerates the buffer -- re-reading the recent-file and
    project lists and redrawing the banner. Reusing an existing one instead
    means returning here is instant and the contents stay put while you work,
    rather than reshuffling under you every time."
      (interactive)
      (if (get-buffer "*dashboard*")
          (switch-to-buffer "*dashboard*")
        (dashboard-open)))

    (defun my/dashboard-on-client-frame ()
      "Show the dashboard alone in a client frame that has nothing else to show.

    Two things had to be handled. The frame can arrive already displaying the
    dashboard -- `dashboard-setup-startup-hook' points `initial-buffer-choice'
    at it, and server.el honours that -- so matching only *scratch* missed
    those and matching both is what makes this idempotent.

    And the frame can arrive split, which is what produced two windows each
    showing the dashboard with its own modeline. `delete-other-windows' leaves
    the one window a home screen should be. A frame opened on a file is
    untouched: its buffer is neither of these."
      (when (member (buffer-name) '("*scratch*" "*dashboard*"))
        (my/dashboard-home)
        (delete-other-windows)))

    (add-hook 'server-after-make-frame-hook #'my/dashboard-on-client-frame)

    (defun my/dashboard ()
      "Show the dashboard."
      (interactive)
      (cond
       ((fboundp 'dashboard-open) (dashboard-open))
       ((fboundp 'dashboard-refresh-buffer) (dashboard-refresh-buffer))
       (t (switch-to-buffer (get-buffer-create dashboard-buffer-name)))))
  '';
}
