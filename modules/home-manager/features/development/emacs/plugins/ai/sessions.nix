{ lib, pkgs, ... }:
let
  # Claude Code keeps every conversation as JSONL under ~/.claude/projects, one
  # directory per working directory. `claude --resume` can reopen them, but its
  # picker only lists the current project's -- so a conversation from another
  # repo is unreachable even though the transcript is right there on disk.
  #
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
                    # Sidechains are subagent transcripts -- real conversations,
                    # but not ones you resume, so they must not crowd the picker.
                    if d.get("isSidechain"):
                        prompt = prompt or "[subagent]"
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
        # Skip the near-empty ones: a session that never got a reply is noise.
        if size < 2048:
            continue
        text = titles.get(sid) or " ".join((prompt or "(no prompt)").split())[:90]
        rows.append((mtime, cwd or "?", branch or "", text, sid, path))

    rows.sort(reverse=True)
    for mtime, cwd, branch, text, sid, path in rows:
        stamp = time.strftime("%Y-%m-%d %H:%M", time.localtime(mtime))
        sys.stdout.write("\t".join([stamp, os.path.basename(cwd), branch, text, sid, cwd, path]) + "\n")
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

    (defun my/claude-resume (&optional all)
      "Pick a past Claude conversation from this project and resume it.
    With a prefix argument ALL, offer conversations from every project.
    Runs in the directory the conversation belonged to, because Claude resolves
    the session against its project and would not find it from anywhere else."
      (interactive "P")
      (let* ((row (my/claude--pick (if all "Resume any Claude session: "
                                     "Resume Claude session: ")
                                   all))
             (sid (nth 4 row))
             (cwd (nth 5 row)))
        (if (not (file-directory-p cwd))
            (user-error "That conversation's directory no longer exists: %s" cwd)
          (let ((default-directory (file-name-as-directory cwd)))
            (vterm (format "*claude:%s*" (file-name-nondirectory (directory-file-name cwd))))
            (vterm-send-string (format "claude --resume %s" sid))
            (vterm-send-return)))))

    ;; Switching between the sessions running right now.
    ;;
    ;; claude-code-switch-to-buffer only reaches the session belonging to the
    ;; current project, so a second project -- or a second instance in the same
    ;; one -- is unreachable once you have moved away from its buffer. This
    ;; lists every live one.
    (defun my/claude--live-session-p (b)
      "Non-nil when buffer B is a running Claude session."
      (and (string-prefix-p "*claude:" (buffer-name b))
           (get-buffer-process b)))

    (defun my/claude-switch ()
      "Switch to one of the Claude sessions running right now."
      (interactive)
      (let ((names (mapcar #'buffer-name
                           (seq-filter #'my/claude--live-session-p (buffer-list)))))
        (cond
         ((null names) (user-error "No Claude session is running"))
         ((null (cdr names)) (pop-to-buffer (car names)))
         (t (pop-to-buffer (completing-read "Claude session: " names nil t))))))

    (defun my/claude-view (&optional all)
      "Open a past conversation as text, without starting Claude.
    With a prefix argument ALL, offer conversations from every project."
      (interactive "P")
      (let* ((row (my/claude--pick (if all "View any Claude transcript: "
                                     "View Claude transcript: ")
                                   all))
             (path (nth 6 row))
             (buf (get-buffer-create (format "*claude transcript: %s*" (nth 4 row)))))
        (with-current-buffer buf
          (let ((inhibit-read-only t))
            (erase-buffer)
            (insert (format "# %s  %s  %s\n\n" (nth 0 row) (nth 1 row) (nth 2 row)))
            ;; Rendered rather than raw JSONL: the transcript is for reading, and
            ;; the tool-call records dwarf the prose in the raw file.
            (dolist (line (split-string
                           (shell-command-to-string
                            (format "%s %s" "${lib.getExe (pkgs.writers.writePython3Bin "claude-transcript" { flakeIgnore = [ "E501" ]; } ''
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
                            '')}" (shell-quote-argument path)))
                           "\n"))
              (insert line "\n"))
            (goto-char (point-min))
            (markdown-mode)
            (view-mode 1)))
        (pop-to-buffer buf)))

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
  '';
}
