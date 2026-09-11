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
          ;; No backup age and no unread count: neither is something you act
          ;; on from a home screen. The backup either ran or the health line in
          ;; the menu bar says it did not, and unread mail is a number that
          ;; changes nothing about what to open next.
          dashboard-items '((config   . 1)
                            (todo     . 8)
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

    ;; Heading icons, which the package works out at load and this config asks
    ;; for afterwards.
    ;;
    ;; `dashboard-heading-icons' is a defcustom whose default is derived from
    ;; `dashboard-icon-type', which itself defaults to nil unless
    ;; `dashboard-set-heading-icons' was already non-nil when dashboard was
    ;; loaded. It was not: both are turned on in the setq above, which runs
    ;; after the require. So the alist was empty, `dashboard-heading-icon'
    ;; returned its two-space fallback for every section, and no heading had
    ;; an icon at all -- while the ROWS did, because `dashboard-set-file-icons'
    ;; is read per row at draw time rather than once at load.
    ;;
    ;; Setting it here gives every heading an icon, and gives the two custom
    ;; sections theirs from the same table as the built-in ones -- which is
    ;; what makes them indent identically, since the icon is the indent.
    (setq dashboard-heading-icons
          '((todo      . "nf-oct-checklist")
            (config    . "nf-oct-gear")
            (recents   . "nf-oct-history")
            (projects  . "nf-oct-rocket")
            (bookmarks . "nf-oct-bookmark")
            (agenda    . "nf-oct-calendar")
            (registers . "nf-oct-database")))

    ;; The indent dashboard's own rows use, so the custom sections line up
    ;; with them.
    ;;
    ;; A generated section inserts whatever it likes, and these two inserted
    ;; four spaces and the text. `dashboard-insert-section-list' -- what the
    ;; built-in sections go through -- inserts four spaces, a file icon and a
    ;; space, so every Todo and nix-config row started two columns to the left
    ;; of every row above and below it.
    (defun my/dashboard--row-icon (name)
      "Row icon NAME plus its trailing space, or the blank of the same width.
    Two columns either way. A row with no icon still has to occupy the width
    of one, or the text in this section hangs left of the text in the next."
      (let ((icon (and name
                       (dashboard-display-icons-p)
                       (ignore-errors
                         (dashboard-octicon name :height 1.0 :v-adjust 0.0)))))
        (if (and (stringp icon) (not (string-empty-p icon)))
            (concat icon " ")
          "  ")))

    (defun my/dashboard--row (icon text)
      "TEXT as a section row: dashboard's indent, then ICON, then TEXT."
      (concat (make-string (or standard-indent tab-width 4) ?\s)
              (my/dashboard--row-icon icon)
              text))

    ;; This also points `initial-buffer-choice' at the dashboard, which is what makes
    ;; it appear in frames the daemon creates later rather than only the first one.
    ;; Setting that variable by hand as well is what makes `emacsclient file' open the
    ;; dashboard instead of the file, so it is deliberately left to dashboard.el.
    ;; Two custom sections, each answering a question the editor is otherwise
    ;; silent about: what state the config is in, and what is on the list.
    ;;
    ;; Both bodies are wrapped in condition-case: a generator that signals
    ;; takes the whole dashboard with it, and this is the first buffer of
    ;; every session.
    (defun my/dashboard-config (_list-size)
      "Insert the state of the nix config: uncommitted, unpushed, drifted."
      (dashboard-insert-heading "nix-config:" (dashboard-get-shortcut 'config)
                                (dashboard-heading-icon 'config))
      (insert "\n")
      (insert
       (my/dashboard--row
        "nf-oct-git_branch"
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
          (error "unavailable"))))
      (insert "\n"))

    ;; The list, read from the file the phone edits too.
    ;;
    ;; One file rather than the whole vault. A vault is full of "- [ ]" lines
    ;; that are template scaffolding rather than work -- a single daily note
    ;; carries a dozen empty ones -- so scanning it would fill the home screen
    ;; with blanks. TaskForge.md is the file TaskForge syncs, which makes it
    ;; exactly the list that also exists on the phone: added here, it is on the
    ;; phone; ticked there, it is gone from here.
    ;;
    ;; Obsidian Tasks keeps its metadata in emoji -- created, start, scheduled,
    ;; due, done, cancelled, recurrence, priority -- all of it after the
    ;; description. So the description is everything before the first of them,
    ;; and the only piece worth showing next to it is the due date.
    (defvar my/dashboard-todo-file "TaskForge.md"
      "File, relative to the Obsidian vault, that the Todo section reads.")

    (defconst my/dashboard--task-meta-rx
      "[📅⏳🛫➕✅❌🔁⏫🔼🔽🔺]"
      "Where the Obsidian Tasks metadata starts on a task line.")

    (defun my/dashboard--todo-path ()
      "Absolute path of the todo file, or nil when there is no vault."
      (let ((vault (bound-and-true-p obsidian-directory)))
        (when vault (expand-file-name my/dashboard-todo-file vault))))

    (defun my/dashboard--tasks ()
      "Open tasks in the todo file as (DUE TEXT LINE), soonest first.
    DUE is nil for a task with no date, and those sort last -- a list with no
    deadline on it is not more urgent than one with a deadline next week."
      (let ((path (my/dashboard--todo-path))
            (rows nil))
        (when (and path (file-readable-p path))
          (with-temp-buffer
            (insert-file-contents path)
            (goto-char (point-min))
            (let ((n 0))
              (while (not (eobp))
                (setq n (1+ n))
                (let ((line (buffer-substring-no-properties
                             (line-beginning-position) (line-end-position))))
                  (when (string-match "\\`[ \t]*[-*+] \\[ \\] +\\(.*\\)\\'" line)
                    (let* ((body (match-string 1 line))
                           (due (when (string-match
                                       "📅 *\\([0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\)"
                                       body)
                                  (match-string 1 body)))
                           (text (string-trim
                                  (car (split-string body my/dashboard--task-meta-rx)))))
                      (unless (string-empty-p text)
                        (push (list due text n) rows)))))
                (forward-line 1)))))
        (sort (nreverse rows)
              (lambda (a b)
                (let ((da (car a)) (db (car b)))
                  (cond ((and da db) (string< da db))
                        (da t)
                        (t nil)))))))

    (defvar my/dashboard-todo-map
      (let ((m (make-sparse-keymap)))
        (define-key m (kbd "RET") #'my/dashboard-todo-open)
        (define-key m [mouse-1] #'my/dashboard-todo-open)
        m)
      "Keymap active on a task row in the dashboard.")

    (defun my/dashboard-todo-open ()
      "Open the todo file at the task on this line."
      (interactive)
      (let ((line (get-text-property (point) 'my/todo-line))
            (path (my/dashboard--todo-path)))
        (if (not (and line path))
            (message "No task on this line")
          (find-file path)
          (goto-char (point-min))
          (forward-line (1- line)))))

    (defun my/dashboard-todo (list-size)
      "Insert the open tasks from the vault, soonest first."
      (dashboard-insert-heading "Todo:" (dashboard-get-shortcut 'todo)
                                (dashboard-heading-icon 'todo))
      (insert "\n")
      (condition-case nil
          (let ((path (my/dashboard--todo-path)))
            (cond
             ((null path) (insert (my/dashboard--row nil "no vault") "\n"))
             ((not (file-readable-p path))
              (insert (my/dashboard--row
                       nil (format "no %s in the vault" my/dashboard-todo-file))
                      "\n"))
             (t
              (let* ((rows (seq-take (my/dashboard--tasks) (or list-size 8)))
                     (today (format-time-string "%Y-%m-%d"))
                     ;; The due dates stay in a column, and the column is as
                     ;; wide as the titles actually are.
                     ;;
                     ;; It was a constant 58, which made every row of this
                     ;; section the widest line on the page -- and
                     ;; `dashboard-center-text' takes ONE maximum width across
                     ;; every section and gives them all the same `line-prefix'
                     ;; from it. So the padding of a todo decided the left edge
                     ;; of the recent files and the projects too, and editing a
                     ;; task title shifted the whole dashboard sideways.
                     (width (min 58 (apply #'max 0 (mapcar (lambda (r)
                                                             (string-width (nth 1 r)))
                                                           rows)))))
                (if (null rows)
                    (insert (my/dashboard--row nil "nothing open") "\n")
                  (dolist (r rows)
                    (let* ((due (nth 0 r))
                           (start (point))
                           ;; Late is an error, today is a warning, and a date
                           ;; further out is dimmed -- it is on the list, but it
                           ;; is not what today is for.
                           (face (cond ((null due) 'shadow)
                                       ((string< due today) 'error)
                                       ((string= due today) 'warning)
                                       (t 'shadow))))
                      (insert (string-trim-right
                               (my/dashboard--row
                                "nf-oct-dot_fill"
                                (format "%s  %s"
                                        (string-pad
                                         (truncate-string-to-width (nth 1 r) width)
                                         width)
                                        (propertize (or due "") (quote face) face))))
                              "\n")
                      ;; Stop one character short of point, so the trailing
                      ;; newline stays bare: a `mouse-face' covering the line
                      ;; break highlights into the row below.
                      (add-text-properties
                       start (1- (point))
                       (list 'my/todo-line (nth 2 r)
                             'keymap my/dashboard-todo-map
                             'mouse-face 'highlight
                             'help-echo "RET or click: open this task in the vault")))))))))
        (error (insert (my/dashboard--row nil "unavailable") "\n"))))

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
    ;; Declared because the `let' below binds it and avy is not loaded when this
    ;; file is compiled: an unbound-at-compile-time symbol binds lexically, and
    ;; the hints would go on every window after all.
    (defvar avy-all-windows)

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

    The row's own keymap comes first, for a row that carries one as a text
    property; then dashboard's own command; then the plain widget."
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

    (add-to-list (quote dashboard-item-generators) (quote (config . my/dashboard-config)))
    (add-to-list (quote dashboard-item-generators) (quote (todo . my/dashboard-todo)))

    ;; The letters in brackets, made true.
    ;;
    ;; Every one of them did nothing. Three things were in the way, and each
    ;; would have been enough on its own:
    ;;
    ;;   - The hint next to a heading comes from `dashboard-item-shortcuts',
    ;;     but the KEY is bound by `dashboard-insert-shortcut', which only runs
    ;;     inside dashboard's own `dashboard-insert-section' macro. A custom
    ;;     generator -- nix-config, and now Todo -- calls
    ;;     `dashboard-insert-heading' directly, so it advertised a key that was
    ;;     never bound to anything at all.
    ;;
    ;;   - What dashboard does bind, for its own sections, is not a jump: it is
    ;;     `dashboard-cycle-section-forward', which steps one WIDGET and only
    ;;     moves to the section when it notices it has left it. The custom
    ;;     sections here are plain text with no widgets in them.
    ;;
    ;;   - And evil normal state sits above the major mode map, so any binding
    ;;     dashboard did make lost to `evil-set-marker' and friends anyway. The
    ;;     live buffer showed m as evil-set-marker and g as the g prefix.
    ;;
    ;; So the sections are declared once, here, and everything else is derived
    ;; from that: the hints, the bindings in the mode map, and the bindings in
    ;; evil's normal state. c rather than g for the config, because g is a
    ;; prefix worth more than a section jump -- and c is free now that the
    ;; Claude section is gone.
    (defvar my/dashboard-sections
      '((todo      "t" "Todo:")
        (config    "c" "nix-config:")
        (recents   "r" "Recent Files:")
        (projects  "p" "Projects:")
        (bookmarks "m" "Bookmarks:"))
      "Each section: its symbol, the key that jumps to it, and its heading.")

    (defun my/dashboard--jump-to (heading)
      "Move point to the first line under HEADING."
      (goto-char (point-min))
      (when (search-forward heading nil t)
        (beginning-of-line)
        (forward-line 1)))

    (defun dashboard-jump-to-config () (interactive) (my/dashboard--jump-to "nix-config:"))

    (setq dashboard-item-shortcuts
          (mapcar (lambda (s) (cons (nth 0 s) (nth 1 s))) my/dashboard-sections))

    ;; After every render, and in both maps.
    ;;
    ;; Rendering re-binds the section keys in `dashboard-mode-map' -- the
    ;; shortcut macro runs again for each section it inserts -- and
    ;; evil-collection then copies r, m and p out of that map into evil's
    ;; normal state. Both of those happen after init, so binding these once at
    ;; startup would simply be overwritten. Hanging it off the same function
    ;; evil-collection advises, added later, puts it last in the queue.
    (defun my/dashboard-bind-sections (&rest _)
      "Bind each section key to a jump to that section's heading."
      (dolist (section my/dashboard-sections)
        (let* ((key (kbd (nth 1 section)))
               (heading (nth 2 section))
               (command (lambda ()
                          (interactive)
                          (my/dashboard--jump-to heading))))
          (define-key dashboard-mode-map key command)
          (when (fboundp 'evil-define-key*)
            (evil-define-key* 'normal dashboard-mode-map key command)))))

    (with-eval-after-load 'dashboard
      (require 'evil nil t)
      (my/dashboard-bind-sections)
      (advice-add 'dashboard-insert-startupify-lists
                  :after #'my/dashboard-bind-sections))

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

    (defun my/dashboard--ordinary-windows (frame)
      "FRAME's windows that are not side windows."
      (seq-remove (lambda (w) (window-parameter w 'window-side))
                  (window-list frame)))

    (defun my/dashboard--flatten (frame window)
      "Leave FRAME showing one ordinary window, WINDOW for preference.

    Ordinary windows only. This used to lift `ignore-window-parameters' and
    call `delete-other-windows', which takes the side windows with it -- and
    now that the Claude sidebar is opened on every frame, that meant opening a
    frame, drawing the sidebar and deleting it again. The duplicate this exists
    to collapse is a second ordinary pane, so a side window is not its
    business.

    `delete-window' per window rather than `delete-other-windows' on the one to
    keep, for the same reason: there is no way to tell the latter to spare
    them. Failures are swallowed one at a time -- a signal here abandons the
    rest of the frame hook, and a pane that will not go is worth less than the
    hooks behind this one.

    The window that stays is an ordinary one wherever the frame has one, and
    is stripped of its side parameters where it does not: a survivor keeps
    them, and a frame rooted on a dedicated slot leaves which-key nowhere to
    put its panel."
      (let ((keep (or (seq-find (lambda (w) (not (window-parameter w 'window-side)))
                                (cons window (window-list frame)))
                      window)))
        (when (window-parameter keep 'window-side)
          (set-window-parameter keep 'window-side nil)
          (set-window-parameter keep 'slot nil)
          (set-window-dedicated-p keep nil))
        (dolist (w (my/dashboard--ordinary-windows frame))
          (unless (eq w keep)
            (ignore-errors (delete-window w))))))

    (defun my/dashboard-on-client-frame ()
      "Show the dashboard alone in a client frame that has nothing else to show.

    Two things had to be handled. The frame can arrive already displaying the
    dashboard -- `dashboard-setup-startup-hook' points `initial-buffer-choice'
    at it, and server.el honours that -- so matching only *scratch* missed
    those and matching both is what makes this idempotent.

    And the frame can arrive split, which is what produced two windows each
    showing the dashboard with its own modeline. `delete-other-windows' leaves
    the one window a home screen should be. A frame opened on a file is
    untouched: its buffer is neither of these.

    What the frame is showing, not `current-buffer'. Inside
    `server-after-make-frame-hook' the current buffer is \" *server*\" --
    server.el's own -- so the guard below never matched and the flattening
    never ran, which is how the split dashboard came back.

    And what its ORDINARY windows are showing, not its selected one. The
    Claude sidebar is opened on this same hook, ahead of this function; it is
    a side window, and while it was also left selected the question \"what is
    this frame showing\" was answered with the sidebar. That is neither
    *scratch* nor the dashboard, so this declined, and the frame opened on an
    empty strip with *scratch* behind it."
      (let* ((frame (selected-frame))
             (ordinary (my/dashboard--ordinary-windows frame))
             (window (or (car (memq (frame-selected-window frame) ordinary))
                         (car ordinary)
                         (frame-selected-window frame)))
             (shown (buffer-name (window-buffer window))))
        (cond
         ;; A frame showing nothing but the dashboard is a home screen that got
         ;; split, whatever split it: one window is the whole of what it has to
         ;; say. Anything that pops a window here -- `display-warning' is the
         ;; usual one -- leaves the pane behind when it is dismissed, still
         ;; showing what was under it, and two panes of dashboard is what "the
         ;; dashboard opened twice" looks like.
         ((and (cdr ordinary)
               (seq-every-p (lambda (w)
                              (equal (buffer-name (window-buffer w)) "*dashboard*"))
                            ordinary))
          (my/dashboard--flatten frame window))
         ;; Not into a frame a saved layout has just been replayed into: that
         ;; layout can have the dashboard in its selected window, and
         ;; flattening would throw away the panes restored beside it.
         ;;
         ;; A frame parameter, not the daemon-wide `my/window-state-restored'
         ;; flag that used to be read here. That flag is set for the life of
         ;; the daemon by the one replay it allows, so every frame after the
         ;; first stood down as well -- and those frames have no restored
         ;; layout to protect, only *scratch*.
         ((frame-parameter frame 'my/window-state-replayed) nil)
         ((member shown '("*scratch*" "*dashboard*"))
          ;; In that window: `my/dashboard-home' switches the selected one,
          ;; and the selected one is not necessarily the window just judged.
          (with-selected-window window (my/dashboard-home))
          (my/dashboard--flatten frame window)
          ;; And then the point goes there, said rather than assumed.
          ;;
          ;; It has been landing on the dashboard only because everything that
          ;; opens a pane on this hook puts the selection back afterwards. That
          ;; is a property of the other hooks, not of this one, and the frame
          ;; that opened with the point in a side strip is what it costs when
          ;; one of them stops holding.
          (when (window-live-p window)
            (select-window window))))))

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
