{
  lib,
  ...
}:
{
  # Split deliberately across two points in the generated file.
  #
  # The machinery and its hooks go FIRST, at 90 — ahead of the core block that calls
  # `evil-collection-init'. That ordering is load-bearing: evil-collection sets each
  # mode up through `with-eval-after-load', and for packages already loaded those run
  # immediately, so a hook added afterwards never sees them. Installed at 90, the hook
  # is in place before the first mode is ever evilified, and every plugin keymap gets
  # rotated as it appears.
  #
  # The global state maps and the remaining literal remaps go LAST, at 1500, once
  # every plugin has had its say.
  programs.emacs.extraConfig = lib.mkMerge [
    (lib.mkOrder 90 ''
            ;;; Colemak hnei rotation — the machinery.

            (defconst my/colemak-swaps
            '(("n" . "j") ("N" . "J")
              ("e" . "k") ("E" . "K")
              ("i" . "l") ("I" . "L"))
            "Key pairs the rotation exchanges.
      Read as a permutation, the nvim keymaps are three transpositions applied in both
      cases: n<->j, e<->k, i<->l. So hnei moves the cursor, j/J take over
      search-next/previous, k/K word-end, and l/L insert.")

          (defvar my/colemak-rotated-maps nil
            "Keymaps the rotation has already been applied to.
      Exchanging a pair is its own inverse, so applying it twice would silently undo
      it. This registry is what makes the hooks below safe to fire repeatedly.")

          (defun my/keymap-own-binding (map key)
            "Binding of KEY in MAP itself, ignoring MAP's parent.
      `lookup-key' follows parents, which for a derived mode would drag prog-mode's
      bindings down into the child map and rotate keys the mode never bound. Detaching
      the parent for the length of one lookup keeps the rotation to bindings the map
      actually owns."
            (let ((parent (keymap-parent map)))
              (unwind-protect
                  (progn
                    (when parent (set-keymap-parent map nil))
                    (let ((def (lookup-key map (kbd key) t)))
                      (if (numberp def) nil def)))
                (when parent (set-keymap-parent map parent)))))

          (defun my/colemak-rotate (map)
            "Exchange the `my/colemak-swaps' pairs in MAP, at most once."
            (when (and (keymapp map) (not (memq map my/colemak-rotated-maps)))
              (push map my/colemak-rotated-maps)
              (dolist (pair my/colemak-swaps)
                (let* ((a (car pair))
                       (b (cdr pair))
                       (ca (my/keymap-own-binding map a))
                       (cb (my/keymap-own-binding map b)))
                  ;; A keymap on either side means the key is a prefix — visual state's
                  ;; "i"/"a" text objects, or "g"/"z" — and swapping those would move a
                  ;; whole submenu. Skipping them is also what keeps `vi{' and `di{'
                  ;; working while n/e still move in visual and operator-pending state.
                  (unless (or (keymapp ca) (keymapp cb) (and (null ca) (null cb)))
                    (define-key map (kbd a) cb)
                    (define-key map (kbd b) ca))))))

          (defun my/colemak-rotate-all (map)
            "Rotate MAP and the evil auxiliary keymaps hanging off it.
      Plugins that bind through `evil-define-key' — which is every mode
      `evil-collection' touches — do not put their bindings in the mode map itself but
      in a per-state auxiliary keymap attached to it. Rotating only the mode map would
      leave magit, treemacs, dired and friends on qwerty. Insert and emacs state are
      deliberately left alone: there, the letters are letters."
            (when (keymapp map)
              (my/colemak-rotate map)
              (dolist (state '(normal visual motion operator))
                (let ((aux (ignore-errors (evil-get-auxiliary-keymap map state))))
                  (when (keymapp aux)
                    (my/colemak-rotate aux))))))

          (defun my/colemak-rotate-thing (thing)
            "Rotate THING, either a keymap or a symbol naming one."
            (cond
             ((keymapp thing) (my/colemak-rotate-all thing))
             ((and thing (symbolp thing) (boundp thing) (keymapp (symbol-value thing)))
              (my/colemak-rotate-all (symbol-value thing)))))

          (defun my/colemak-rotate-collection (&rest args)
            "Rotate whatever `evil-collection' just finished setting up.
      Run from `evil-collection-setup-hook', which passes the mode and a list of keymap
      symbols. Written to accept keymaps, symbols or any argument count so that an
      upstream signature change degrades to the major-mode backstop below instead of
      erroring on every single mode load. Note the keymapp test comes first: a keymap
      satisfies `listp', so testing for a list first would iterate its entries."
            (dolist (arg args)
              (if (and (listp arg) (not (keymapp arg)))
                  (mapc #'my/colemak-rotate-thing arg)
                (my/colemak-rotate-thing arg))))

          (add-hook 'evil-collection-setup-hook #'my/colemak-rotate-collection)

          (defun my/colemak-rotate-current-mode-maps ()
            "Rotate the current major mode's keymap.
      Backstop for modes `evil-collection' does not report — a plugin with its own
      evil bindings, or a mode that binds n/e/i directly."
            (let ((sym (and (fboundp 'derived-mode-map-name)
                            (derived-mode-map-name major-mode))))
              (when (and sym (boundp sym))
                (my/colemak-rotate-all (symbol-value sym))))
            (my/colemak-rotate-all (current-local-map)))

          (add-hook 'after-change-major-mode-hook #'my/colemak-rotate-current-mode-maps)
    '')

    (lib.mkOrder 1500 ''
      ;;; Colemak hnei rotation — the global state maps, and the literal remaps.

      ;; The global states. Motion carries the movement commands and is shared by
      ;; normal, visual and operator-pending, which is why `dn' deletes a line down
      ;; and `vn' selects one.
      ;;
      ;; This is deliberately one step stricter than the nvim config: those keymaps
      ;; omit `mode', so nixvim defaults them to normal mode only, leaving visual and
      ;; operator-pending on qwerty j/k/l. Rotating all four states is what you
      ;; actually want on Colemak. To match nvim exactly instead, cut this list down
      ;; to `evil-normal-state-map'.
      (dolist (map (list evil-motion-state-map
                         evil-normal-state-map
                         evil-visual-state-map
                         evil-operator-state-map))
        (my/colemak-rotate map))

      ;; Scroll pair. nvim swaps C-p and C-e, which lands nvim's C-e (scroll one line
      ;; down) on C-p. The other half of that swap inherits nvim's unbound normal-mode
      ;; C-p, so C-e is given scroll-one-line-up here to make it a usable pair — the
      ;; single intentional deviation, and a one-line revert if you want the literal
      ;; swap. Insert-state C-e stays on snippet jumping, as in cmp.nix.
      (evil-define-key 'normal 'global
        (kbd "C-p") #'evil-scroll-line-down
        (kbd "C-e") #'evil-scroll-line-up)
      (evil-define-key 'normal 'global
        (kbd "C-S-p") #'evil-scroll-down
        (kbd "C-S-e") #'evil-scroll-up)

      ;; Delete without copying: x, X and Del write to the black-hole register.
      (defun my/delete-char-no-yank (count)
        "Delete COUNT characters forward, leaving the unnamed register alone."
        (interactive "p")
        (evil-delete-char (point) (min (point-max) (+ (point) count)) 'exclusive ?_))

      (defun my/delete-backward-char-no-yank (count)
        "Delete COUNT characters backward, leaving the unnamed register alone."
        (interactive "p")
        (evil-delete-backward-char
         (max (point-min) (- (point) count)) (point) 'exclusive ?_))

      (evil-define-key 'normal 'global
        "x" #'my/delete-char-no-yank
        "X" #'my/delete-backward-char-no-yank
        (kbd "<delete>") #'my/delete-char-no-yank)

      ;; Increment and decrement, keeping the nvim assignment: "+" runs what vim binds
      ;; to C-x (decrement) and "-" what vim binds to C-a (increment).
      (evil-define-key 'normal 'global
        "+" #'evil-numbers/dec-at-pt
        "-" #'evil-numbers/inc-at-pt)

      ;; Normal-state Tab indents, as intellitab does. (This is vim's jump-forward
      ;; key; the nvim config overrides it the same way, and C-o still jumps back.)
      (evil-define-key 'normal 'global
        (kbd "TAB") #'indent-for-tab-command)

      ;; Escape leaves the terminal, mirroring <Esc> -> <C-\><C-n>.
      (with-eval-after-load 'vterm
        (evil-define-key 'insert vterm-mode-map (kbd "<escape>") #'evil-normal-state)
        (evil-define-key 'emacs vterm-mode-map (kbd "<escape>") #'evil-normal-state))

      ;; LSP signature help on C-k in both normal and insert, as the LspAttach autocmd
      ;; does. Insert-state C-k shadows `kill-line' here, same trade the nvim config
      ;; makes.
      (evil-define-key '(normal insert) 'global
        (kbd "C-k") #'my/lsp-signature-help)
    '')
  ];
}
