# development emacs plugins ai sessions

{ lib, pkgs, ... }:
let

  # Claude Code keeps every conversation as JSONL under...

  # Claude Code keeps every conversation as JSONL under ~/.claude/projects, one
  # directory per working directory. `claude --resume` can reopen them, but its
  # picker only lists the current project's -- so a conversation from another
  # repo is unreachable even though the transcript is right there on disk.

  # This indexes all of them. Reading the first 40 records of each file is enough
  # for the metadata and the opening prompt, which keeps a ~1000-session sweep
  # well under a second rather than parsing 700MB.

  index = pkgs.writers.writePython3Bin "claude-session-index" { flakeIgnore = [ "E501" ]; } ''
    import glob
    import json
    import os
    import sys
    import time

    root = os.path.expanduser("~/.claude/projects")

    # The desktop app keeps its own metadata beside the CLI transcripts, under
    # Application Support/Claude/claude-code-sessions/<account>/<workspace>/.
    # It carries a human title ("Nix flake inputs update") where the CLI store
    # has only the opening prompt, and links to the transcript by cliSessionId.
    # Same conversations, better labels -- so titles are borrowed where they
    # exist and the prompt is the fallback.
    titles = {}
    desktop = os.path.expanduser(
        "~/Library/Application Support/Claude/claude-code-sessions"
    )
    for meta_path in glob.glob(os.path.join(desktop, "**", "local_*.json"), recursive=True):
        try:
            with open(meta_path, errors="replace") as fh:
                meta = json.load(fh)
        except (ValueError, OSError):
            continue
        cli_id = meta.get("cliSessionId")
        title = meta.get("title")
        if cli_id and title:
            titles[cli_id] = title

    rows = []
    for path in glob.glob(os.path.join(root, "**", "*.jsonl"), recursive=True):
        cwd = branch = prompt = None
        sidechain = False
        sid = os.path.basename(path)[:-6]
        try:
            with open(path, errors="replace") as fh:
                for i, line in enumerate(fh):
                    if i > 40:
                        break
                    try:
                        d = json.loads(line)
                    except ValueError:
                        continue
                    cwd = cwd or d.get("cwd")
                    branch = branch or d.get("gitBranch")
                    sid = d.get("sessionId") or sid
                    # Sidechains are subagent transcripts. `claude --resume' cannot
                    # open one, so a row for it is an entry that only ever fails.
                    # Labelling it "[subagent]" and listing it anyway -- which is
                    # what this did -- is how a fifth of the picker became unusable.
                    if d.get("isSidechain"):
                        sidechain = True
                        break
                    if prompt is None and d.get("type") == "user":
                        msg = d.get("message") or {}
                        content = msg.get("content")
                        if isinstance(content, str):
                            prompt = content
                        elif isinstance(content, list):
                            for part in content:
                                if isinstance(part, dict) and part.get("type") == "text":
                                    prompt = part.get("text")
                                    break
                    if prompt and cwd:
                        break
            mtime = os.path.getmtime(path)
            size = os.path.getsize(path)
        except OSError:
            continue
        if sidechain:
            continue
        # Skip the near-empty ones: a session that never got a reply is noise.
        if size < 2048:
            continue
        # And the ones with nowhere to run. Claude resolves a session against
        # its project directory, so a conversation from a deleted worktree or a
        # moved repository cannot be resumed from anywhere. Most of these are
        # the throwaway .claude/worktrees/* that agent runs leave behind.
        if not cwd or not os.path.isdir(cwd):
            continue
        text = titles.get(sid) or " ".join((prompt or "(no prompt)").split())[:90]
        rows.append((mtime, cwd, branch or "", text, sid, path))

    rows.sort(reverse=True)
    for mtime, cwd, branch, text, sid, path in rows:
        stamp = time.strftime("%Y-%m-%d %H:%M", time.localtime(mtime))
        sys.stdout.write("\t".join([stamp, os.path.basename(cwd), branch, text, sid, cwd, path]) + "\n")
  '';

  # A transcript is for reading, and the tool-call records dwarf the...

  # A transcript is for reading, and the tool-call records dwarf the prose in the
  # raw JSONL -- so this renders it down to the conversation. Hoisted up here
  # beside the index rather than interpolated in the middle of the elisp, which
  # is where it used to sit: two callers now want it.

  transcript = pkgs.writers.writePython3Bin "claude-transcript" { flakeIgnore = [ "E501" ]; } ''
    import json
    import sys

    for line in open(sys.argv[1], errors="replace"):
        try:
            d = json.loads(line)
        except ValueError:
            continue
        if d.get("type") not in ("user", "assistant"):
            continue
        msg = d.get("message") or {}
        content = msg.get("content")
        parts = []
        if isinstance(content, str):
            parts.append(content)
        elif isinstance(content, list):
            for part in content:
                if isinstance(part, dict) and part.get("type") == "text":
                    parts.append(part.get("text") or "")
        body = "\n".join(p for p in parts if p.strip())
        if body.strip():
            who = "##" if d.get("type") == "user" else "###"
            sys.stdout.write("%s %s\n\n%s\n\n" % (who, d.get("type"), body))
  '';
