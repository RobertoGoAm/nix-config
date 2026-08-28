# Literate Nix: author the config as org prose, commit the tangled .nix.
#
# The org sources live in their own private repository, cloned to
# ~/nix-config-literate, and are never committed to nix-config. Saving one
# writes the .nix it describes into the matching path here, with the prose
# around each block emitted as `#' comments -- so what lands in the public
# repo is ordinary commented Nix, the same thing that was there before.
#
# The separate repo is the reason lit-tangle --check exists. Nothing stops you
# editing a .nix in nix-config directly, on a host that has no clone of the
# sources; it will work, and it will be silently overwritten the next time the
# org file it came from is saved. The check catches that before a commit does.
{ pkgs, config, ... }:
{
  home.packages = [ pkgs.lit-tangle ];

  programs.emacs.extraConfig = ''
        ;;; Literate Nix — org sources tangled into the nix-config checkout.

        (require 'org)
        (require 'ob-tangle)

        (defvar my/lit-src-root
          (file-name-as-directory "${config.home.homeDirectory}/nix-config-literate")
          "Root of the literate org sources.")

        (defvar my/lit-out-root
          (file-name-as-directory "${config.home.homeDirectory}/nix-config")
          "Root of the nix-config checkout the org sources tangle into.")

        ;; Org works out a language's comment syntax by consulting a major mode,
        ;; and it ships no entry for nix. Without this line `:comments org' fails
        ;; with "No comment syntax is defined" and tangles nothing at all -- not
        ;; a broken file, no file -- which reads as the save hook not firing.
        ;;
        ;; nix-ts-mode also gives C-c ' a real editing mode for the block, with
        ;; the treesitter font-lock and the nixd server the rest of this config
        ;; already sets up.
        (add-to-list 'org-src-lang-modes '("nix" . nix-ts))

        (defun my/lit-target ()
          "Destination .nix path for the org file being tangled.

    Every literate source carries the same `:tangle (my/lit-target)' header, so
    the mirroring lives in one function rather than in a hand-written relative
    path per file -- those differ with each file's depth in the tree and break
    silently when a file moves. lit-tangle.el defines this under the same name,
    so the editor and the batch tangler agree on where output goes."
          (let ((rel (file-relative-name (buffer-file-name) my/lit-src-root)))
            (expand-file-name (concat (file-name-sans-extension rel) ".nix")
                              my/lit-out-root)))

        (defun my/lit-buffer-p ()
          "Non-nil when this buffer is a literate source, not just any org file."
          (and buffer-file-name
               (derived-mode-p 'org-mode)
               (string-prefix-p my/lit-src-root (expand-file-name buffer-file-name))))

        (defun my/lit-tangle-on-save ()
          "Tangle a literate source when it is saved.

    Scoped by path on purpose: this is on the global `after-save-hook', and an
    org file anywhere else -- the Obsidian vault, a capture, a scratch note --
    must not start writing .nix files into the config."
          (when (my/lit-buffer-p)
            (let ((org-confirm-babel-evaluate nil))
              (org-babel-tangle))
            (message "Tangled %s" (file-relative-name (buffer-file-name)
                                                      my/lit-src-root))))

        (add-hook 'after-save-hook #'my/lit-tangle-on-save)

        (defun my/lit-tangle-all ()
          "Tangle every literate source, not just the one in this buffer.
    For after a pull, or a change to something several files quote."
          (interactive)
          (let ((org-confirm-babel-evaluate nil)
                (files (directory-files-recursively my/lit-src-root "\\.org\\'")))
            (dolist (f files) (org-babel-tangle-file f))
            (message "Tangled %d literate file(s)" (length files))))

        (defun my/lit-check ()
          "Report whether the committed Nix still matches the org sources."
          (interactive)
          (compile "lit-tangle --check"))
  '';
}
