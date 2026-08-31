# development emacs plugins files replace

{
  ...
}:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      deadgrep
      wgrep
    ];

  programs.emacs.extraConfig = ''
    ;;; Search and replace — deadgrep + wgrep in place of grug-far.
    ;;;
    ;;; deadgrep's results buffer becomes directly editable with
    ;;; `deadgrep-edit-mode': change the matched text in place, then C-c C-c writes
    ;;; every file back. Same shape as grug-far, and wgrep gives the identical
    ;;; treatment to any consult-ripgrep result exported with embark.

    (require 'deadgrep)
    (require 'wgrep)

    (setq wgrep-auto-save-buffer t
          wgrep-change-readonly-file t
          deadgrep-max-line-length 500)

    ;; C-c C-e enters the editable mode from either kind of results buffer, so the
    ;; keystroke does not depend on which one you happened to open. Plain "e" is
    ;; deliberately left alone — the Colemak rotation owns it as a movement key.
    (with-eval-after-load 'deadgrep
      (define-key deadgrep-mode-map (kbd "C-c C-e") #'deadgrep-edit-mode))
    (with-eval-after-load 'grep
      (define-key grep-mode-map (kbd "C-c C-e") #'wgrep-change-to-wgrep-mode))

    (defun my/replace-buffer ()
      "Substitute across this buffer, starting a :%s/ line."
      (interactive)
      (evil-ex "%s/"))

    (defun my/replace-word-buffer ()
      "Substitute the symbol at point across this buffer."
      (interactive)
      (let ((word (thing-at-point 'symbol t)))
        (if word
            (evil-ex (format "%%s/\\<%s\\>/" (regexp-quote word)))
          (evil-ex "%s/"))))

    (defun my/replace-project ()
      "Search the project, then edit the matches in place and save them all."
      (interactive)
      (deadgrep (read-string "Replace across project — search for: ")))

    (defun my/replace-word-project ()
      "Same as `my/replace-project', seeded with the symbol at point."
      (interactive)
      (deadgrep (or (thing-at-point 'symbol t)
                    (read-string "Search for: "))))
  '';
}
