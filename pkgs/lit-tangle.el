;;; lit-tangle.el --- Tangle the literate Nix sources  -*- lexical-binding: t; -*-

;; Batch half of the literate nix-config setup: walks a tree of .org sources
;; and writes the .nix files they describe into a mirrored tree.
;;
;; Emacs tangles these on save too (see the literate.nix Emacs module). This
;; exists so the same job can run without a configured Emacs — from a shell,
;; from a rebuild, or as the drift check that proves the committed .nix still
;; matches the org it came from.

(require 'org)
(require 'ob-tangle)

(defvar lit-src nil "Root of the .org sources.")
(defvar lit-out nil "Root the .nix files are written into.")

;; Org derives a language's comment syntax from a major mode and ships no
;; entry for nix at all. Without one, `:comments org' fails with
;;
;;   No comment syntax is defined
;;
;; and tangles nothing — not a malformed file, no file.
;;
;; The editor maps nix to nix-ts-mode, which `emacs -Q' cannot load. Falling
;; back to conf-mode happens to work, but "happens to work" is how the two
;; paths drift into emitting different comment padding and every tangle shows
;; up as a spurious diff. Pinning the two settings nix-ts-mode itself sets
;; makes them identical by construction rather than by coincidence.
(define-derived-mode lit-nix-mode prog-mode "LitNix"
  "Stand-in for `nix-ts-mode', for its comment syntax and nothing else."
  (setq-local comment-start "# ")
  (setq-local comment-start-skip "#+\\s-*"))

(add-to-list 'org-src-lang-modes '("nix" . lit-nix))

(defun my/lit-target ()
  "Destination .nix path for the org file currently being tangled.

Every literate source carries the same `:tangle (my/lit-target)' header, so
the src->out mirroring lives here rather than in a hand-written relative
path per file — those differ with each file's depth and silently break the
moment a file moves. Defined under the same name in the Emacs module, so
the two tangle paths agree."
  (let ((rel (file-relative-name (buffer-file-name) lit-src)))
    (expand-file-name (concat (file-name-sans-extension rel) ".nix") lit-out)))

(let* ((args command-line-args-left)
       (org-confirm-babel-evaluate nil)
       (files nil))
  (unless (= (length args) 2)
    (message "usage: lit-tangle.el SRC-ROOT OUT-ROOT")
    (kill-emacs 2))
  (setq lit-src (file-name-as-directory (expand-file-name (nth 0 args)))
        lit-out (file-name-as-directory (expand-file-name (nth 1 args))))
  (unless (file-directory-p lit-src)
    (message "lit-tangle: no such source tree: %s" lit-src)
    (kill-emacs 1))
  (setq files (sort (directory-files-recursively lit-src "\\.org\\'") #'string<))
  (dolist (f files)
    (message "  %s" (file-relative-name f lit-src))
    (org-babel-tangle-file f))
  (message "lit-tangle: %d org file(s)" (length files)))