in
{
  programs.emacs.extraConfig = lib.mkOrder 1450 ''
    ;;; Claude conversation history, across every project.

    (defun my/claude--sessions ()
      "Parsed rows from the session index, newest first."
      (let ((out (shell-command-to-string "${lib.getExe index}")))
        (delq nil
              (mapcar (lambda (line)
                        (let ((f (split-string line "\t")))
                          (when (= (length f) 7) f)))
                      (split-string out "\n" t)))))

    ;; This project's conversations first.
    ;;
    ;; The index spans every project, newest first, which is what you want for
    ;; "find that conversation from last week" and wrong for the ordinary case
    ;; of picking up where you left off here. The picker now offers only this
    ;; project's conversations, and every conversation with a prefix argument.
    ;; If the current directory has none, it falls back to showing everything
    ;; rather than an empty prompt.
    ;;
    ;; The predicate reads its root from a defvar instead of closing over a
    ;; `let': this file is generated without a lexical-binding cookie, so a
    ;; lambda cannot capture a local and would see the global value instead.
    (defvar my/claude--root nil
      "Project root `my/claude--row-here-p' matches against.")

    (defun my/claude--project-root ()
      "Root of the project the current buffer belongs to."
      (expand-file-name
       (or (and (fboundp 'projectile-project-root)
                (ignore-errors (projectile-project-root)))
           (and (fboundp 'project-current)
                (ignore-errors
                  (let ((pr (project-current nil)))
                    (and pr (project-root pr)))))
           default-directory)))

    (defun my/claude--row-here-p (f)
      "Non-nil when session row F took place under `my/claude--root'.
    `file-in-directory-p' rather than `string-prefix-p': the latter counts
    ~/nix-config-literate as living under ~/nix-config, since one path really
    is a prefix of the other. Two sibling projects whose names share a stem is
    not an edge case here, it is the literate setup."
      (file-in-directory-p (nth 5 f) my/claude--root))

    (defun my/claude--pick (prompt &optional all)
      "Choose a session, returning its field list.
    Offers only the current project's conversations unless ALL is non-nil."
      (let* ((my/claude--root (my/claude--project-root))
             (rows (my/claude--sessions))
             (here (seq-filter #'my/claude--row-here-p rows))
             (rows (if (or all (null here)) rows here))
             (table (mapcar (lambda (f)
                              (cons (format "%s  %-22s %-18s %s"
                                            (nth 0 f) (nth 1 f)
                                            (truncate-string-to-width (nth 2 f) 18)
                                            (nth 3 f))
                                    f))
                            rows)))
        (unless table (user-error "No Claude sessions found"))
        ;; Order is meaningful here (newest first), so the completion table must
        ;; not be re-sorted alphabetically behind our back.
        (let* ((choice (completing-read
                        prompt
                        (lambda (str pred action)
                          (if (eq action 'metadata)
                              '(metadata (display-sort-function . identity)
                                         (cycle-sort-function . identity))
                            (complete-with-action action table str pred)))
                        nil t)))
          (cdr (assoc choice table)))))

    (defvar-local my/claude--resumed-sid nil
      "Conversation this session was resumed from, when it was resumed.

    The transcript path is the exact handle between a running session and its
    file on disk, but it only holds until a resumed session says something:
    `claude --resume' continues the conversation into a transcript of its own,
    and the hooks then report that new file. This is the handle that does not
    move, so the chat list can still tell that a row in the history and the
    session running in the pane are one conversation.")

    (defun my/claude--live-session-for (sid path)
      "Key of the session already running conversation SID, if one is.
    Matched on the transcript at PATH while a session is still writing that
    file, and on the conversation it was resumed from once it is not."
      (when (and (fboundp 'claude-code-ide-manager--build-items)
                 (fboundp 'claude-code-ide-manager--session-buffer))
        (catch 'found
          (dolist (item (claude-code-ide-manager--build-items '(:type global)))
            (let* ((key (claude-code-ide-manager-item-session-key item))
                   (buf (claude-code-ide-manager--session-buffer key)))
              (when (and (buffer-live-p buf)
                         (or (and path
                                  (equal path (buffer-local-value
                                               'my/claude--transcript-path buf)))
                             (and sid
                                  (equal sid (buffer-local-value
                                              'my/claude--resumed-sid buf)))))
                (throw 'found key))))
          nil)))

    (defun my/claude-resume-session (sid cwd &optional label path)
      "Resume conversation SID in a claude-code-ide session rooted at CWD.
    LABEL, when given, names the session so the manager sidebar has something
    to show for it. PATH is the conversation's transcript, recorded on the new
    session's buffer so the chat list can tell the two are one thing before the
    first hook has fired and told it the same.

    Runs in the conversation's own directory: Claude resolves a session against
    the project it belongs to and does not find it from anywhere else.

    Started through claude-code-ide rather than by typing `claude --resume' into
    a bare vterm, which is what this used to do. A raw vterm is invisible to
    everything that makes the manager sidebar useful -- it is not in the session
    registry, so it gets no row, no state glyph and no saved layout, and it has
    no MCP server, so Claude cannot reach xref or the diagnostics. A resumed
    conversation is a conversation; it should arrive with the same machinery a
    fresh one does.

    `claude-code-ide-cli-extra-flags' is the seam for this: the only documented
    way in is the -r flag, which makes the CLI draw its own picker, and the
    picker is exactly what this command exists to replace. Bound dynamically
    around a private entry point, because the public commands cannot express
    \"this directory, a new session, these flags\" -- `claude-code-ide-resume'
    would toggle into the project's existing session instead of starting one on
    the conversation asked for.

    A conversation already resumed and still running is switched into rather
    than resumed again: a second CLI on one conversation is two panes, two sets
    of hooks and two claims on the transcript, and it is never what picking the
    row meant."
      (unless (file-directory-p cwd)
        (user-error "That conversation's directory no longer exists: %s" cwd))
      (require 'claude-code-ide)
      (if-let* ((running (my/claude--live-session-for sid path)))
          (my/claude-show-session running)
        (let* ((claude-code-ide-cli-extra-flags (format "--resume %s" sid))
               (session (claude-code-ide--start-session nil nil cwd t))
               ;; The struct's own buffer rather than the current one: this
               ;; happens to run in the new session's buffer, because the
               ;; package selects its window on the way out, and that is a
               ;; setting away from being false.
               (buf (or (and (claude-code-ide-session-p session)
                             (claude-code-ide-session-buffer session))
                        (and (claude-code-ide-session-buffer-p (current-buffer))
                             (current-buffer)))))
          (when (buffer-live-p buf)
            (with-current-buffer buf
              (setq-local my/claude--resumed-sid sid)
              (when path
                (setq-local my/claude--transcript-path path)))
            ;; Cosmetic, and deliberately best-effort: an unnamed sibling
            ;; session is still a working session, and it is not worth an error
            ;; on the way into one if the fork renames or moves either private
            ;; function.
            (when label
              (ignore-errors
                (when-let* ((key (claude-code-ide-manager--session-key-for-buffer
                                  buf)))
                  (claude-code-ide-manager-rename-session
                   key (truncate-string-to-width label 28)))))))))

    (defun my/claude-resume (&optional all)
      "Pick a past Claude conversation from this project and resume it.
    With a prefix argument ALL, offer conversations from every project."
      (interactive "P")
      (let ((row (my/claude--pick (if all "Resume any Claude session: "
                                    "Resume Claude session: ")
                                  all)))
        (my/claude-resume-session (nth 4 row) (nth 5 row) (nth 3 row) (nth 6 row))))

    (defun my/claude--render-transcript (path sid header)
      "Render the conversation at PATH read-only and show it.
    SID names the buffer; HEADER is the line put above the conversation."
      (let ((buf (get-buffer-create (format "*claude transcript: %s*" sid))))
        (with-current-buffer buf
          (let ((inhibit-read-only t))
            (erase-buffer)
            (insert header "\n\n")
            (insert (shell-command-to-string
                     (format "%s %s" "${lib.getExe transcript}"
                             (shell-quote-argument path))))
            (goto-char (point-min))
            (markdown-mode)
            (view-mode 1)))
        (pop-to-buffer buf)))

    (defun my/claude-view (&optional all)
      "Open a past conversation as text, without starting Claude.
    With a prefix argument ALL, offer conversations from every project."
      (interactive "P")
      (let ((row (my/claude--pick (if all "View any Claude transcript: "
                                    "View Claude transcript: ")
                                  all)))
        (my/claude--render-transcript
         (nth 6 row) (nth 4 row)
         (format "# %s  %s  %s" (nth 0 row) (nth 1 row) (nth 2 row)))))

    (defun my/claude-search (term)
      "Search every past conversation for TERM and open the one you pick."
      (interactive "sSearch all Claude conversations: ")
      (let* ((default-directory (expand-file-name "~/.claude/projects"))
             (hits (split-string
                    (shell-command-to-string
                     (format "rg --no-heading --with-filename --max-count 1 -l -F %s . 2>/dev/null"
                             (shell-quote-argument term)))
                    "\n" t)))
        (unless hits (user-error "No conversation mentions %s" term))
        (message "%d conversations mention %s" (length hits) term)
        (find-file (completing-read "Transcript: " hits nil t))))

    ;;; ------------------------------------------------------------------
    ;;; Every conversation in one list
    ;;; ------------------------------------------------------------------
    ;;
    ;; The manager sidebar answers "what is running". Its rows come from the
    ;; live session registry filtered on `process-live-p', so a conversation
    ;; that is not open right now has no row and cannot be given one. The
    ;; transcripts on disk are the other half, and the larger half: a handful of
    ;; sessions running against a thousand conversations kept.
    ;;
    ;; This is both halves in one list. A live row carries the glyph the sidebar
    ;; would draw for it and RET switches into it; a past row carries no glyph
    ;; and RET resumes it. Told apart rather than blended, because the two
    ;; actions differ in kind -- one moves the point, the other starts a
    ;; process.

    (defvar my/claude--chats-scope 'all
      "Whether the chat list shows `project' or `all' conversations.
    Every project by default: this list exists to be browsed, and the fold
    below keeps that from being a wall of text -- five conversations a project,
    the rest a TAB away. Narrowing to one project is the special case, and `a'
    is what asks for it.")

    ;; Faces by meaning rather than by colour, so the theme decides the colour.
    ;; `error', `warning' and `success' already read as stop, look and done in
    ;; any theme, and the list agrees with the sidebar because both now end up
    ;; at the same three faces.
    (defface my/claude-chats-project-face
      '((t (:inherit font-lock-keyword-face :weight bold)))
      "Face for a project heading in the chat list.")

    (defface my/claude-chats-fold-face
      '((t (:inherit font-lock-comment-face)))
      "Face for the line that folds away a project's older conversations.")

    (defun my/claude--chats-glyph-face (glyph)
      "Face for GLYPH, taken from the meaning claude-code-ide gives it.
    Compared against the package's own constants rather than against literal
    characters, so changing a glyph upstream drops the colour rather than
    quietly colouring the wrong state."
      (cond
       ((not (boundp 'claude-code-ide-manager--needs-input-glyph)) 'default)
       ((member glyph (list claude-code-ide-manager--needs-input-glyph
                            claude-code-ide-manager--failed-glyph))
        'error)
       ((equal glyph claude-code-ide-manager--done-glyph) 'success)
       ((equal glyph claude-code-ide-manager--working-glyph)
        'font-lock-keyword-face)
       ((equal glyph claude-code-ide-manager--bell-glyph) 'warning)
       (t 'default)))

    (defvar my/claude--chats-index nil
      "Conversation index the chat list is being built from.
    A defvar rather than an argument threaded inward, for the reason
    `my/claude--root' is one: this file is generated without a lexical-binding
    cookie, so a lambda cannot capture a local. Bound once per refresh, because
    reading it shells out.")

    (defvar my/claude--chats-index-cache nil
      "Cons of the time the index was last read and the rows it returned.")

    (defvar my/claude--chats-force-index nil
      "Non-nil while a refresh should re-read the index rather than reuse it.")

    (defun my/claude--chats-read-index (&optional force)
      "Index rows, from the cache unless FORCE or the cache has aged out.
    Reading the index spawns a process that walks every transcript on disk. The
    glyph refreshes want to redraw far more often than that history changes: a
    turn starting or finishing moves the live half of the list and leaves every
    other row exactly as it was. So a state change redraws from the cache and
    `g' re-reads."
      (let ((now (float-time)))
        (when (or force
                  (null my/claude--chats-index-cache)
                  (> (- now (car my/claude--chats-index-cache)) 30))
          (setq my/claude--chats-index-cache (cons now (my/claude--sessions))))
        (cdr my/claude--chats-index-cache)))

    (defun my/claude--chat-here-p (row)
      "Non-nil when chat ROW took place under `my/claude--root'.
    Reads its root from the defvar for the reason `my/claude--row-here-p' does."
      (file-in-directory-p (plist-get row :cwd) my/claude--root))

    (defun my/claude--chat-title (path sid fallback)
      "Title the index gives the conversation at PATH or with id SID, or FALLBACK.
    claude-code-ide names a live session after its directory, which says where
    a conversation is and nothing about which one it is -- so a live row borrows
    the title the index already has for its transcript, and reads the same as
    the past rows below it. SID is the same lookup for a resumed session, whose
    transcript has moved on but whose conversation the index still knows.
    FALLBACK covers a session that has not written anything yet, or one running
    somewhere the index skips."
      (or (when (or path sid)
            (let ((found nil))
              (dolist (f my/claude--chats-index)
                (when (and (not found)
                           (or (and path (equal (nth 6 f) path))
                               (and sid (equal (nth 4 f) sid))))
                  (setq found (nth 3 f))))
              found))
          fallback))

    (defun my/claude--live-chats ()
      "Rows for the sessions running right now.
    Built from claude-code-ide's own items, so the glyph is the one its sidebar
    would draw for each -- the states the Claude Code hooks push in included.

    Empty, rather than an error, when the package has never been loaded: the
    list is then just the conversation history, which is a reasonable thing to
    open before starting anything."
      (when (and (fboundp 'claude-code-ide-manager--build-items)
                 (boundp 'claude-code-ide--sessions))
        (let ((rows nil))
          (dolist (item (claude-code-ide-manager--build-items '(:type global)))
            (let* ((key (claude-code-ide-manager-item-session-key item))
                   (dir (claude-code-ide-manager-item-directory item))
                   (buf (claude-code-ide-manager--session-buffer key))
                   (path (and (buffer-live-p buf)
                              (buffer-local-value 'my/claude--transcript-path
                                                  buf)))
                   (sid (and (buffer-live-p buf)
                             (buffer-local-value 'my/claude--resumed-sid buf))))
              (push (list :live t
                          :key key
                          :glyph (string-trim
                                  (claude-code-ide-manager--marker-gutter item))
                          :cwd dir
                          :project (file-name-nondirectory
                                    (directory-file-name dir))
                          :when "live"
                          :title (my/claude--chat-title
                                  path sid
                                  (claude-code-ide-manager-item-display-name item))
                          :sid sid
                          :path path)
                    rows)))
          (nreverse rows))))

    (defun my/claude--past-chats (live)
      "Rows for the conversations on disk, minus the ones LIVE already covers.
    Matched on the transcript path, which is exact: it is the file the CLI says
    it is writing, and the same string the index reports. claude-code-ide's own
    session id cannot do this job -- it is its own, and the CLI never sees it.

    A resumed conversation is matched on the conversation it came from as well,
    since the CLI writes the continuation to a transcript of its own and the
    path stops matching as soon as it does."
      (let ((open (delq nil (mapcar (lambda (row) (plist-get row :path)) live)))
            (resumed (delq nil (mapcar (lambda (row) (plist-get row :sid)) live)))
            (rows nil))
        (dolist (f my/claude--chats-index)
          (unless (or (member (nth 6 f) open)
                      (member (nth 4 f) resumed))
            (push (list :live nil
                        :glyph ""
                        :cwd (nth 5 f)
                        :project (nth 1 f)
                        :when (nth 0 f)
                        :title (nth 3 f)
                        :sid (nth 4 f)
                        :path (nth 6 f))
                  rows)))
        (nreverse rows)))

    (defvar my/claude--chats-narrowed nil
      "Non-nil when the last redraw actually narrowed to one project.
    Not the same question as `my/claude--chats-scope': asking for one project
    with no conversations in it falls back to showing every project, and the
    header has to say what is on screen rather than what was asked for.")

    (defun my/claude--chats-entries ()
      "Live sessions first, then the conversations on disk by recency."
      (let* ((my/claude--chats-index
              (my/claude--chats-read-index my/claude--chats-force-index))
             (live (my/claude--live-chats))
             (rows (append live (my/claude--past-chats live)))
             (entries nil))
        (setq my/claude--chats-narrowed nil)
        (when (eq my/claude--chats-scope 'project)
          (let* ((my/claude--root (my/claude--project-root))
                 (here (seq-filter #'my/claude--chat-here-p rows)))
            ;; An empty list is worse than a wide one: a project with no history
            ;; would otherwise open a pane with nothing in it and no clue that
            ;; `a' is what fills it.
            (when here
              (setq rows here
                    my/claude--chats-narrowed t))))
        (dolist (row rows)
          (let ((glyph (plist-get row :glyph)))
            (push (list row
                        (vector (propertize glyph 'face
                                            (my/claude--chats-glyph-face glyph))
                                (propertize (plist-get row :title)
                                            'face (if (plist-get row :live)
                                                      'bold
                                                    'default))
                                (plist-get row :when)))
                  entries)))
        (nreverse entries)))

    (defvar my/claude--chats-limit 5
      "Conversations shown per project before the rest are folded away.")

    (defvar my/claude--chats-expanded nil
      "Working directories whose folded conversations are currently shown.")

    (defun my/claude--chats-more-row (cwd hidden expanded)
      "The fold line for CWD: HIDDEN conversations away, EXPANDED as it stands."
      (list (list :more cwd)
            (vector ""
                    (propertize (if expanded
                                    "fewer"
                                  (format "%d older" hidden))
                                'face 'my/claude-chats-fold-face)
                    "")))

    (defun my/claude--chats-groups ()
      "Entries grouped by project, live sessions first, the old ones folded.

    Keyed on the working directory rather than its name. Two directories can
    share a basename -- a worktree beside the repository it came from, which is
    how several tickets get worked at once -- and merging those under one
    heading would file conversations from different trees together. The
    heading falls back to parent/name when a basename is not unique.

    The fold applies to the conversations on disk, not to the running ones: a
    project with eight sessions open wants all eight, and its history from
    March does not need to be on screen to get at them."
      (let ((order nil) (buckets nil) (counts nil) (groups nil))
        (dolist (entry (my/claude--chats-entries))
          (let* ((cwd (plist-get (nth 0 entry) :cwd))
                 (bucket (assoc cwd buckets)))
            (unless bucket
              (setq bucket (list cwd))
              (push bucket buckets)
              (push cwd order))
            (setcdr bucket (cons entry (cdr bucket)))))
        (setq order (nreverse order))
        (dolist (cwd order)
          (let* ((name (file-name-nondirectory (directory-file-name cwd)))
                 (seen (assoc name counts)))
            (if seen
                (setcdr seen (1+ (cdr seen)))
              (push (cons name 1) counts))))
        (dolist (cwd order)
          (let* ((dir (directory-file-name cwd))
                 (name (file-name-nondirectory dir))
                 (heading (if (> (cdr (assoc name counts)) 1)
                              (concat (file-name-nondirectory
                                       (directory-file-name
                                        (file-name-directory dir)))
                                      "/" name)
                            name))
                 (expanded (member cwd my/claude--chats-expanded))
                 (live nil)
                 (past nil)
                 (rows nil))
            (dolist (entry (nreverse (cdr (assoc cwd buckets))))
              (if (plist-get (nth 0 entry) :live)
                  (push entry live)
                (push entry past)))
            (setq live (nreverse live)
                  past (nreverse past))
            (setq rows (append live (if expanded
                                        past
                                      (seq-take past my/claude--chats-limit))))
            (when (> (length past) my/claude--chats-limit)
              (setq rows (append rows
                                 (list (my/claude--chats-more-row
                                        cwd
                                        (- (length past) my/claude--chats-limit)
                                        expanded)))))
            (push (cons (propertize heading
                                    'face 'my/claude-chats-project-face)
                        rows)
                  groups)))
        (nreverse groups)))

    (defun my/claude--chats-goto-fold (cwd)
      "Put the point on CWD's fold line. Non-nil when there was one."
      (let ((target nil))
        (goto-char (point-min))
        (while (and (not target) (not (eobp)))
          (let ((id (tabulated-list-get-id)))
            (when (and id (equal (plist-get id :more) cwd))
              (setq target (point))))
          (forward-line 1))
        (when target
          (goto-char target)
          t)))

    (defun my/claude-chats-toggle-group ()
      "Fold or unfold the older conversations of the project at point.
    Leaves the point on the fold line rather than on whatever row its old line
    number now holds. Unfolding pushes that line down past everything it
    revealed, so restoring by number lands on a conversation -- and a second
    RET there resumes one nobody asked for."
      (interactive)
      (let* ((row (tabulated-list-get-id))
             (cwd (and row (or (plist-get row :more) (plist-get row :cwd))))
             (line (line-number-at-pos)))
        (unless cwd (user-error "No project on this line"))
        (setq my/claude--chats-expanded
              (if (member cwd my/claude--chats-expanded)
                  (delete cwd my/claude--chats-expanded)
                (cons cwd my/claude--chats-expanded)))
        (tabulated-list-print)
        (unless (my/claude--chats-goto-fold cwd)
          (goto-char (point-min))
          (forward-line (1- line)))))

    (defun my/claude--chats-redraw ()
      "Redraw the list in the current buffer, keeping the point on its line.
    The header goes in after the print, not before: it names the scope the
    rows are actually in, and that is only known once they have been built."
      (let ((line (line-number-at-pos)))
        (tabulated-list-print)
        (my/claude--chats-header)
        (goto-char (point-min))
        (forward-line (1- line))))

    (defun my/claude-chats-refresh ()
      "Re-read the conversation history and rebuild the list."
      (interactive)
      (let ((my/claude--chats-force-index t))
        (my/claude--chats-redraw)))

    (defun my/claude--chats-restate (&rest _)
      "Redraw the chat list when a session's state changes under it.
    The glyph is the part of the list that goes stale fastest: a turn that
    finishes while the list is on screen would otherwise still read as working
    until the next `g'. claude-code-ide-manager keeps its own sidebar current
    through these same three signals -- the two state hooks, and the setter the
    Claude Code hooks reach over emacsclient -- so the list rides on them too.

    Only when the list is actually on a window somewhere. Redrawing a buffer
    nobody is looking at would spend a subprocess on every turn transition in
    every project, and `my/claude-chats' re-reads on the way in anyway."
      (when-let* ((buf (get-buffer "*claude chats*")))
        (when (get-buffer-window buf t)
          (with-current-buffer buf
            (my/claude--chats-redraw)))))

    (with-eval-after-load 'claude-code-ide
      (add-hook 'claude-code-ide-session-idle-hook #'my/claude--chats-restate)
      (add-hook 'claude-code-ide-session-working-hook #'my/claude--chats-restate)
      (advice-add 'claude-code-ide-session-idle-set-agent-state
                  :after #'my/claude--chats-restate))

    (defun my/claude-chats-toggle-scope ()
      "Switch between this project's conversations and every project's."
      (interactive)
      (setq my/claude--chats-scope
            (if (eq my/claude--chats-scope 'project) 'all 'project))
      (my/claude-chats-refresh)
      (message "Claude chats: %s"
               (if (eq my/claude--chats-scope 'all)
                   "every project"
                 "this project")))

    (defun my/claude--chats-window ()
      "The window showing the chat list, if it is on screen."
      (get-buffer-window "*claude chats*" t))

    (defun my/claude--chats-close ()
      "Close the chat list window, leaving the buffer behind it."
      (when-let* ((win (my/claude--chats-window)))
        (when (window-live-p win)
          (delete-window win))))

    (defun my/claude-chats-visit ()
      "Enter the conversation on this line, resuming it when it is not running.
    On a fold line, unfolds the project instead.

    Closes the list on the way through, before the conversation opens. It is a
    picker and the two share a column: leaving it up would halve the pane the
    conversation is about to appear in."
      (interactive)
      (let ((row (tabulated-list-get-id)))
        (unless row (user-error "No conversation on this line"))
        (if (plist-get row :more)
            (my/claude-chats-toggle-group)
          (my/claude--chats-close)
          (if (plist-get row :live)
              (my/claude-show-session (plist-get row :key))
            (message "Resuming %s..." (plist-get row :title))
            (my/claude-resume-session (plist-get row :sid)
                                      (plist-get row :cwd)
                                      (plist-get row :title)
                                      (plist-get row :path))))))

    (defun my/claude-chats-view ()
      "Read the conversation on this line without starting Claude."
      (interactive)
      (let ((row (tabulated-list-get-id)))
        (when (or (null row) (plist-get row :more))
          (user-error "No conversation on this line"))
        (let ((path (plist-get row :path)))
          (unless path
            (user-error "This session has not written a transcript yet"))
          (my/claude--render-transcript
           path (or (plist-get row :sid) (plist-get row :project))
           (format "# %s  %s" (plist-get row :when) (plist-get row :project))))))

    (defvar my/claude-chats-mode-map
      (let ((map (make-sparse-keymap)))
        (define-key map (kbd "RET") #'my/claude-chats-visit)
        (define-key map (kbd "TAB") #'my/claude-chats-toggle-group)
        (define-key map (kbd "v") #'my/claude-chats-view)
        (define-key map (kbd "a") #'my/claude-chats-toggle-scope)
        (define-key map (kbd "r") #'my/claude-chats-refresh)
        (define-key map (kbd "g") #'my/claude-chats-refresh)
        (define-key map (kbd "q") #'quit-window)
        map)
      "Keymap for `my/claude-chats-mode'.
    Avoids h/n/e/i/p/f, which are movement and scrolling on this layout.")

    ;; Which scope you are in, on screen rather than in the echo area.
    ;;
    ;; `a' announced the switch in a message, and a message is gone by the time
    ;; you have read the second row. The list is grouped by project either way,
    ;; so a narrowed list and a wide one whose first group happens to be this
    ;; project look identical -- which is exactly when you want to be told.
    ;;
    ;; It rides in the "Chat" column header because that is the one line always
    ;; on screen and never scrolled away.
    (defun my/claude--chats-scope-label ()
      "How the header names the scope the rows on screen are in."
      (if my/claude--chats-narrowed
          (file-name-nondirectory (directory-file-name (my/claude--project-root)))
        "every project"))

    (defun my/claude--chats-header ()
      "Install the column header, with the current scope named in it."
      (setq tabulated-list-format
            (vector '("" 2 nil)
                    (list (format "Chat — %s" (my/claude--chats-scope-label)) 58 nil)
                    '("When" 18 nil)))
      (tabulated-list-init-header))

    (define-derived-mode my/claude-chats-mode tabulated-list-mode "Claude chats"
      "Every Claude conversation, the running ones and the kept ones."
      ;; The project is the group heading, so no column repeats it.
      (setq tabulated-list-padding 1
            tabulated-list-groups #'my/claude--chats-groups)
      (my/claude--chats-header))

    ;; The major mode map alone loses to evil's normal state, which is why RET
    ;; on a row did nothing: `evil-ret' moved down a line instead. Same keys
    ;; again, where evil can see them. `g' is left out deliberately -- binding
    ;; it here would take `gg' with it -- so `r' is the refresh in normal state.
    (with-eval-after-load 'evil
      (evil-set-initial-state 'my/claude-chats-mode 'normal)
      (evil-define-key 'normal my/claude-chats-mode-map
        (kbd "RET") #'my/claude-chats-visit
        (kbd "TAB") #'my/claude-chats-toggle-group
        (kbd "v") #'my/claude-chats-view
        (kbd "a") #'my/claude-chats-toggle-scope
        (kbd "r") #'my/claude-chats-refresh
        (kbd "q") #'quit-window))

    (defun my/claude-chats ()
      "Every Claude conversation in one list: the running ones and the kept ones.
    Grouped under the project each belongs to, running sessions at the top of
    their group and the rest by recency, five deep before the older ones fold
    away behind a line that unfolds them.

    A live row is prefixed with the state glyph claude-code-ide draws for it --
    `?' waiting on you, `✓' finished, `✗' failed, `⚙︎' working, `🔔' gone quiet --
    and RET switches into it. A past row has no glyph, and RET resumes it in its
    own project directory.

    Opens on every project, which is the case both the manager sidebar and
    `claude --resume' refuse; `a' narrows it to this one and back, and the
    column header says which of the two is on screen. TAB folds and unfolds a
    project, `v' reads a conversation without starting anything, `r' refreshes.

    Called again while it is up, closes it."
      (interactive)
      (if (my/claude--chats-window)
          (my/claude--chats-close)
        ;; The project `a' narrows to is the one you opened the list from.
        ;;
        ;; It is read from the list buffer's own `default-directory', and that
        ;; is inherited from whatever buffer was current when the buffer was
        ;; first created -- so without this it stayed pinned to the project of
        ;; the very first invocation, and narrowing in a second project
        ;; silently filtered by the first one.
        (let ((root (my/claude--project-root))
              (buf (get-buffer-create "*claude chats*")))
          (with-current-buffer buf
            (setq default-directory root)
            (my/claude-chats-mode)
            (my/claude-chats-refresh))
          (pop-to-buffer buf))))
  '';
}
