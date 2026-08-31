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
    (setq alert-default-style '${
      if pkgs.stdenv.hostPlatform.isDarwin then "osx-notifier" else "libnotify"
    }
          alert-fade-time 5)

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
