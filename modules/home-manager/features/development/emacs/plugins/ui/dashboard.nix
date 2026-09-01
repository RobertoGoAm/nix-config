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
          dashboard-show-shortcuts t
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
      (dashboard-insert-heading "Backup:" "k")
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
      (dashboard-insert-heading "Unread mail:" "u")
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
      (dashboard-insert-heading "nix-config:" "g")
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

    ;; Each row carries its session id and directory as text properties, and a
    ;; keymap for RET and mouse-1. Properties rather than a closure per line:
    ;; this file is generated without a lexical-binding cookie, so a lambda
    ;; cannot capture the row it was made for -- every one would resume
    ;; whichever session happened to be last.
    (defvar my/dashboard-claude-map
      (let ((m (make-sparse-keymap)))
        (define-key m (kbd "RET") #'my/dashboard-claude-resume)
        (define-key m [mouse-1] #'my/dashboard-claude-resume)
        m)
      "Keymap active on a Claude session row in the dashboard.")

    (defun my/dashboard-claude-resume ()
      "Resume the Claude conversation on this line, in its own directory.

    Claude resolves a session against the project it belongs to, so this has
    to run there -- resuming from anywhere else simply does not find it."
      (interactive)
      (let ((sid (get-text-property (point) 'my/claude-sid))
            (cwd (get-text-property (point) 'my/claude-cwd)))
        (if (null sid)
            (message "No Claude session on this line")
          (my/claude-resume-session sid cwd))))

    (defun my/dashboard-claude (list-size)
      "Insert the most recent Claude conversations, newest first."
      (dashboard-insert-heading "Claude sessions:" "c")
      (insert "\n")
      (condition-case nil
          (let ((rows (seq-take (my/claude--sessions) (or list-size 5))))
            (if (null rows)
                (insert "    none recorded\n")
              (dolist (r rows)
                (let ((start (point)))
                  (insert (format "    %-16s %-22s %s\n"
                                  (nth 0 r)
                                  (truncate-string-to-width (nth 1 r) 22)
                                  (truncate-string-to-width (nth 3 r) 60)))
                  ;; Stop one character short of point so the trailing newline stays
                  ;; bare. A `mouse-face' covering the line break highlights past the
                  ;; end of the line and into the row below, which made every session
                  ;; light up together instead of just the one under the pointer.
                  (add-text-properties
                   start (1- (point))
                   (list 'my/claude-sid (nth 4 r)
                         'my/claude-cwd (nth 5 r)
                         'keymap my/dashboard-claude-map
                         'mouse-face 'highlight
                         'help-echo "RET or click: resume this conversation"))))))
        (error (insert "    index unavailable\n"))))

    ;; Jump to any single entry, not just to a section.
    ;;
    ;; The section shortcuts land you on a heading; from there it is n and p.
    ;; With seven sections and a screenful of rows that is a lot of pressing,
    ;; and there are far more entries than there are digits to number them
    ;; with. avy labels every visible entry with a one or two character hint
    ;; instead, so the number of rows stops mattering.
    ;;
    ;; The regex matches the four-space indent every generator here writes,
    ;; which keeps hints on the entries and off the headings and blank lines.
    (defun my/dashboard-jump-to-entry ()
      "Label every dashboard entry with an avy hint and jump to the one picked."
      (interactive)
      (require 'avy)
      (let ((avy-all-windows nil))
        (avy-jump "^ \\{2,\\}[^ \n]")))

    (defun my/dashboard-open-at-point ()
      "Act on the dashboard entry at point, whatever kind it is.

    Not `(key-binding (kbd \"RET\"))'. dashboard-mode-map binds RET to
    `dashboard-return', but evil's normal state sits above the major mode map
    and answers with `evil-ret', which only moves down a line -- so asking
    what RET does gets the wrong answer here, and plain RET on an entry has
    never opened anything either.

    The row's own keymap comes first, because the Claude rows carry one as a
    text property to resume a session in its project directory; then
    dashboard's own command; then the plain widget."
      (interactive)
      (let* ((km (get-char-property (point) 'keymap))
             (own (and (keymapp km) (lookup-key km (kbd "RET"))))
             (cmd (cond ((commandp own) own)
                        ((fboundp 'dashboard-return) #'dashboard-return)
                        (t #'widget-button-press))))
        (call-interactively cmd)))

    (defun my/dashboard-jump-and-open ()
      "Pick a dashboard entry by hint and act on it."
      (interactive)
      (when (my/dashboard-jump-to-entry)
        (my/dashboard-open-at-point)))

    ;; Bound through evil, not `define-key'. A plain mode-map binding loses to
    ;; evil's normal state -- f there is `evil-find-char', which is worth far
    ;; more than a dashboard shortcut. o and O are the pair chosen instead:
    ;; both open a line in normal state, which is meaningless in a read-only
    ;; buffer, and "open" is what this does anyway.
    (with-eval-after-load 'dashboard
      (require 'evil nil t)
      (if (fboundp 'evil-define-key*)
          (evil-define-key* 'normal dashboard-mode-map
            (kbd "o") #'my/dashboard-jump-and-open
            (kbd "O") #'my/dashboard-jump-to-entry
            ;; RET too, for the same reason: evil-ret would otherwise swallow
            ;; it and the entry under point would never open.
            (kbd "RET") #'my/dashboard-open-at-point)
        (define-key dashboard-mode-map (kbd "o") #'my/dashboard-jump-and-open)
        (define-key dashboard-mode-map (kbd "O") #'my/dashboard-jump-to-entry)))

    (add-to-list (quote dashboard-item-generators) (quote (backup . my/dashboard-backup)))
    (add-to-list (quote dashboard-item-generators) (quote (unread . my/dashboard-unread)))
    (add-to-list (quote dashboard-item-generators) (quote (config . my/dashboard-config)))
    (add-to-list (quote dashboard-item-generators) (quote (claude . my/dashboard-claude)))

    ;; The key each heading advertises is the SECOND argument to
    ;; dashboard-insert-heading. Passing nil there -- as these did at first --
    ;; registers the shortcut but prints no hint, so the keys worked and were
    ;; invisible.
    ;;
    ;; Section shortcuts. dashboard drives these through a
    ;; dashboard-jump-to-<section> function, which it only defines for its own
    ;; built-in sections -- a custom generator gets a shortcut that silently
    ;; does nothing unless the function exists, so define one per section.
    (defun my/dashboard--jump-to (heading)
      "Move point to the first line under HEADING."
      (goto-char (point-min))
      (when (search-forward heading nil t)
        (beginning-of-line)
        (forward-line 1)))

    (defun dashboard-jump-to-backup () (interactive) (my/dashboard--jump-to "Backup:"))
    (defun dashboard-jump-to-unread () (interactive) (my/dashboard--jump-to "Unread mail:"))
    (defun dashboard-jump-to-config () (interactive) (my/dashboard--jump-to "nix-config:"))
    (defun dashboard-jump-to-claude () (interactive) (my/dashboard--jump-to "Claude sessions:"))

    ;; c for Claude, k for backup (b is taken by bookmarks), u for unread,
    ;; g for the config since n is nothing here and c is spoken for.
    (setq dashboard-item-shortcuts
          '((backup    . "k")
            (unread    . "u")
            (config    . "g")
            (claude    . "c")
            (recents   . "r")
            (projects  . "p")
            (bookmarks . "m")))

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
