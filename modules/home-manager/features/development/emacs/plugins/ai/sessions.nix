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
        text = " ".join((prompt or "(no prompt)").split())[:90]
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

    (defun my/claude--pick (prompt)
      "Choose a session, returning its field list."
      (let* ((rows (my/claude--sessions))
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

    (defun my/claude-resume ()
      "Pick any past Claude conversation and resume it.
    Runs in the directory the conversation belonged to, because Claude resolves
    the session against its project and would not find it from anywhere else."
      (interactive)
      (let* ((row (my/claude--pick "Resume Claude session: "))
             (sid (nth 4 row))
             (cwd (nth 5 row)))
        (if (not (file-directory-p cwd))
            (user-error "That conversation's directory no longer exists: %s" cwd)
          (let ((default-directory (file-name-as-directory cwd)))
            (vterm (format "*claude:%s*" (file-name-nondirectory (directory-file-name cwd))))
            (vterm-send-string (format "claude --resume %s" sid))
            (vterm-send-return)))))

    (defun my/claude-view ()
      "Open a past conversation as text, without starting Claude."
      (interactive)
      (let* ((row (my/claude--pick "View Claude transcript: "))
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
