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
    (setq message-truncate-lines nil
          set-message-functions '(inhibit-message set-multi-message message-or-box)
          inhibit-message-regexps '("^Wrote " "^Saving file"))
  '';
}
