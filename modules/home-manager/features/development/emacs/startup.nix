# Background services, started once there is a frame

# The daemon comes up at login and stays up for days, so "when Emacs starts"
# really means "once, shortly after the first frame appears". Three things want
# that moment: Telegram connecting, mail syncing, and the Connect device coming
# back -- each of them is something used every day and none of them is worth
# opening by hand first.

# None of it belongs in init. The daemon has no frame there, which matters more
# than it sounds: telega decides whether it can draw images from the frame it is
# loaded in, and a service that starts before any frame exists gets that answer
# wrong for the life of the daemon. Init time is also the one stretch where
# every millisecond is visible, and tdlib, mu and a Web API round trip are not
# millisecond work.

# So services register on a hook here and are run from idle timers after the
# first frame, two seconds apart rather than all at once -- three subprocesses
# starting in the same second is a stall on the frame that has just opened. Idle
# rather than a plain delay because none of this is urgent: if the frame opened
# because you were about to type, the services can wait until you pause.

# Errors are demoted. These are conveniences running behind your back, and one
# of them failing must not take the other two with it, or leave a backtrace in a
# frame you opened to do something else.

{
  lib,
  ...
}:
{
  programs.emacs.extraConfig = lib.mkOrder 250 ''
    (defvar my/startup-hook nil
      "Functions to run once, shortly after the first frame of the session.
    Each is called with no arguments, on its own idle timer, with errors
    demoted. Add to it with `add-hook'; the services themselves are defined by
    the module that owns them, not here.")

    (defvar my/startup--done nil
      "Non-nil once `my/startup-hook' has been run.")

    (defun my/startup-run (&optional _frame)
      "Run `my/startup-hook', once per Emacs.

    Once per Emacs rather than once per frame: these are background services,
    and a second `emacsclient -c' does not want a second Telegram.

    Both entry points are needed, and only one of them ever fires. Under the
    daemon there is no frame at `emacs-startup-hook' time -- which is the whole
    reason for waiting -- and `server-after-make-frame-hook' is what runs when
    one finally appears. Started without a daemon it is the other way round."
      (unless my/startup--done
        (setq my/startup--done t)
        (let ((delay 2))
          (dolist (fn my/startup-hook)
            (run-with-idle-timer
             delay nil
             (lambda ()
               (with-demoted-errors "startup service: %S" (funcall fn))))
            (setq delay (+ delay 2))))))

    (add-hook 'server-after-make-frame-hook #'my/startup-run)
    (add-hook 'emacs-startup-hook #'my/startup-run)
  '';
}
