# Reading a book in Emacs, and staying in the same place as the reader

# nov.el renders an EPUB into an ordinary buffer, which is the whole point: the
# notes go in a window beside it, the text is searchable and yankable, and
# movement is the movement you already have. The X4 Pro is still the better
# device for actually reading; this is for the sessions where the book and the
# notes need to be next to each other.

# The two of them agree on position through kosync -- the same protocol
# KOReader syncs with, served from vulcan by features/services/reading. So
# this is a real client, not a viewer: it reads the position the reader left
# and writes back the one it leaves.

# Be clear about the granularity, because it is not the same in both
# directions. KOReader records an xpointer into the parsed document and can
# return to the exact line. Emacs cannot construct one of those, so it sends
# the chapter it is in plus the percentage through the book, and reads the
# same two back. Reader to reader stays exact; anything involving Emacs lands
# on the right chapter and close to the right place in it, not on the line.

# Highlights are deliberately absent. The X4 Pro's reader does not do them at
# all, so a highlight made here would sync to nothing and come back from
# nothing -- a quote filed into the book's note is the honest version of that
# feature.

# The note lives in the Obsidian vault, not beside the library. It is the same
# note the Book Reader plugin writes to when the book is open in Obsidian, so a
# book can be read in either app -- Emacs is always open, the vault is where
# notes get worked on -- and both add to one note under one Quotes heading.
# Position is shared with Book Reader as well, through the progress file it
# keeps in the vault: when a book opens here, whichever of the e-reader and
# Obsidian was read last is the position offered.

