{
  lib,
  pkgs,
  ...
}:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      obsidian
    ];

  programs.emacs.extraConfig = ''
        ;;; Obsidian — obsidian.el over the same vault obsidian.nvim uses.
        ;;;
        ;;; Same directory, same markdown files, so notes edited here and in the Obsidian
        ;;; app stay in sync exactly as they do from nvim. The vault path matches the
        ;;; nvim `dir' setting.
        ;;;
        ;;; Loaded on first use rather than at startup, which matters more than it looks:
        ;;; obsidian.el resolves its vault and starts a polling timer the moment it is
        ;;; required, and if the vault is missing it silently falls back to indexing
        ;;; `default-directory' instead. During the sandboxed byte-compile that meant
        ;;; scanning the nix build directory on a timer that could fire part-way through
        ;;; compilation — which is exactly the failure that showed up as an error landing
        ;;; at a different line on every build.

        (setq obsidian-directory (expand-file-name "~/Documents/robertogoam")
              obsidian-inbox-directory "Inbox"
              obsidian-daily-notes-directory "Daily"
              obsidian-wiki-link-alias-first t
              obsidian-links-use-vault-path nil)

        (autoload 'obsidian-capture "obsidian" nil t)
        (autoload 'obsidian-jump "obsidian" nil t)
        (autoload 'obsidian-insert-template "obsidian" nil t)
        (autoload 'global-obsidian-mode "obsidian" nil t)

        (defun my/obsidian-ensure ()
          "Load obsidian.el and turn it on, once, if the vault is actually present."
          (unless (featurep 'obsidian)
            (if (not (file-directory-p obsidian-directory))
                (user-error "Obsidian vault %s is not present" obsidian-directory)
              (require 'obsidian)
              (global-obsidian-mode 1)))
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

        (add-hook 'markdown-mode-hook #'my/obsidian-maybe-enable)

        (defun my/obsidian-new ()
          "Create a note in the vault."
          (interactive)
          (when (my/obsidian-ensure)
            (call-interactively #'obsidian-capture)))

        (defun my/obsidian-new-from-template ()
          "Create a note from a template.
    obsidian.nvim's `new_from_template' has no obsidian.el equivalent, so this captures
    a fresh note and then inserts a template into it."
          (interactive)
          (when (my/obsidian-ensure)
            (call-interactively #'obsidian-capture)
            (when (fboundp 'obsidian-insert-template)
              (call-interactively #'obsidian-insert-template))))

        (defun my/obsidian-open-note ()
          "Jump to a note in the vault."
          (interactive)
          (when (my/obsidian-ensure)
            (call-interactively #'obsidian-jump)))

        (defun my/obsidian-open-app ()
          "Open the current note in the Obsidian app."
          (interactive)
          ${
            if pkgs.stdenv.hostPlatform.isDarwin then
              ''
                (let ((file (buffer-file-name)))
                        (if file
                            (call-process "/usr/bin/open" nil nil nil "-a" "Obsidian" file)
                          (call-process "/usr/bin/open" nil nil nil "-a" "Obsidian")))''
            else
              ''
                (let ((file (buffer-file-name)))
                        (call-process "xdg-open" nil nil nil (or file obsidian-directory)))''
          })
  '';
}
