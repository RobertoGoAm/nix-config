# development emacs plugins ui notifications

{
  lib,
  pkgs,
  ...
}:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      alert
    ];

  programs.emacs.extraConfig = ''
        ;;; Notifications — alert in place of nvim-notify.
        ;;;
        ;;; Not a like-for-like swap: nvim-notify draws stacked toasts inside the editor,
        ;;; and Emacs has no equivalent. alert instead routes messages out to the system
        ;;; notifier, which is arguably the more useful half — a test suite or a compile
        ;;; that finishes while you are in another window actually tells you.

        (require 'alert)
        (setq alert-fade-time 5)
    ${lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
      ;;; The macOS transport, and why it is not alert's own osx-notifier.
      ;;;
      ;;; A banner is attributed to the bundle of the process that POSTS it, and
      ;;; to nothing else. The daemon runs from inside Emacs.app -- see
      ;;; client-app.nix -- so an AppleScript run *within* Emacs posts as
      ;;; org.gnu.Emacs: the banner carries Emacs' icon and clicking it raises
      ;;; Emacs. The same script through /usr/bin/osascript is attributed to
      ;;; Script Editor, and wrapping it in `tell application id "org.gnu.Emacs"'
      ;;; does not change that -- both were tested, and both said Script Editor.
      ;;;
      ;;; alert's own `osx-notifier' style already prefers `do-applescript' when
      ;;; it is available, so it gets that half right. Three things it does not
      ;;; do, and a chat client needs all three.
      ;;;
      ;;; `do-applescript' BLOCKS. Measured in this daemon: ~100ms for the first
      ;;; call and 19-24ms warm, against 0ms for the fire-and-forget subprocess it
      ;;; replaces. Emacs is single-threaded and its threads are cooperative, so a
      ;;; blocking C call cannot be moved off the main loop -- but it can be moved
      ;;; out of the way. Posted from an idle timer, the pause lands where you are
      ;;; not typing; a banner that waits for a gap in your typing is better
      ;;; behaviour rather than worse.
      ;;;
      ;;; A burst of ten messages is ten of those pauses. They are coalesced per
      ;;; title instead, which for telega is per chat.
      ;;;
      ;;; And `alert-osx-notifier-notify' ends by calling `alert-message-notify',
      ;;; which echoes the alert into the minibuffer as well. For a compile that
      ;;; finished that is harmless; for a group chat it is a stream of other
      ;;; people's messages over whatever the echo area was saying.

      (defvar my/notify-idle-delay 0.4
        "Seconds of idleness to wait for before posting queued notifications.")

      (defvar my/notify--pending nil
        "Notifications waiting for an idle moment, newest first.")

      (defvar my/notify--timer nil
        "The idle timer that will flush `my/notify--pending'.")

      (defun my/notify--applescript-string (s)
        "S as an AppleScript string literal.

      `%S' is the correct escape rather than an approximation of one: `prin1'
      escapes a double quote and a backslash and nothing else, which is exactly
      what an AppleScript string literal escapes. Whitespace is collapsed first --
      a banner is two lines whatever it is handed, and collapsing removes the
      newline, which is the one character the literal cannot carry."
        (format "%S"
                (string-trim
                 (replace-regexp-in-string
                  "[ \t\n\r]+" " " (substring-no-properties (or s ""))))))

      (defun my/notify--graphic-p ()
        "Non-nil when some frame of this session can talk to the window system.
      `display-graphic-p' with no argument asks about the SELECTED frame, and in
      a daemon that is as likely to be a terminal frame as not."
        (seq-some (lambda (frame) (display-graphic-p frame)) (frame-list)))

      (defun my/notify--post-in-process (title body)
        "Post through Emacs' own AppleScript. Non-nil when that worked."
        (and (fboundp 'do-applescript)
             (my/notify--graphic-p)
             (ignore-errors
               (do-applescript
                (format "display notification %s with title %s"
                        (my/notify--applescript-string body)
                        (my/notify--applescript-string title)))
               t)))

      (defun my/notify--post-subprocess (title body)
        "Post through osascript, which is the fallback and not the choice.

      The banner is attributed to Script Editor rather than to Emacs, which is
      worth having only because the alternative -- when there is no graphical
      frame, and `do-applescript' answers \"Window system is not in use\" -- is no
      banner at all.

      The text travels in argv rather than in the script source. Interpolating it
      would let any message containing a quote break the script, and a crafted one
      run arbitrary AppleScript; this content comes from other people."
        (call-process "/usr/bin/osascript" nil 0 nil
                      "-e" "on run argv"
                      "-e" "display notification (item 2 of argv) with title (item 1 of argv)"
                      "-e" "end run"
                      (substring-no-properties (or title ""))
                      (substring-no-properties (or body ""))))

      (defun my/notify--post (title body)
        "Show one banner, by whichever route is available."
        (unless (my/notify--post-in-process title body)
          (my/notify--post-subprocess title body)))

      (defun my/notify--flush ()
        "Post everything that queued up, one banner per title."
        (setq my/notify--timer nil)
        (let ((pending (nreverse my/notify--pending))
              (order nil)
              (groups nil))
          (setq my/notify--pending nil)
          (dolist (item pending)
            (let ((cell (assoc (car item) groups)))
              (unless cell
                (setq cell (list (car item)))
                (push cell groups)
                (push (car item) order))
              (setcdr cell (cons (cdr item) (cdr cell)))))
          (dolist (title (nreverse order))
            (let* ((bodies (nreverse (cdr (assoc title groups))))
                   (n (length bodies)))
              (my/notify--post
               title
               ;; The newest one, since that is the one you would have seen if
               ;; the banners had not been held, and a count of what came with it.
               (if (= n 1)
                   (car bodies)
                 (format "%s   (+%d more)" (car (last bodies)) (1- n))))))))

      (defun my/notify--queue (title body)
        "Hold TITLE and BODY until Emacs is idle."
        (push (cons title body) my/notify--pending)
        (unless my/notify--timer
          (setq my/notify--timer
                (run-with-idle-timer my/notify-idle-delay nil #'my/notify--flush))))

      (alert-define-style 'my/macos
                          :title "Notify through Emacs' own bundle, once idle"
                          :notifier
                          (lambda (info)
                            (my/notify--queue (or (plist-get info :title) "Emacs")
                                              (or (plist-get info :message) ""))))
    ''}
        (setq alert-default-style '${
          if pkgs.stdenv.hostPlatform.isDarwin then "my/macos" else "libnotify"
        })

        ;; The one door every notification in this config goes through: telega's
        ;; banners, a compile that finished, and anything added later. What varies
        ;; per platform is the style above, not the callers.
        (defun my/notify (title message &optional severity)
          "Send MESSAGE under TITLE at SEVERITY, defaulting to `normal'."
          (alert message :title title :severity (or severity 'normal)))

        ;; Long-running jobs report when they land: compiles, and the test runners in
        ;; plugins/code/test.nix that go through `compile'.
        (defun my/notify-compilation-finished (buffer status)
          "Notify that compilation in BUFFER ended with STATUS."
          (my/notify (format "Emacs — %s" (buffer-name buffer))
                     (string-trim status)
                     (if (string-match-p "finished" status) 'normal 'high)))

        (add-hook 'compilation-finish-functions #'my/notify-compilation-finished)

        ;; The echo area is where everything else lands, so keep it quiet and readable.
        ;;
        ;; `message-or-box' must NOT go in this list. It renders a message as a modal
        ;; DIALOG BOX whenever the command was invoked with the mouse and
        ;; `use-dialog-box' is non-nil (its default). Every ordinary `message' from a
        ;; mouse-driven command therefore became a dialog: alerts for routine actions,
        ;; a modal grabbing focus before dired could draw, and the CPU cost of the
        ;; resulting pile-up. It is invisible in a terminal or daemon, which is why
        ;; this survived -- it only misbehaves under a window system.
        ;;
        ;; `set-minibuffer-message' is Emacs's own default and is what the other two
        ;; entries are meant to compose with.
        (setq message-truncate-lines nil
              set-message-functions '(inhibit-message set-multi-message set-minibuffer-message)
              inhibit-message-regexps '("^Wrote " "^Saving file"))
  '';
}
