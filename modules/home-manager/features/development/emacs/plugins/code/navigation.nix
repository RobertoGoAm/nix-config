# development emacs plugins code navigation

{
  ...
}:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      avy
      pulsar
      symbol-overlay
      treesit-fold
      yascroll
    ];

  programs.emacs.extraConfig = ''
    ;;; Navigation — avy for hop, symbol-overlay for illuminate, treesit-fold for
    ;;; nvim-ufo, yascroll for scrollview, pulsar for the lspsaga beacon.
    ;;;
    ;;; Two nvim plugins have no counterpart and are deliberately absent rather than
    ;;; faked: precognition (the inline w/b/e hint overlay) and hardtime (the
    ;;; repeated-key nag). Nothing in the Emacs ecosystem does either.

    (require 'avy)
    ;; avy labels jump targets with `avy-keys', which defaults to the qwerty home
    ;; row. On Colemak the home row is arstd-hneio, so these are the keys actually
    ;; under your fingers — the same reasoning as the hnei rotation itself.
    (setq avy-keys '(?a ?r ?s ?t ?d ?h ?n ?e ?i ?o)
          avy-all-windows nil
          avy-all-windows-alt t
          avy-timeout-seconds 0.4
          avy-style 'at-full)

    ;; Hop's commands, one for one. avy's "-0" variants match any word start, which
    ;; is what HopWord does; -above and -below are HopWordBC and HopWordAC.
    (defalias 'my/jump-char        #'avy-goto-char)
    (defalias 'my/jump-char-2      #'avy-goto-char-2)
    (defalias 'my/jump-word        #'avy-goto-word-0)
    (defalias 'my/jump-word-above  #'avy-goto-word-0-above)
    (defalias 'my/jump-word-below  #'avy-goto-word-0-below)
    (defalias 'my/jump-line        #'avy-goto-line)

    ;; illuminate: the other occurrences of the symbol at point. lsp-mode does this
    ;; itself with real semantic information when a server is attached, so
    ;; symbol-overlay stands down there and covers everything else.
    (require 'symbol-overlay)
    (setq symbol-overlay-idle-time 0.2)
    (add-hook 'prog-mode-hook #'symbol-overlay-mode)
    (add-hook 'lsp-mode-hook (lambda () (symbol-overlay-mode -1)))

    ;; Folding. nvim runs ufo with foldlevel 99 and foldlevelstart 99 — everything
    ;; open until you fold it — which is treesit-fold's default behaviour, and it
    ;; folds on the same tree-sitter nodes ufo does.
    (require 'treesit-fold)
    ;; The fold-column indicators live in their own file.
    (require 'treesit-fold-indicators)
    (setq treesit-fold-line-count-show t
          treesit-fold-line-count-format " ⋯ %d lines ")
    (global-treesit-fold-mode 1)

    ;; The fold indicators are off, and this is not a matter of taste.
    ;;
    ;; `treesit-fold-indicators-mode' hangs its refresh on the window scroll
    ;; and size-change hooks, and that refresh runs a whole
    ;; `treesit-query-capture' over the visible window. So every redisplay --
    ;; every keystroke that scrolls, every line a terminal prints -- re-queries
    ;; the tree. Emacs' own CPU profiler, taken while the daemon sat at 99%:
    ;;
    ;;   554693  97%  redisplay_internal
    ;;   266077  46%    treesit-fold-indicators--scroll
    ;;   219430  38%      treesit-query-capture
    ;;
    ;; Forty-six per cent of everything, for triangles in the fringe. Folding
    ;; itself is untouched -- `global-treesit-fold-mode' above is what za, zc,
    ;; zo, zM and zR drive, and it costs nothing until a fold is asked for.
    ;; nvim's foldcolumn = "1" is what this was mirroring, and nvim redraws a
    ;; fold column without re-parsing the buffer to do it.

    (evil-define-key 'normal 'global
      (kbd "za") #'treesit-fold-toggle
      (kbd "zc") #'treesit-fold-close
      (kbd "zo") #'treesit-fold-open
      (kbd "zM") #'treesit-fold-close-all
      (kbd "zR") #'treesit-fold-open-all)

    ;; scrollview: a scrollbar drawn in the buffer, so it works in the terminal
    ;; too. Off for the same reason as the fold indicators, and found in the
    ;; same profile: `yascroll:after-window-scroll' was 22% of all CPU, second
    ;; only to them. Two decorations between them were taking sixty-eight per
    ;; cent of the daemon.
    ;;
    ;; `yascroll:delay-to-hide' does not help: the cost is in the scroll hook
    ;; that decides where to draw, which runs whether or not the bar is then
    ;; shown.
    (require 'yascroll)
    (setq yascroll:delay-to-hide 1.0)

    ;; lspsaga's beacon = true: flash the line you land on, so a jump is never
    ;; disorienting.
    (require 'pulsar)
    (setq pulsar-face 'pulsar-cyan
          pulsar-delay 0.05
          pulsar-iterations 8)
    (dolist (fn '(evil-scroll-line-down evil-scroll-line-up
                  evil-scroll-down evil-scroll-up
                  evil-window-up evil-window-down
                  evil-window-left evil-window-right
                  avy-goto-char avy-goto-char-2 avy-goto-line avy-goto-word-0
                  lsp-find-definition lsp-find-references xref-find-definitions
                  treesit-fold-open recenter-top-bottom))
      (add-to-list 'pulsar-pulse-functions fn))
    (pulsar-global-mode 1)

    ;; navbuddy and aerial: the symbol outline. lsp-treemacs gives the tree view
    ;; navbuddy has (and inherits the Colemak rotation through treemacs), while
    ;; consult-imenu is the searchable flat version.
    (defun my/symbol-outline ()
      "Outline of the symbols in this buffer — the Navbuddy reflex."
      (interactive)
      (if (bound-and-true-p lsp-mode)
          (lsp-treemacs-symbols)
        (consult-imenu)))
  '';
}