{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      nov
    ];

  programs.emacs.extraConfig = ''
    (require 'json)
    (require 'url-auth)
    (require 'nov nil t)
    (add-to-list 'auto-mode-alist (cons "\\.epub\\'" 'nov-mode))

    (defvar my/books-dir "${config.home.homeDirectory}/books"
      "Where the EPUBs live. The same tree calibre-web serves on vulcan.")

    (with-eval-after-load 'nov
      ;; Books are prose, not code: a fixed pitch and a full-width window are
      ;; both wrong for them.
      (setq nov-text-width 80)
      (add-hook 'nov-mode-hook #'visual-line-mode))

    ;;; ------------------------------------------------------------------
    ;;; Identifying a book the way KOReader does
    ;;;
    ;;; The sync key is not a filename. KOReader offers two ways to derive it and
    ;;; both readers have to be set the same way or they will sync happily and
    ;;; independently forever -- which is the usual reason this appears to work and
    ;;; does nothing.
    ;;;
    ;;; Binary is KOReader's default and the one implemented here: MD5 over twelve
    ;;; 1 KiB samples taken at exponentially spaced offsets, which survives the file
    ;;; being renamed. Filename mode is the fallback, and it is the one to switch
    ;;; both ends to if the two disagree -- it is trivially reproducible and it is
    ;;; also the only thing that works when the reader and the library hold copies
    ;;; that differ by so much as a byte.
    ;;;
    ;;; The offsets look odd because they are: KOReader's loop starts at i = -1 and
    ;;; shifts 1024 left by 2i, and on a 32-bit shift that first step wraps to zero.
    ;;; Sampling begins at the start of the file by accident, and the accident is
    ;;; part of the protocol now.

    (defcustom my/kosync-match-method 'binary
      "How to derive a book's sync key: `binary' or `filename'.
    Must match \"Document matching method\" in KOReader, on every device."
      :type '(choice (const binary) (const filename))
      :group 'my/kosync)

    (defconst my/kosync--sample-offsets
      (cons 0 (mapcar (lambda (i) (ash 1024 (* 2 i))) (number-sequence 0 10)))
      "Byte offsets KOReader samples when hashing a document.")

    (defun my/kosync-document-id (path)
      "The kosync document key for the book at PATH.
    `binary' hashes twelve 1 KiB samples of the file, concatenated in order,
    which is what KOReader does and what makes the key survive a rename.
    Each sample is appended rather than inserted with REPLACE, which would
    discard the previous ones and hash only the last."
      (if (eq my/kosync-match-method 'filename)
          (md5 (file-name-nondirectory path))
        (with-temp-buffer
          (set-buffer-multibyte nil)
          (dolist (offset my/kosync--sample-offsets)
            (goto-char (point-max))
            (insert-file-contents-literally path nil offset (+ offset 1024)))
          (md5 (current-buffer)))))

    ;;; ------------------------------------------------------------------
    ;;; Credentials
    ;;;
    ;;; KOReader MD5s the password once and then replays that digest as the
    ;;; credential on every request, so the digest is what has to be stored. It lives
    ;;; in a 0600 file outside this repository; nothing here is generated into the
    ;;; nix store, which is world-readable.
    ;;;
    ;;; ~my/kosync-setup~ is the whole account flow: it takes a username and a
    ;;; password, registers them with the server if the account is new, writes the
    ;;; file, and then asks the server whether the credential works. A server with
    ;;; registration closed refuses the first step and the rest still holds.
    ;;;
    ;;; The server has to be the one KOReader points at, or the two sides keep
    ;;; positions that never meet. There is one on vulcan, in
    ;;; features/services/reading, for the self-hosted arrangement.

    (defcustom my/kosync-url "https://sync.crosspointreader.com"
      "Base URL of the kosync server. Must match KOReader's own setting.
    Set it to \"http://vulcan.tail5ec262.ts.net:8087\" to use the self-hosted
    server instead -- plain HTTP is deliberate there, since the tailnet is
    already encrypted and KOReader on a device with no CA store is one more
    thing to go wrong."
      :type 'string
      :group 'my/kosync)

    (defun my/kosync--endpoint (path)
      "The full URL for PATH, tolerating a trailing slash on `my/kosync-url'.
    A server routing on the exact path answers \"//users/auth\" with a 404, which
    a client reads as no answer at all. KOReader's own settings box has the same
    edge and no such guard, so the URL entered there must not end in a slash."
      (concat (string-trim-right my/kosync-url "/+") path))

    (defvar my/kosync--credentials-file
      (expand-file-name "~/.config/kosync/credentials")
      "username:md5-of-password, 0600, deliberately outside the repository.")

    (defun my/kosync--credentials ()
      "Return (USERNAME . KEY), or nil when the account has not been set up."
      (when (file-readable-p my/kosync--credentials-file)
        (with-temp-buffer
          (insert-file-contents my/kosync--credentials-file)
          (let ((line (string-trim (buffer-string))))
            (when (string-match "\\`\\([^:]+\\):\\(.+\\)\\'" line)
              (cons (match-string 1 line) (match-string 2 line)))))))

    (defun my/kosync--request (method path &optional payload async)
      "Call the kosync server, returning the parsed body or nil.

    With ASYNC the request is fired and forgotten and the return value is nil.
    Background pushes use that: a synchronous request on an idle timer stalls
    the first keystroke after a pause when the server is slow or gone, and
    nothing reads the reply to a push anyway.

    `url-registered-auth-schemes' is bound to nil for the duration. url.el
    answers a 401 by prompting in the minibuffer for a username and password,
    which on a kill-buffer hook means Emacs stops dead asking about a service
    the user was not thinking about -- and the credential it wants is not one
    a human has anyway, since kosync authenticates with an MD5 digest. With no
    schemes registered the 401 raises instead, and the condition-case below
    turns it into nil."
      (let* ((credentials (my/kosync--credentials))
             (url-registered-auth-schemes nil)
             (url-request-method method)
             (url-request-extra-headers
              (append '(("Content-Type" . "application/json"))
                      (when credentials
                        (list (cons "x-auth-user" (car credentials))
                              (cons "x-auth-key" (cdr credentials))))))
             (url-request-data
              (when payload (encode-coding-string (json-encode payload) 'utf-8))))
        (when (and (not credentials) (not (equal path "/users/create")))
          (setq path nil))
        (condition-case err
            (cond
             ((not path) nil)
             (async
              ;; Errors reach the callback, not this stack frame, so it takes
              ;; its own handler -- otherwise a dead server prints a url.el
              ;; backtrace into the echo area from a timer.
              (url-retrieve (my/kosync--endpoint path)
                            (lambda (status &rest _)
                              (let ((failed (plist-get status :error)))
                                (kill-buffer (current-buffer))
                                (when failed (message "kosync: push failed"))))
                            nil t t)
              nil)
             (t
              ;; nil, not a signal, is how url-retrieve-synchronously reports a
              ;; connection it could not make -- and `with-current-buffer' on
              ;; nil then throws a "Wrong type argument: stringp, nil" that
              ;; says nothing about the server being down.
              (when-let* ((buffer (url-retrieve-synchronously
                                   (my/kosync--endpoint path) t t 15)))
                (with-current-buffer buffer
                  (goto-char (point-min))
                  (when (re-search-forward "^$" nil t)
                    (prog1 (ignore-errors (json-parse-buffer :object-type 'alist))
                      (kill-buffer)))))))
          (error (message "kosync: %s" (error-message-string err)) nil))))

    (defun my/kosync-setup (username password)
      "Register USERNAME with the kosync server and store the credential.

    This is a once-per-machine command, not part of syncing: `my/kosync-push'
    and `my/kosync-pull' read the credential from disk and never ask for it.
    An account already on disk is confirmed before anything is prompted for,
    so reaching this by accident costs one keystroke."
      (interactive
       (progn
         (when (and (my/kosync--credentials)
                    (not (yes-or-no-p
                          "kosync: an account is set up. Replace the credential? ")))
           (user-error "kosync: kept the credential already on disk"))
         (list (read-string "kosync username: ")
               (read-passwd "kosync password: " t))))
      (let* ((key (md5 password))
             (result (my/kosync--request "POST" "/users/create"
                                         (list (cons "username" username)
                                               (cons "password" key)))))
        (make-directory (file-name-directory my/kosync--credentials-file) t)
        (with-temp-file my/kosync--credentials-file
          (insert username ":" key "\n"))
        (set-file-modes my/kosync--credentials-file #o600)
        ;; An existing account, or a server that refuses registration, is the
        ;; expected outcome on the second device; the credential file is what
        ;; this command is for. Only /users/auth says whether it is any good.
        (let ((authorized (alist-get 'authorized
                                     (my/kosync--request "GET" "/users/auth"))))
          (message "kosync: %s; %s"
                   (cond ((alist-get 'username result) "account created")
                         ((alist-get 'message result) (alist-get 'message result))
                         (t "server did not answer the registration"))
                   (if authorized
                       "credential works"
                     "credential REJECTED -- wrong password, or wrong server")))))

    ;;; ------------------------------------------------------------------
    ;;; Position, in both directions
    ;;;
    ;;; A percentage through the book needs the chapters weighted by length, or
    ;;; chapter nine of a hundred pages and chapter nine of three both read as the
    ;;; same fraction. nov keeps the spine as a vector of file paths, so the weights
    ;;; are just their sizes -- which is close enough to how crengine computes its
    ;;; own percentage for the two to agree to within a page.
    ;;;
    ;;; The xpointer sent alongside it is chapter-granular: crengine numbers
    ;;; DocFragments in spine order, so DocFragment[N] is the Nth spine item and
    ;;; KOReader will open the right chapter from it. It will not open the right
    ;;; line, and that is the limit described at the top.

    (defun my/nov--weights ()
      "Byte size of each spine document, as a vector."
      (let ((sizes (make-vector (length nov-documents) 1)))
        (dotimes (i (length nov-documents))
          (let ((path (cdr (aref nov-documents i))))
            (aset sizes i (max 1 (or (ignore-errors
                                       (file-attribute-size
                                        (file-attributes path)))
                                     1)))))
        sizes))

    (defun my/nov-percentage ()
      "How far through the whole book point is, as a float in [0, 1]."
      (let* ((sizes (my/nov--weights))
             (total (float (apply #'+ (append sizes nil))))
             (before (apply #'+ (append (substring sizes 0 nov-documents-index) nil)))
             (within (if (> (point-max) 1)
                         (/ (float (1- (point))) (float (1- (point-max))))
                       0.0)))
        (min 1.0 (/ (+ before (* within (aref sizes nov-documents-index))) total))))

    (defun my/nov-goto-percentage (fraction)
      "Move to FRACTION through the whole book."
      (let* ((sizes (my/nov--weights))
             (total (float (apply #'+ (append sizes nil))))
             (target (* (max 0.0 (min 1.0 fraction)) total))
             (index 0)
             (accumulated 0.0))
        (while (and (< index (1- (length sizes)))
                    (>= target (+ accumulated (aref sizes index))))
          (setq accumulated (+ accumulated (aref sizes index)))
          (setq index (1+ index)))
        (unless (equal index nov-documents-index)
          (nov-goto-document index))
        (goto-char (+ (point-min)
                      (round (* (/ (- target accumulated) (aref sizes index))
                                (- (point-max) (point-min))))))
        ;; Only when the book is on screen: the jump on opening runs from a
        ;; timer, and `recenter' signals if the selected window shows anything
        ;; else by then.
        (when (eq (window-buffer) (current-buffer))
          (recenter))))

    (defun my/nov--xpointer ()
      "A chapter-granular xpointer KOReader will accept."
      (format "/body/DocFragment[%d]/body/p[1]" (1+ nov-documents-index)))

    (defun my/nov--chapter-from-xpointer (xpointer)
      "The zero-based spine index XPOINTER refers to, or nil."
      (when (and (stringp xpointer)
                 (string-match "DocFragment\\[\\([0-9]+\\)\\]" xpointer))
        (1- (string-to-number (match-string 1 xpointer)))))

    ;;; ------------------------------------------------------------------
    ;;; Push and pull
    ;;;
    ;;; Both directions are automatic; the difference is what happens when they
    ;;; disagree.
    ;;;
    ;;; Pushing needs no judgement, so it just happens: thirty seconds after you
    ;;; stop moving, when Emacs loses focus -- which is exactly the moment you
    ;;; pick the reader up -- when the buffer is killed, and when Emacs quits.
    ;;; Only if the position actually moved since the last push, so an idle book
    ;;; sends nothing.
    ;;;
    ;;; Background pushes are fired and forgotten. A synchronous request on an
    ;;; idle timer would stall the first keystroke after a pause if the server
    ;;; were slow or gone, and nothing here reads the reply.
    ;;;
    ;;; Pulling is where the judgement is, because it moves you. At the start of
    ;;; a book there is nothing to lose and it jumps; otherwise it asks, naming
    ;;; both positions, the way KOReader does. Silently overwriting where
    ;;; somebody is reading is the one thing a sync client must never do.

    (defcustom my/kosync-auto-pull 'ask
      "What to do when the server has a different position on opening a book.
    `ask' prompts unless you are at the very start; `always' jumps without
    asking; `never' only reports it and leaves the jump to SPC R p."
      :type '(choice (const ask) (const always) (const never))
      :group 'my/kosync)

    (defvar-local my/kosync--last-synced nil
      "Percentage last sent for this buffer.
    An idle tick on a book nobody moved should not become a request.")

    (defvar-local my/book--obsidian-saved nil
      "Percentage last written to Book Reader's progress file for this buffer.
    Kept apart from `my/kosync--last-synced': the two are saved on the same
    occasions but either can fail without the other.")

    (defun my/kosync--document ()
      "The sync key for the book in the current buffer, or nil."
      (when (and (derived-mode-p 'nov-mode) nov-file-name)
        (my/kosync-document-id nov-file-name)))

    (defun my/kosync-push (&optional quietly)
      "Send this book's position to the server.
    Run by hand, it saves the position for Book Reader as well; the automatic
    path does that itself, in `my/kosync--push-if-moved'."
      (interactive)
      (when (called-interactively-p 'interactive)
        (my/book--obsidian-save))
      (let ((document (my/kosync--document)))
        (cond
         ((not document) (unless quietly (message "Not reading a book.")))
         ((not (my/kosync--credentials))
          (unless quietly (message "kosync: no account -- run my/kosync-setup.")))
         (t
          (let ((percentage (my/nov-percentage)))
            (my/kosync--request
             "PUT" "/syncs/progress"
             (list (cons "document" document)
                   (cons "progress" (my/nov--xpointer))
                   (cons "percentage" percentage)
                   (cons "device" "Emacs")
                   (cons "device_id" (md5 (system-name))))
             quietly)
            (setq my/kosync--last-synced percentage)
            (unless quietly
              (message "kosync: pushed %.1f%%" (* 100 percentage))))))))

    (defun my/kosync--apply (state)
      "Move to the position in STATE and return its percentage."
      (let ((chapter (my/nov--chapter-from-xpointer (alist-get 'progress state)))
            (percentage (alist-get 'percentage state)))
        (my/nov-goto-percentage percentage)
        ;; When the two disagree, the xpointer wins: it came from the reader
        ;; verbatim and names the chapter exactly, where the percentage only
        ;; approximates it.
        (when (and chapter (< chapter (length nov-documents))
                   (not (equal chapter nov-documents-index)))
          (nov-goto-document chapter))
        ;; Record where we landed, not where the server said, or the next idle
        ;; tick pushes the rounding error straight back -- to both places.
        (setq my/kosync--last-synced (my/nov-percentage)
              my/book--obsidian-saved my/kosync--last-synced)
        percentage))

    (defun my/kosync-pull ()
      "Jump to the newest position recorded for this book.
    That is the newer of the kosync server's, which the e-reader writes, and
    Book Reader's, which Obsidian writes."
      (interactive)
      (let ((state (and (derived-mode-p 'nov-mode) (my/book--latest-state))))
        (cond
         ((not (derived-mode-p 'nov-mode)) (message "Not reading a book."))
         ((not (alist-get 'percentage state)) (message "Nothing recorded yet for this book."))
         (t (message "%.1f%% from %s"
                     (* 100 (my/kosync--apply state))
                     (or (alist-get 'device state) "elsewhere"))))))

    (defun my/kosync--on-open ()
      "Reconcile with the newest known position just after a book finishes opening.

    Deferred rather than run straight from the mode hook: nov is still building
    the buffer at that point, so jumping would land in a document about to be
    replaced -- and a prompt would appear before the book had drawn.

    Newest of two places: the kosync server, which the e-reader writes, and
    Book Reader's progress file, which Obsidian writes."
      (let ((buffer (current-buffer)))
        (run-at-time
         0.5 nil
         (lambda ()
           (when (buffer-live-p buffer)
             (with-current-buffer buffer
               (when-let* ((state (my/book--latest-state))
                           (remote (alist-get 'percentage state)))
                 (let ((local (my/nov-percentage))
                       (device (or (alist-get 'device state) "another device")))
                   (setq my/kosync--last-synced local
                         my/book--obsidian-saved local)
                   (cond
                    ((< (abs (- remote local)) 0.001) nil)
                    ((eq my/kosync-auto-pull 'never)
                     (message "%s left off at %.1f%% -- SPC R p to go there"
                              device (* 100 remote)))
                    ;; Nothing to lose at the very start of the book.
                    ((or (eq my/kosync-auto-pull 'always) (< local 0.001))
                     (message "%.1f%% from %s"
                              (* 100 (my/kosync--apply state)) device))
                    ((y-or-n-p
                      (format "%s left off at %.1f%%, you are at %.1f%%. Go there? "
                              device (* 100 remote) (* 100 local)))
                     (my/kosync--apply state)))))))))))

    (defun my/kosync--push-if-moved ()
      "Push the current buffer, but only if the position actually changed.
    Book Reader's copy is saved on the same occasions -- idle, focus lost,
    buffer killed, Emacs quit -- and judged separately, since it needs no kosync
    account and a push that failed should not hold it back."
      (when (derived-mode-p 'nov-mode)
        (my/book--obsidian-save-if-moved)
        (let ((percentage (my/nov-percentage)))
          (unless (and my/kosync--last-synced
                       (< (abs (- percentage my/kosync--last-synced)) 0.0005))
            (my/kosync-push t)))))

    (defun my/kosync--push-every-book ()
      "Push every open book that has moved.
    On kill-emacs, and when Emacs loses focus, the current buffer is whichever
    one happened to be selected -- usually not the one being read."
      (dolist (buffer (buffer-list))
        (with-current-buffer buffer
          (my/kosync--push-if-moved))))

    (defun my/kosync--on-focus-change ()
      "Push on the way out to another app, which is when you pick the reader up."
      (unless (frame-focus-state)
        (my/kosync--push-every-book)))

    (defvar my/kosync--idle-timer nil
      "Guarded so reloading this configuration does not stack up timers.")

    (unless my/kosync--idle-timer
      (setq my/kosync--idle-timer
            (run-with-idle-timer 30 t #'my/kosync--push-if-moved)))

    (add-hook 'nov-mode-hook #'my/kosync--on-open)
    (add-hook 'kill-buffer-hook #'my/kosync--push-if-moved)
    (add-hook 'kill-emacs-hook #'my/kosync--push-every-book)
    (add-function :after after-focus-change-function #'my/kosync--on-focus-change)

    ;;; ------------------------------------------------------------------
    ;;; The book's note, in the vault
    ;;;
    ;;; One markdown note per book, in the Obsidian vault rather than beside the
    ;;; library, because that is where the reading pipeline is: a book's note
    ;;; starts in Inbox from the Book template, like every other source, and is
    ;;; worked on from there. It is the same note the Book Reader plugin uses when
    ;;; the book is open in Obsidian, found the way the plugin finds it:
    ;;;
    ;;; 1. the note Book Reader has linked to the book, when the book is in the
    ;;;    vault;
    ;;; 2. any note whose `book' property -- or Annotator's `annotation-target' --
    ;;;    names the book;
    ;;; 3. otherwise a new one in Inbox, named the way Book Reader names one, so
    ;;;    whichever app gets there first, the other finds it.
    ;;;
    ;;; ~SPC R n~ opens it in a split to the right. ~SPC R c~ quotes the region --
    ;;; or the line point is on -- into it, with the percentage it came from; with
    ;;; a prefix argument it asks for a comment to go under the quote.
    ;;;
    ;;; Quotes go where Book Reader puts its own: appended to the very end of the
    ;;; note, under a "## Quotes" heading added the first time. The plugin
    ;;; appends at the end whether or not that heading is the last one, so it has
    ;;; to stay the last section -- which is why the Book template ends with it.

    (require 'dom)
    (defvar obsidian-directory)

    (defgroup my/books nil
      "Reading books in Emacs alongside the Obsidian vault."
      :group 'applications)

    (defcustom my/book-notes-folder "Inbox"
      "Vault folder new book notes are created in.
    The vault's pipeline sends every source to Inbox first, and so does Book
    Reader while its own book-notes folder is left empty."
      :type 'string
      :group 'my/books)

    (defcustom my/book-note-template "000 Meta/Templates/Book.md"
      "Vault-relative template for a new book note -- the one Book Reader uses."
      :type 'string
      :group 'my/books)

    (defconst my/book--reader-data ".obsidian/plugins/elton-reader-books/data.json"
      "Book Reader's saved settings, relative to the vault.")

    (defun my/book--vault ()
      "The vault directory, with a trailing slash."
      (file-name-as-directory
       (expand-file-name (or (bound-and-true-p obsidian-directory)
                             "~/Documents/robertogoam"))))

    (defun my/book--vault-path (file)
      "FILE relative to the vault, or nil when it lives outside it."
      (let ((vault (my/book--vault))
            (path (expand-file-name file)))
        (when (string-prefix-p vault path)
          (substring path (length vault)))))

    (defun my/book--hidden-p (directory)
      "Non-nil for dot-directories: .obsidian, .trash, .git."
      (string-prefix-p "." (file-name-nondirectory (directory-file-name directory))))

    (defun my/book--vault-files (regexp)
      "Every file in the vault matching REGEXP, outside hidden directories."
      (directory-files-recursively
       (my/book--vault) regexp nil
       (lambda (directory) (not (my/book--hidden-p directory)))))

    (defun my/book--read-json (file)
      "FILE parsed as JSON with objects as hash tables.
    nil when FILE is missing; the symbol `unreadable' when it is there but does
    not parse, so a caller about to rewrite it can tell the two apart."
      (when (file-exists-p file)
        (condition-case nil
            (with-temp-buffer
              (insert-file-contents file)
              (json-parse-buffer :object-type 'hash-table))
          (error 'unreadable))))

    (defun my/book--reader-setting (key)
      "Book Reader's setting KEY, or nil when blank or the plugin is absent."
      (let* ((data (my/book--read-json
                    (expand-file-name my/book--reader-data (my/book--vault))))
             (settings (and (hash-table-p data) (gethash "settings" data)))
             (value (and (hash-table-p settings) (gethash key settings))))
        (unless (or (memq value '(nil :null :false)) (equal value ""))
          value)))

    (defun my/book--note-target (note)
      "The book NOTE points at, from its `book' or `annotation-target' property."
      (with-temp-buffer
        (insert-file-contents note nil 0 4096)
        (goto-char (point-min))
        (when (looking-at "---[ \t]*$")
          (forward-line 1)
          (let ((start (point))
                (end (and (re-search-forward "^---[ \t]*$" nil t) (point))))
            (goto-char start)
            (when (and end (re-search-forward
                            "^\\(?:book\\|annotation-target\\):[ \t]*\\(.+\\)$" end t))
              (let* ((value (string-trim (match-string 1)))
                     (value (string-trim value "[\"']+" "[\"']+"))
                     (value (string-trim value "\\[\\[" "\\]\\]")))
                (car (split-string value "|"))))))))

    (defun my/book--names (book)
      "The ways a note's `book' property may name BOOK.
    Book Reader writes the vault path and also accepts the bare file name;
    a book outside the vault can only be named by where it is."
      (let ((relative (my/book--vault-path book))
            (absolute (expand-file-name book)))
        (delq nil (list relative
                        (and relative (file-name-sans-extension
                                       (file-name-nondirectory book)))
                        (file-name-nondirectory book)
                        (abbreviate-file-name absolute)
                        absolute))))

    (defun my/book--note-title (book)
      "What a new note for BOOK is called.
    A book in the vault is named after its file, as Book Reader names it, so
    both apps land on one note. A book from ~/books usually carries a long
    catalogue filename, so its own metadata title is used instead."
      (let ((title (or (and (not (my/book--vault-path book))
                            (derived-mode-p 'nov-mode)
                            (equal (expand-file-name book)
                                   (expand-file-name nov-file-name))
                            (alist-get 'title nov-metadata))
                       (car (split-string (file-name-base book) " -- ")))))
        (string-trim
         (replace-regexp-in-string
          " +" " " (replace-regexp-in-string "[]\\/:*?\"<>|#^[]" " " title)))))

    (defun my/book--linked-note (book)
      "The note Book Reader has linked to BOOK, if there is one."
      (when-let* ((relative (my/book--vault-path book))
                  (links (my/book--reader-setting "bookNoteLinks"))
                  ((hash-table-p links))
                  (name (gethash relative links))
                  ((stringp name)))
        (let* ((name (string-trim name "\\[\\[" "\\]\\]"))
               (preferred (expand-file-name
                           (concat my/book-notes-folder "/" name ".md")
                           (my/book--vault))))
          (if (file-exists-p preferred)
              preferred
            (seq-find (lambda (note) (equal (file-name-base note) name))
                      (my/book--vault-files "\\.md\\'"))))))

    (defun my/book-note-file (&optional book)
      "The vault note for BOOK, defaulting to the one being read.
    It may not exist yet; `my/book--ensure-note' creates it."
      (let* ((book (or book
                       (and (derived-mode-p 'nov-mode) nov-file-name)
                       (user-error "Not reading a book")))
             (names (my/book--names book)))
        (or (my/book--linked-note book)
            (seq-find (lambda (note) (member (my/book--note-target note) names))
                      (my/book--vault-files "\\.md\\'"))
            (expand-file-name
             (concat my/book-notes-folder "/" (my/book--note-title book) ".md")
             (my/book--vault)))))

    (defun my/book--template (title)
      "The Book template filled in for TITLE.
    Only the Templater calls the template uses are evaluated -- the title and
    today's date -- and any other <% %> is dropped. That is exactly what Book
    Reader does when it creates a book note, so the two produce the same note."
      (let ((file (expand-file-name my/book-note-template (my/book--vault)))
            (today (format-time-string "%Y-%m-%d")))
        (if (not (file-readable-p file))
            (format "# %s\n" title)
          (let ((text (with-temp-buffer
                        (insert-file-contents file)
                        (buffer-string))))
            (setq text (replace-regexp-in-string
                        "<%[-_]?[ \t]*tp\\.file\\.title[ \t]*[-_]?%>" title text t t))
            (setq text (replace-regexp-in-string
                        "<%[-_]?[ \t]*tp\\.date\\.now([^)]*)[ \t]*[-_]?%>" today text t t))
            (replace-regexp-in-string "<%\\(?:.\\|\n\\)*?%>" "" text t t)))))

    (defun my/book--set-property (key value)
      "Set KEY to VALUE in this buffer's frontmatter, adding one if there is none."
      (save-excursion
        (goto-char (point-min))
        (let ((line (format "%s: \"%s\"" key
                            (replace-regexp-in-string "\"" "\\\\\"" value))))
          (if (not (looking-at "---[ \t]*$"))
              (insert "---\n" line "\n---\n\n")
            (forward-line 1)
            (let ((end (save-excursion
                         (and (re-search-forward "^---[ \t]*$" nil t)
                              (match-beginning 0)))))
              (cond
               ((not end) (insert line "\n"))
               ((re-search-forward (format "^%s:.*$" (regexp-quote key)) end t)
                (replace-match line t t))
               (t (goto-char end)
                  (insert line "\n"))))))))

    (defun my/book--ensure-note (book)
      "The note for BOOK, created from the Book template if it is new.
    The `book' property it gets is the one Book Reader writes -- a link to the
    vault path -- or, for a book outside the vault, where the file is."
      (let ((file (my/book-note-file book)))
        (unless (file-exists-p file)
          (make-directory (file-name-directory file) t)
          (let ((relative (my/book--vault-path book))
                (coding-system-for-write 'utf-8-unix))
            (with-temp-file file
              (insert (my/book--template (file-name-base file)))
              (my/book--set-property
               "book" (if relative
                          (format "[[%s]]" relative)
                        (abbreviate-file-name (expand-file-name book)))))))
        file))

    (defun my/book--note-buffer (note)
      "A buffer visiting NOTE, re-read first if Obsidian changed it meanwhile."
      (let ((buffer (find-file-noselect note)))
        (with-current-buffer buffer
          (unless (or (buffer-modified-p) (verify-visited-file-modtime buffer))
            (revert-buffer t t t)))
        buffer))

    (defun my/book-notes ()
      "Open this book's note from the vault in a window to the right."
      (interactive)
      (unless (derived-mode-p 'nov-mode)
        (user-error "Not reading a book"))
      (let ((buffer (my/book--note-buffer (my/book--ensure-note nov-file-name))))
        (display-buffer buffer '(display-buffer-in-side-window
                                 (side . right) (window-width . 0.4)))
        buffer))

    (defun my/book--label-p (text book-title)
      "Non-nil when TEXT says something a reader would recognise.
    Not blank, not the book's own title, and not a generated name: plenty of
    EPUBs title their documents \"part0004\" or \"Page 76\", or head a chapter
    with its number alone."
      (and text
           (not (string-empty-p text))
           (not (and book-title (string-equal-ignore-case text book-title)))
           (not (let ((case-fold-search t))
                  (string-match-p
                   "\\`\\(?:part\\|page\\|split\\|section\\|text\\|index\\|ch\\)?[-_ ]*[0-9]+\\'"
                   text)))))

    (defun my/book--chapter ()
      "A label for the part of the book point is in, or nil.
    The current spine document's <title>, else its first h1-h3, whichever
    passes `my/book--label-p'. Books are not consistent about any of these, so
    this is a label, not an address -- the percentage beside the quote is what
    finds the place again."
      ;; Both are read before the temporary buffer is entered: they are local
      ;; to the book's buffer.
      (let ((document (ignore-errors (cdr (aref nov-documents nov-documents-index))))
            (book-title (alist-get 'title nov-metadata)))
        (when document
          (ignore-errors
            (with-temp-buffer
              (insert-file-contents document)
              (let ((dom (libxml-parse-html-region (point-min) (point-max))))
                (seq-some
                 (lambda (tag)
                   (when-let* ((node (car (dom-by-tag dom tag)))
                               (text (string-trim
                                      (replace-regexp-in-string
                                       "[ \t\n]+" " " (dom-inner-text node))))
                               ((my/book--label-p text book-title)))
                     text))
                 '(title h1 h2 h3))))))))

    (defun my/book--append-quote (note text where &optional chapter comment)
      "Append TEXT to NOTE under its Quotes heading, the way Book Reader does.
    WHERE follows the quote on its line; CHAPTER, when given, goes above it in
    bold, and COMMENT below it, inside the same blockquote."
      (with-current-buffer (my/book--note-buffer note)
        (save-excursion
          (save-restriction
            (widen)
            (let ((has-heading (save-excursion
                                 (goto-char (point-min))
                                 (re-search-forward "^## Quotes[ \t]*$" nil t))))
              (goto-char (point-max))
              (skip-chars-backward " \t\n")
              (delete-region (point) (point-max))
              (insert "\n\n")
              (unless has-heading
                (insert "## Quotes\n\n"))
              (when chapter
                (insert "**" chapter "**\n\n"))
              (insert "> " text where)
              (when comment
                (insert "\n>\n> — " (replace-regexp-in-string "\n" "\n> " comment)))
              (insert "\n"))))
        (save-buffer)))

    (defun my/book-note-capture (beginning end &optional comment)
      "Quote the region -- or this line -- into the book's note in the vault.
    With a prefix argument, ask for a COMMENT to file under the quote."
      (interactive
       (list (if (use-region-p) (region-beginning) (line-beginning-position))
             (if (use-region-p) (region-end) (line-end-position))
             (and current-prefix-arg (read-string "Comment: "))))
      (unless (derived-mode-p 'nov-mode)
        (user-error "Not reading a book"))
      (let ((text (string-trim
                   (replace-regexp-in-string
                    "[ \t\n]+" " " (buffer-substring-no-properties beginning end))))
            (percentage (* 100 (my/nov-percentage))))
        (when (string-empty-p text)
          (user-error "Nothing to note on this line"))
        (my/book--append-quote (my/book--ensure-note nov-file-name)
                               text
                               (format " *(%.1f%%)*" percentage)
                               (my/book--chapter)
                               (and comment (not (string-empty-p comment)) comment))
        (my/book-notes)
        (deactivate-mark)
        (message "Noted at %.1f%%" percentage)))

    ;;; ------------------------------------------------------------------
    ;;; Position, shared with Book Reader
    ;;;
    ;;; Book Reader keeps every book's position in reading-progress.json, in the
    ;;; vault, keyed by the book's vault path: a fraction through the book, the
    ;;; time it was saved in milliseconds, and the index of the paragraph it was
    ;;; on. Emacs has no way to name that paragraph, so it writes the fraction and
    ;;; the time and leaves the index out -- the case the plugin already handles,
    ;;; by opening at the fraction instead. Same granularity as kosync: the right
    ;;; neighbourhood, not the line.
    ;;;
    ;;; Only books inside the vault take part; Obsidian cannot open the others.
    ;;; The file holds every book's position, so it is replaced whole through a
    ;;; temporary file and left alone entirely if it does not parse.
    ;;;
    ;;; One race is out of reach from here: Book Reader holds the file in memory
    ;;; while a book is open and writes all of it back, so a position saved in
    ;;; Emacs while Obsidian has another book open can be overwritten with the
    ;;; older one. kosync keeps its own copy, and opening the book takes whichever
    ;;; of the two is newer.

    (defun my/book--progress-file ()
      "Book Reader's reading-progress.json, or nil when the plugin is absent.
    It sits in the plugin's data folder, else its books folder, else the vault
    root -- the order the plugin itself uses."
      (let ((vault (my/book--vault)))
        (when (file-exists-p (expand-file-name my/book--reader-data vault))
          (let ((folder (seq-find #'stringp
                                  (list (my/book--reader-setting "dataFolder")
                                        (my/book--reader-setting "booksFolder")))))
            (expand-file-name "reading-progress.json"
                              (if folder (expand-file-name folder vault) vault))))))

    (defun my/book--obsidian-state (book)
      "Where Book Reader left BOOK, shaped like a kosync reply, or nil."
      (when-let* ((relative (my/book--vault-path book))
                  (file (my/book--progress-file))
                  (data (my/book--read-json file))
                  ((hash-table-p data))
                  (entry (gethash relative data))
                  ((hash-table-p entry))
                  (fraction (gethash "pct" entry))
                  ((numberp fraction)))
        (let ((saved (gethash "lastRead" entry)))
          (list (cons 'percentage (float fraction))
                (cons 'timestamp (if (numberp saved) (/ saved 1000.0) 0))
                (cons 'device "Obsidian")))))

    (defun my/book--obsidian-save (&optional book fraction)
      "Record FRACTION through BOOK in Book Reader's progress file.
    Both default to the book being read and where point is in it."
      (when-let* ((book (or book (and (derived-mode-p 'nov-mode) nov-file-name)))
                  (relative (my/book--vault-path book))
                  (file (my/book--progress-file)))
        (let ((fraction (or fraction (my/nov-percentage)))
              (data (my/book--read-json file))
              (entry (make-hash-table :test 'equal)))
          (if (eq data 'unreadable)
              (message "Book Reader's progress file does not parse; position not saved")
            (unless (hash-table-p data)
              (setq data (make-hash-table :test 'equal)))
            (puthash "pct" fraction entry)
            (puthash "percent" (round (* 100 fraction)) entry)
            (puthash "lastRead" (truncate (* 1000 (float-time))) entry)
            (puthash relative entry data)
            (make-directory (file-name-directory file) t)
            (let ((temporary (make-temp-file
                              (expand-file-name ".reading-progress"
                                                (file-name-directory file))
                              nil ".json"))
                  (coding-system-for-write 'utf-8-unix))
              (with-temp-file temporary
                (insert (json-serialize data)))
              (rename-file temporary file t))
            (setq my/book--obsidian-saved fraction)))))

    (defun my/book--obsidian-save-if-moved ()
      "Save this buffer's position for Book Reader if it moved since last time."
      (when (and (derived-mode-p 'nov-mode)
                 nov-file-name
                 (my/book--vault-path nov-file-name))
        (let ((fraction (my/nov-percentage)))
          (unless (and my/book--obsidian-saved
                       (< (abs (- fraction my/book--obsidian-saved)) 0.0005))
            (my/book--obsidian-save nov-file-name fraction)))))

    (defun my/book--newest-state (&rest states)
      "Whichever of STATES was recorded last.
    A state with no time, which a kosync server may send, counts as oldest."
      (car (sort (seq-filter (lambda (state) (alist-get 'percentage state)) states)
                 (lambda (a b) (> (or (alist-get 'timestamp a) 0)
                                  (or (alist-get 'timestamp b) 0))))))

    (defun my/book--latest-state ()
      "The newest position recorded elsewhere for the book being read, or nil."
      (let ((document (my/kosync--document)))
        (my/book--newest-state
         (and document (my/kosync--request "GET" (concat "/syncs/progress/" document)))
         (and nov-file-name (my/book--obsidian-state nov-file-name)))))

    ;;; ------------------------------------------------------------------
    ;;; Opening a book

    (defun my/book--library ()
      "Every EPUB in ~/books and in the vault, as (LABEL . PATH)."
      (append
       (mapcar (lambda (file) (cons (concat "vault/" (my/book--vault-path file)) file))
               (my/book--vault-files "\\.epub\\'"))
       (when (file-directory-p my/books-dir)
         (mapcar (lambda (file)
                   (cons (concat "books/" (file-relative-name file my/books-dir)) file))
                 (directory-files-recursively
                  my/books-dir "\\.epub\\'" nil
                  (lambda (directory) (not (my/book--hidden-p directory))))))))

    (defun my/book-open ()
      "Open a book from ~/books or from the vault.
    Books in the vault can be read in Obsidian too; the rest only here and on
    the e-reader."
      (interactive)
      (let ((books (my/book--library)))
        (unless books
          (user-error "No books in %s or the vault" my/books-dir))
        (find-file (cdr (assoc (completing-read "Book: " books nil t) books)))))

    (defun my/book-library ()
      "Browse the library the reader and calibre-web both serve."
      (interactive)
      (make-directory my/books-dir t)
      (dired my/books-dir))
  '';
}
