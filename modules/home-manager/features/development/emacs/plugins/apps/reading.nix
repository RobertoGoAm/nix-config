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
# nothing -- the notes file below is the honest version of that feature.

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

    (defvar my/book-notes-dir "${config.home.homeDirectory}/books/notes"
      "One org file per book, beside the library rather than inside it, so
    calibre does not try to import them as documents.")

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
    ;;; password, registers them with the server if the account is new, and writes
    ;;; the file. Registration is open on the server only until the accounts exist --
    ;;; close it in features/services/reading afterwards.

    (defcustom my/kosync-url "http://vulcan.tail5ec262.ts.net:8087"
      "Base URL of the kosync server.
    Plain HTTP on purpose: the tailnet is already encrypted, and KOReader on a
    device with no CA store is one more thing to go wrong."
      :type 'string
      :group 'my/kosync)

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
              (url-retrieve (concat my/kosync-url path)
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
                                   (concat my/kosync-url path) t t 15)))
                (with-current-buffer buffer
                  (goto-char (point-min))
                  (when (re-search-forward "^$" nil t)
                    (prog1 (ignore-errors (json-parse-buffer :object-type 'alist))
                      (kill-buffer)))))))
          (error (message "kosync: %s" (error-message-string err)) nil))))

    (defun my/kosync-setup (username password)
      "Register USERNAME with the kosync server and store the credential."
      (interactive (list (read-string "kosync username: ")
                         (read-passwd "kosync password: " t)))
      (let* ((key (md5 password))
             (result (my/kosync--request "POST" "/users/create"
                                         (list (cons "username" username)
                                               (cons "password" key)))))
        (make-directory (file-name-directory my/kosync--credentials-file) t)
        (with-temp-file my/kosync--credentials-file
          (insert username ":" key "\n"))
        (set-file-modes my/kosync--credentials-file #o600)
        ;; An existing account is the expected outcome on the second device,
        ;; not a failure -- the credential file is what this command is really
        ;; for, and it has just been written either way.
        (message "kosync: %s"
                 (cond ((alist-get 'username result) "account created")
                       ((alist-get 'message result) (alist-get 'message result))
                       (t "credential saved; server did not answer")))))

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
        (recenter)))

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

    (defun my/kosync--document ()
      "The sync key for the book in the current buffer, or nil."
      (when (and (derived-mode-p 'nov-mode) nov-file-name)
        (my/kosync-document-id nov-file-name)))

    (defun my/kosync-push (&optional quietly)
      "Send this book's position to the server."
      (interactive)
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
        ;; tick pushes the rounding error straight back.
        (setq my/kosync--last-synced (my/nov-percentage))
        percentage))

    (defun my/kosync-pull ()
      "Jump to the position the server has for this book."
      (interactive)
      (let* ((document (my/kosync--document))
             (state (and document
                         (my/kosync--request
                          "GET" (concat "/syncs/progress/" document)))))
        (cond
         ((not document) (message "Not reading a book."))
         ((not (alist-get 'percentage state)) (message "kosync: nothing recorded yet."))
         (t (message "kosync: %.1f%% from %s"
                     (* 100 (my/kosync--apply state))
                     (or (alist-get 'device state) "elsewhere"))))))

    (defun my/kosync--on-open ()
      "Reconcile with the server just after a book finishes opening.

    Deferred rather than run straight from the mode hook: nov is still building
    the buffer at that point, so jumping would land in a document about to be
    replaced -- and a prompt would appear before the book had drawn."
      (let ((buffer (current-buffer)))
        (run-at-time
         0.5 nil
         (lambda ()
           (when (buffer-live-p buffer)
             (with-current-buffer buffer
               (when-let* ((document (my/kosync--document))
                           (state (my/kosync--request
                                   "GET" (concat "/syncs/progress/" document)))
                           (remote (alist-get 'percentage state)))
                 (let ((local (my/nov-percentage))
                       (device (or (alist-get 'device state) "another device")))
                   (setq my/kosync--last-synced local)
                   (cond
                    ((< (abs (- remote local)) 0.001) nil)
                    ((eq my/kosync-auto-pull 'never)
                     (message "kosync: %s left off at %.1f%% -- SPC R p to go there"
                              device (* 100 remote)))
                    ;; Nothing to lose at the very start of the book.
                    ((or (eq my/kosync-auto-pull 'always) (< local 0.001))
                     (message "kosync: %.1f%% from %s"
                              (* 100 (my/kosync--apply state)) device))
                    ((y-or-n-p
                      (format "%s left off at %.1f%%, you are at %.1f%%. Go there? "
                              device (* 100 remote) (* 100 local)))
                     (my/kosync--apply state)))))))))))

    (defun my/kosync--push-if-moved ()
      "Push the current buffer, but only if the position actually changed."
      (when (derived-mode-p 'nov-mode)
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
    ;;; The notes window
    ;;;
    ;;; One org file per book, opened in a split to the right, with the book's title
    ;;; as the heading. ~SPC R n~ from inside a book opens it; from anywhere else it
    ;;; asks which book.
    ;;;
    ;;; The capture command is the one that gets used: it takes the region -- or the
    ;;; line point is on -- and files it under the notes heading with the percentage
    ;;; it came from, so a quote can be found again in the reader as well as here.

    (defun my/book-notes-file (&optional book)
      "Path to the notes for BOOK, defaulting to the one being read."
      (let ((name (file-name-base (or book nov-file-name "notes"))))
        (expand-file-name (concat name ".org") my/book-notes-dir)))

    (defun my/book-notes ()
      "Open this book's notes in a window to the right."
      (interactive)
      (unless (derived-mode-p 'nov-mode)
        (user-error "Not reading a book"))
      (let ((file (my/book-notes-file))
            (title (or (alist-get 'title nov-metadata) (file-name-base nov-file-name))))
        (make-directory my/book-notes-dir t)
        (let ((buffer (find-file-noselect file)))
          (with-current-buffer buffer
            (when (zerop (buffer-size))
              (insert (format "#+TITLE: %s\n\n* Notes\n" title))
              (save-buffer)))
          (display-buffer buffer '(display-buffer-in-side-window
                                   (side . right) (window-width . 0.4))))))

    (defun my/book-note-capture (beginning end)
      "File the region -- or this line -- into the book's notes."
      (interactive "r")
      (unless (derived-mode-p 'nov-mode)
        (user-error "Not reading a book"))
      (let* ((text (string-trim
                    (if (use-region-p)
                        (buffer-substring-no-properties beginning end)
                      (thing-at-point 'line t))))
             (percentage (* 100 (my/nov-percentage)))
             (file (my/book-notes-file)))
        (my/book-notes)
        (with-current-buffer (find-file-noselect file)
          (goto-char (point-max))
          (insert (format "\n** %.1f%%\n#+begin_quote\n%s\n#+end_quote\n\n"
                          percentage text))
          (save-buffer))
        (deactivate-mark)
        (message "Noted at %.1f%%" percentage)))

    (defun my/book-open ()
      "Open a book from the library."
      (interactive)
      (make-directory my/books-dir t)
      (let ((default-directory my/books-dir))
        (call-interactively #'find-file)))

    (defun my/book-library ()
      "Browse the library the reader and calibre-web both serve."
      (interactive)
      (make-directory my/books-dir t)
      (dired my/books-dir))
  '';
}
