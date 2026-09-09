# development emacs plugins notes obsidian

{
  ...
}:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      obsidian
    ];

  programs.emacs.extraConfig = ''
    ;;; Obsidian — obsidian.el over the same vault the Obsidian app uses.
    ;;;
    ;;; Same directory, same markdown files, so notes edited here and in the app
    ;;; stay in sync exactly as they do from nvim. The vault path matches the nvim
    ;;; `dir' setting.
    ;;;
    ;;; Loaded on first use rather than at startup, which matters more than it looks:
    ;;; obsidian.el resolves its vault and starts a polling timer the moment it is
    ;;; required, and if the vault is missing it silently falls back to indexing
    ;;; `default-directory' instead. During the sandboxed byte-compile that meant
    ;;; scanning the nix build directory on a timer that could fire part-way through
    ;;; compilation — which is exactly the failure that showed up as an error landing
    ;;; at a different line on every build.

    ;; Everything obsidian.el provides that is named below, declared before it is
    ;; used. This is not decoration: nothing in this block loads obsidian.el, so
    ;; without the declarations the byte-compiler warns on all thirty-odd names
    ;; and, worse, cannot tell a typo from a lazily loaded symbol -- the whole
    ;; point of compiling the init at all. A `dolist' around `autoload' does not
    ;; do it either: the compiler only reads top-level `autoload' forms, so a
    ;; loop over a list of symbols registers with nobody until it runs.
    (defvar obsidian-directory)
    (defvar obsidian-inbox-directory)
    (defvar obsidian-daily-notes-directory)
    (defvar obsidian-templates-directory)
    (defvar obsidian-daily-note-template)
    (defvar obsidian-wiki-link-alias-first)
    (defvar obsidian-links-use-vault-path)
    (defvar obsidian-excluded-directories)
    (defvar obsidian-include-hidden-files)
    (defvar obsidian-vault-cache)
    (defvar obsidian--updated-time)
    ;; markdown-mode is required by the markview block, which lands after this
    ;; one in default.el.
    (defvar markdown-wiki-link-alias-first)

    (autoload 'global-obsidian-mode "obsidian" nil t)
    (autoload 'obsidian-backlink-jump "obsidian" nil t)
    (autoload 'obsidian-capture "obsidian" nil t)
    (autoload 'obsidian-daily-note "obsidian" nil t)
    (autoload 'obsidian-find-tag "obsidian" nil t)
    (autoload 'obsidian-follow-link-at-point "obsidian" nil t)
    (autoload 'obsidian-insert-link "obsidian" nil t)
    (autoload 'obsidian-insert-tag "obsidian" nil t)
    (autoload 'obsidian-insert-wikilink "obsidian" nil t)
    (autoload 'obsidian-jump "obsidian" nil t)
    (autoload 'obsidian-jump-back "obsidian" nil t)
    (autoload 'obsidian-move-file "obsidian" nil t)
    (autoload 'obsidian-remove-link "obsidian" nil t)
    (autoload 'obsidian-rescan-cache "obsidian" nil t)
    (autoload 'obsidian-toggle-backlinks-panel "obsidian" nil t)

    ;; The rest are not commands and are only ever called on a path that has
    ;; already required the package, so they need declaring but not autoloading.
    (declare-function obsidian-aliases "obsidian")
    (declare-function obsidian-apply-template "obsidian" (template-filename))
    (declare-function obsidian-file-p "obsidian" (&optional file))
    (declare-function obsidian-file-relative-name "obsidian" (f))
    (declare-function obsidian-file-to-absolute-path "obsidian" (file))
    (declare-function obsidian-files "obsidian")
    (declare-function obsidian-tags "obsidian")

    (setq obsidian-directory (expand-file-name "~/Documents/robertogoam")
          obsidian-inbox-directory "Inbox"
          obsidian-daily-notes-directory "Daily"
          ;; Vault-relative, both of them: `obsidian-daily-note' builds the
          ;; template path by concatenating obsidian-directory, this, and the
          ;; template name, so an absolute path here would produce
          ;; "~/Documents/robertogoam//Users/...". The values are the ones the
          ;; Obsidian app itself uses, from .obsidian/templates.json and
          ;; .obsidian/daily-notes.json, and the templates are the nix-managed
          ;; ones features/productivity/obsidian installs.
          obsidian-templates-directory "000 Meta/Templates"
          obsidian-daily-note-template "Daily.md"
          ;; nil, matching the app. Obsidian writes an aliased link as
          ;; [[PageName|display text]] -- name first -- and with alias-first on,
          ;; obsidian.el read the display text as the note to open, so following
          ;; any aliased link went to the wrong place or offered to create a note
          ;; named after the label. The two variables have to agree because
          ;; markdown-mode does the parsing; setq bypasses the defcustom :set
          ;; that would otherwise keep them in step.
          obsidian-wiki-link-alias-first nil
          markdown-wiki-link-alias-first nil
          obsidian-links-use-vault-path nil
          ;; "Old backups" holds three stale copies of the whole vault: 451 of
          ;; the 591 markdown files in the tree, and 145M of it. Indexed, they
          ;; dominated every jump list and every completion with three dead
          ;; duplicates of each real note, and they are most of what the startup
          ;; vault walk was spending its seconds on. Excluded here, not deleted:
          ;; they stay readable in the app, and SPC n s with a prefix argument
          ;; still searches them.
          ;;
          ;; Absolute paths, despite what the docstring says. The predicate is
          ;; `(s-starts-with-p (expand-file-name excluded-dir) file)', and
          ;; expand-file-name on a relative entry resolves it against whatever
          ;; `default-directory' happens to be, not against the vault.
          obsidian-excluded-directories
          (list (expand-file-name "Old backups" obsidian-directory)
                (expand-file-name ".claude" obsidian-directory))
          obsidian-include-hidden-files nil)

    (defun my/obsidian-vault ()
      "Return the vault directory, or signal when it is not on this machine."
      (if (file-directory-p obsidian-directory)
          obsidian-directory
        (user-error "Obsidian vault %s is not present" obsidian-directory)))

    (defun my/obsidian-ensure ()
      "Load obsidian.el and turn it on, once, if the vault is actually present."
      (unless (featurep 'obsidian)
        (my/obsidian-vault)
        (require 'obsidian)
        (global-obsidian-mode 1))
      (featurep 'obsidian))

    ;; Opening a note from inside the vault is the other natural trigger, so the mode
    ;; comes up without having to reach for a leader key first.
    (defun my/obsidian-maybe-enable ()
      "Turn obsidian on when this buffer is a file inside the vault."
      (when (and buffer-file-name
                 (file-directory-p obsidian-directory)
                 (string-prefix-p (expand-file-name obsidian-directory)
                                  (expand-file-name buffer-file-name)))
        (my/obsidian-ensure)))

    ;; No startup warm-up. There used to be a one-shot idle timer here that
    ;; loaded obsidian.el eight seconds in, so the vault walk happened
    ;; before anything waited on it rather than on the first note opened.
    ;;
    ;; The vault lives under ~/Documents, which macOS guards with TCC. Any
    ;; process reading it must be granted access, and that grant is bound to
    ;; the binary's identity -- for an unsigned nix build, its store path.
    ;; Every rebuild produces a new path, so the grant never carries over and
    ;; the warm-up asked again on the next launch, for a vault the session
    ;; might never touch. This is the same trap as the App Management prompt
    ;; documented in cli/zsh.nix: nix rewrites the binary the grant belongs
    ;; to.
    ;;
    ;; Loading on demand means the prompt arrives when you actually open a
    ;; note -- an answerable moment, not an unexplained dialog at login. The
    ;; cost is that first note paying the walk; my/obsidian-ensure is guarded
    ;; by `unless (featurep 'obsidian)', so it is paid once per session and
    ;; only by a session that goes near the vault.

    ;;; ------------------------------------------------------------------
    ;;; In-buffer completion
    ;;; ------------------------------------------------------------------

    ;; The gap this closes: obsidian.el ships exactly one completion source, a
    ;; `company' backend for tags. Nothing in this configuration uses company --
    ;; corfu reads `completion-at-point-functions' -- so typing [[ in a note
    ;; offered nothing at all, and every link had to be inserted through a
    ;; minibuffer command that leaves the buffer. Three capfs below put note
    ;; names, heading anchors and tags in the same popup as everything else.

    (defvar my/obsidian--link-cache nil
      "Memoised (STAMP CANDIDATES DIRS) for the wiki-link completion table.")

    (defun my/obsidian--link-table ()
      "Return (CANDIDATES DIRS) for wiki-link completion.
    CANDIDATES are the vault's note names and aliases; DIRS maps a note name to the
    folder it lives in, for the annotation.

    Memoised against obsidian.el's own index, because corfu asks on every keystroke
    and a vault of several hundred notes is not something to walk that often. The
    stamp is the index's update time plus its size, so an in-place rename that
    happens to land on the same second still invalidates it."
      (let ((stamp (list obsidian--updated-time
                         (and obsidian-vault-cache
                              (hash-table-count obsidian-vault-cache)))))
        (unless (equal (car my/obsidian--link-cache) stamp)
          (let ((dirs (make-hash-table :test 'equal))
                (names nil))
            (dolist (file (obsidian-files))
              (let ((name (file-name-sans-extension (file-name-nondirectory file)))
                    (dir (file-name-directory (obsidian-file-relative-name file))))
                (push name names)
                (unless (gethash name dirs)
                  (puthash name (if dir (directory-file-name dir) "") dirs))))
            ;; delete-dups compares with `equal', which is the right notion here:
            ;; two notes of the same name in different folders produce the same
            ;; link text, and with obsidian-links-use-vault-path nil there is no
            ;; way to write a link that tells them apart anyway.
            (setq my/obsidian--link-cache
                  (list stamp
                        (append (delete-dups (nreverse names)) (obsidian-aliases))
                        dirs))))
        (cdr my/obsidian--link-cache)))

    (defun my/obsidian--annotate-note (candidate)
      "Show the folder CANDIDATE lives in, or mark it as an alias."
      (let ((dirs (cadr (my/obsidian--link-table))))
        (if (not (gethash candidate dirs))
            "  alias"
          (let ((dir (gethash candidate dirs)))
            (unless (string-empty-p dir)
              (concat "  " dir))))))

    (defun my/obsidian--wikilink-field ()
      "Bounds of the note-name field of the wiki link being typed at point.
    Returns (START . END), or nil when point is not in one."
      (save-excursion
        (let ((pos (point))
              (bol (line-beginning-position)))
          (when (re-search-backward "\\[\\[" bol t)
            (let ((open (match-end 0)))
              ;; A closing ]] between the brackets and point means that link is
              ;; already finished and point is somewhere after it.
              (unless (save-excursion (search-forward "]]" pos t))
                (let* ((text (buffer-substring-no-properties open pos))
                       (bar (string-match-p "|" text)))
                  (cond
                   ;; No alias yet: the whole field is the note name.
                   ((null bar) (cons open pos))
                   ;; [[alias|PageName]], if that convention is ever turned back
                   ;; on: the name is what follows the bar.
                   (obsidian-wiki-link-alias-first (cons (+ open bar 1) pos))
                   ;; [[PageName|display text]], the app's convention: the name is
                   ;; already typed and what is being written is prose.
                   (t nil)))))))))

    (defun my/obsidian--headings (note)
      "ATX headings in NOTE, a note name without its extension."
      (let ((file (obsidian-file-to-absolute-path (concat note ".md"))))
        (when (file-readable-p file)
          (with-temp-buffer
            (insert-file-contents file)
            (goto-char (point-min))
            (let (headings)
              (while (re-search-forward "^#+[ \t]+\\(.+?\\)[ \t]*$" nil t)
                (push (match-string-no-properties 1) headings))
              (nreverse headings))))))

    (defun my/obsidian--tag-field ()
      "Bounds of the tag being typed after a # at point, or nil."
      (save-excursion
        (let ((pos (point)))
          (skip-chars-backward "-A-Za-z0-9_/")
          (let ((start (point)))
            (when (and (> start (point-min))
                       (eq (char-before start) ?#))
              (goto-char (1- start))
              ;; A tag opens a line or follows whitespace or an opening bracket.
              ;; This is also what rules out a heading: "# Title" puts a space
              ;; after the #, so the skip above never reaches back past it, and
              ;; a bare "###" leaves another # before this one.
              (when (or (bolp)
                        (memq (char-before) '(?\s ?\t ?\( ?\[)))
                (cons start pos)))))))

    (defun my/obsidian-capf ()
      "Complete wiki-link targets, heading anchors and tags inside a vault note."
      (when (and (featurep 'obsidian) (obsidian-file-p))
        (let ((link (my/obsidian--wikilink-field)))
          (cond
           (link
            (let* ((text (buffer-substring-no-properties (car link) (cdr link)))
                   (anchor (string-match-p "#" text)))
              (if anchor
                  ;; [[Note#Heading]] -- past the #, the candidates come from
                  ;; that note rather than from the vault.
                  (list (+ (car link) anchor 1) (cdr link)
                        (my/obsidian--headings (substring text 0 anchor))
                        :exclusive 'no
                        :annotation-function (lambda (_) "  heading"))
                (list (car link) (cdr link)
                      (car (my/obsidian--link-table))
                      :exclusive 'no
                      :annotation-function #'my/obsidian--annotate-note))))
           ((my/obsidian--tag-field)
            (let ((tag (my/obsidian--tag-field)))
              (list (car tag) (cdr tag)
                    (obsidian-tags)
                    :exclusive 'no
                    :annotation-function (lambda (_) "  tag"))))))))

    ;; setq-local rather than add-hook. `my/setup-capf' runs from text-mode-hook,
    ;; which a derived mode runs before its own hook, and it *replaces* the
    ;; buffer-local list -- so this cons has to happen afterwards. add-hook would
    ;; also append the `t' sentinel that pulls the global capfs back in, which is
    ;; a change to what completes in every markdown buffer and not what is being
    ;; asked for here.
    (defun my/obsidian-setup-capf ()
      "Put vault completion in front of the generic text sources."
      (when (my/obsidian-maybe-enable)
        (setq-local completion-at-point-functions
                    (cons #'my/obsidian-capf completion-at-point-functions))))

    (add-hook 'markdown-mode-hook #'my/obsidian-setup-capf)

    ;;; ------------------------------------------------------------------
    ;;; Commands
    ;;; ------------------------------------------------------------------

    (defmacro my/obsidian-command (name docstring command)
      "Define NAME as an interactive COMMAND that loads the vault first."
      `(defun ,name ()
         ,docstring
         (interactive)
         (when (my/obsidian-ensure)
           (call-interactively #',command))))

    (my/obsidian-command my/obsidian-new
      "Create a note in the vault inbox." obsidian-capture)
    (my/obsidian-command my/obsidian-jump
      "Jump to a note by title or alias." obsidian-jump)
    (my/obsidian-command my/obsidian-daily-note
      "Open today's daily note, from the Daily template if it is new."
      obsidian-daily-note)
    (my/obsidian-command my/obsidian-find-tag
      "List the notes carrying a tag." obsidian-find-tag)
    (my/obsidian-command my/obsidian-insert-tag
      "Insert one of the vault's existing tags." obsidian-insert-tag)
    (my/obsidian-command my/obsidian-insert-wikilink
      "Insert a [[wiki link]] to a note." obsidian-insert-wikilink)
    (my/obsidian-command my/obsidian-insert-link
      "Insert a markdown link to a note." obsidian-insert-link)
    (my/obsidian-command my/obsidian-remove-link
      "Replace the link at point with its own text." obsidian-remove-link)
    (my/obsidian-command my/obsidian-follow-link
      "Follow the link at point, creating the note if it does not exist yet."
      obsidian-follow-link-at-point)
    (my/obsidian-command my/obsidian-jump-back
      "Return to where the last link was followed from." obsidian-jump-back)
    (my/obsidian-command my/obsidian-backlinks
      "Jump to one of the notes that link here." obsidian-backlink-jump)
    (my/obsidian-command my/obsidian-toggle-backlinks
      "Show or hide the side panel listing what links here."
      obsidian-toggle-backlinks-panel)
    (my/obsidian-command my/obsidian-move-note
      "Move this note into another vault folder, keeping its name."
      obsidian-move-file)
    (my/obsidian-command my/obsidian-rescan
      "Rebuild the vault index, after changes made outside Emacs."
      obsidian-rescan-cache)

    (defun my/obsidian-new-from-template ()
      "Create a note and fill it from one of the vault templates.
    obsidian.el has no command for this: `obsidian-apply-template' takes a file name
    and is not interactive, and the autoload this used to call --
    obsidian-insert-template -- does not exist in the package at all, so the
    template half silently did nothing.

    Only {{title}}, {{date}} and {{time}} are substituted. The vault's templates are
    Templater files, so any richer expression in one arrives in the note as written,
    to be filled in by the app."
      (interactive)
      (when (my/obsidian-ensure)
        (let* ((dir (expand-file-name obsidian-templates-directory obsidian-directory))
               (templates (and (file-directory-p dir)
                               (directory-files dir nil "\\.md\\'"))))
          (unless templates
            (user-error "No templates in %s" dir))
          (let ((template (completing-read "Template: " templates nil t)))
            (call-interactively #'obsidian-capture)
            (obsidian-apply-template (expand-file-name template dir))
            (save-buffer)))))

    ;; consult is required further down default.el, in the fuzzy-finding block,
    ;; so at runtime every command below resolves. The compiler reads top to
    ;; bottom, though, and that matters for one of them: without this
    ;; declaration `consult-ripgrep-args' is not yet known to be special, so the
    ;; `let' in my/obsidian-search would make a lexical binding that consult
    ;; never looks at -- and the exclusions would silently do nothing while the
    ;; code kept reading as though they worked.
    (defvar consult-ripgrep-args)
    (declare-function consult-fd "consult")
    (declare-function consult-ripgrep "consult")
    (declare-function consult-imenu "consult-imenu")

    ;; fd over the vault, not `obsidian-jump'. Jumping is the thing reached for
    ;; most often and it should not be the thing that pays for the index: this
    ;; answers immediately on a cold session, previews as you move down the list,
    ;; and reaches the PDFs and .base files in the vault that obsidian.el does
    ;; not consider notes at all. SPC n j is the title- and alias-aware version
    ;; for when that is what is wanted.
    (defun my/obsidian-open-note ()
      "Jump to a note by file name, previewed."
      (interactive)
      (consult-fd (my/obsidian-vault)))

    (defun my/obsidian--excluded-globs ()
      "Ripgrep --glob arguments matching `obsidian-excluded-directories'.
    Search skips whatever the index skips, so a query does not come back with three
    hits from the stale vault copies for every real one."
      (mapcar (lambda (dir)
                (format "--glob=!%s/**"
                        (directory-file-name
                         (file-relative-name dir obsidian-directory))))
              obsidian-excluded-directories))

    (defun my/obsidian-search (&optional all)
      "Search the vault text, previewed live.
    With a prefix argument ALL, search the excluded directories too.

    This replaces `obsidian-search', which greps the vault, reports a count, and
    then asks twice -- once for the file, once with no preview. ripgrep is live from
    the first character and jumps to the matching line."
      (interactive "P")
      (let* ((dir (my/obsidian-vault))
             (consult-ripgrep-args
              (if all
                  consult-ripgrep-args
                ;; A list, not a concatenated string. `consult--build-args'
                ;; splits string elements on whitespace, which would tear
                ;; "--glob=!Old backups/**" in half, and evaluates a non-string
                ;; element whole instead.
                (list consult-ripgrep-args
                      (list 'quote (my/obsidian--excluded-globs))))))
        (consult-ripgrep dir)))

    (defun my/obsidian-headings ()
      "Jump to a heading in this note."
      (interactive)
      (consult-imenu))

    ;; `system-type', not a nix interpolation of the two platforms' openers. An
    ;; interpolation splits the enclosing string into parts, and nix works out
    ;; the indentation to strip per part -- so one landing mid-line leaves this
    ;; whole section indented in the generated default.el, alone among all of
    ;; them. Emacs knows which platform it is on anyway.
    (defun my/obsidian-open-app ()
      "Open this note, or the vault, in the Obsidian app."
      (interactive)
      (let ((target (or (buffer-file-name) (my/obsidian-vault))))
        (if (eq system-type 'darwin)
            (call-process "/usr/bin/open" nil nil nil "-a" "Obsidian" target)
          (call-process "xdg-open" nil nil nil target))))

    ;; RET follows the link under the cursor, as it does in org. The rest of the
    ;; surface lives on the SPC n leader tree rather than in the mode map: this
    ;; is the one that has to be under a finger while reading.
    (with-eval-after-load 'markdown-mode
      (evil-define-key 'normal markdown-mode-map
        (kbd "RET") #'my/obsidian-follow-link))
  '';
}
