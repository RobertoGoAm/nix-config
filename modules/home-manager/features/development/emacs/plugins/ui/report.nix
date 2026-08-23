{ lib, ... }:
{
  # One command that collects everything worth having when Emacs misbehaves, so
  # a bug report is a file rather than a description. *Messages* alone is rarely
  # enough -- the useful context is usually the warning that scrolled past, the
  # backtrace nobody saved, and how long startup actually took.
  programs.emacs.extraConfig = lib.mkOrder 1450 ''
    ;;; Diagnostics report.

    ;; *Messages* IS the echo-area history -- every "Wrote ...", "Auto-saving...",
    ;; and command result that flashed at the bottom of the frame is in it,
    ;; including the ones inhibit-message-regexps hides from the echo area: those
    ;; are suppressed from display only, and still logged.
    ;;
    ;; The default keeps 1000 lines, which a long session with a chatty LSP will
    ;; roll straight past -- and the interesting message is usually the one that
    ;; scrolled off. 10000 lines of text costs nothing next to the rest of Emacs.
    (setq message-log-max 10000)

    (defun my/report--buffer (name)
      "Contents of buffer NAME, or a note that it does not exist."
      (if (get-buffer name)
          (with-current-buffer name (buffer-substring-no-properties (point-min) (point-max)))
        (format "(no %s buffer)" name)))

    (defun my/emacs-report ()
      "Write a diagnostics report and show where it went.
    Includes *Messages*, *Warnings*, any *Backtrace*, startup timing and the
    loaded-feature count. Written to a file rather than the kill ring because
    *Messages* routinely runs to thousands of lines."
      (interactive)
      (let* ((file (expand-file-name
                    (format-time-string "~/emacs-report-%Y%m%d-%H%M%S.txt")))
             (text
              (concat
               "=== emacs ===\n"
               (format "version:      %s\n" emacs-version)
               (format "init time:    %s\n" (emacs-init-time))
               (format "features:     %d loaded\n" (length features))
               (format "daemon:       %s\n" (daemonp))
               (format "system:       %s\n" system-configuration)
               (format "frame:        %s\n" (framep (selected-frame)))
               ;; Which store path this is running from pins the report to a
               ;; specific generation, which matters when the question is whether
               ;; a rebuild actually took effect.
               (format "invocation:   %s\n" (expand-file-name invocation-name invocation-directory))
               "\n=== *Warnings* ===\n" (my/report--buffer "*Warnings*")
               "\n\n=== *Backtrace* ===\n" (my/report--buffer "*Backtrace*")
               "\n\n=== *Messages* ===\n" (my/report--buffer "*Messages*"))))
        (with-temp-file file (insert text))
        (kill-new file)
        (message "Report written to %s (path copied)" file)
        file))

    (defun my/report-profiler-start ()
      "Start the CPU profiler, to catch a freeze in the act."
      (interactive)
      (profiler-start 'cpu)
      (message "Profiler running -- reproduce the problem, then SPC h P"))

    (defun my/report-profiler-stop ()
      "Stop the profiler and write its report next to the diagnostics one."
      (interactive)
      (profiler-stop)
      (profiler-report)
      (let ((file (expand-file-name
                   (format-time-string "~/emacs-profile-%Y%m%d-%H%M%S.txt"))))
        ;; The report buffer is a tree that starts collapsed; expanding it is what
        ;; makes the written file readable rather than four summary lines.
        (with-current-buffer (get-buffer "*CPU-Profiler-Report*")
          (profiler-report-expand-entry)
          (write-region (point-min) (point-max) file))
        (kill-new file)
        (message "Profile written to %s (path copied)" file)))
  '';
}
