{
  lib,
  ...
}:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      dimmer
      doom-themes
    ];

  programs.emacs.extraConfig = lib.mkOrder 300 ''
        ;;; Colorscheme: tokyonight storm, transparent.

        ;; The storm palette, verbatim from the nvim colorscheme (plus the #2d3149
        ;; prompt colour the Telescope on_highlights block picks). statusline.nix reads
        ;; this alist, so the modeline cannot drift from the theme.
        (defconst my/tokyonight
          '((bg       . "#24283b")
            (bg-dark  . "#1f2335")
            (bg-hl    . "#292e42")
            (prompt   . "#2d3149")
            (fg       . "#c0caf5")
            (fg-dark  . "#a9b1d6")
            (comment  . "#565f89")
            (blue     . "#7aa2f7")
            (cyan     . "#7dcfff")
            (green    . "#9ece6a")
            (magenta  . "#bb9af7")
            (orange   . "#ff9e64")
            (violet   . "#9d7cd8")
            (red      . "#f7768e")
            (yellow   . "#e0af68"))
          "tokyonight storm, as used by the nvim config and the modeline.")

        (defun my/tn (key)
          "Hex string for KEY in `my/tokyonight'."
          (alist-get key my/tokyonight))

        (require 'doom-themes)
        (setq doom-themes-enable-bold t
              doom-themes-enable-italic t
              doom-themes-treemacs-theme "doom-colors")
        (load-theme 'doom-tokyo-night :no-confirm)

        ;; Break a face inheritance cycle the theme introduces.
        ;;
        ;; Under Emacs 31 creating a graphical frame died with
        ;;
        ;;   (error "Face inheritance results in inheritance cycle"
        ;;          gnus-group-news-low)
        ;;
        ;; so `emacsclient -c' could not open a window at all. A standalone
        ;; Emacs.app was unaffected, which is why this looked like a launcher
        ;; problem rather than a theme one.
        ;;
        ;; The cycle is between the theme and the stock defface:
        ;;
        ;;   theme: gnus-group-news-low-empty -> gnus-group-news-low  (t, always)
        ;;   stock: gnus-group-news-low       -> gnus-group-news-low-empty
        ;;
        ;; The theme only points news-low somewhere else for displays matching
        ;; (min-colors 257); wherever that clause does not apply the defface
        ;; stands and the two face each other. Emacs 30 tolerated the cycle,
        ;; 31 raises on it.
        ;;
        ;; custom-theme-reset-faces, not set-face-attribute: the latter is
        ;; undone on every new frame, since each one re-applies the theme's
        ;; specs -- which is exactly why overriding the attribute appeared to
        ;; work and then did not. Both ends are reset because resetting only
        ;; the entry point restores its defface and the cycle survives.
        ;;
        ;; Nothing is lost: gnus is not used here, so these two faces are only
        ;; ever realised as part of building a frame's face table.
        (dolist (f '(gnus-group-news-low gnus-group-news-low-empty))
          (when (facep f)
            (custom-theme-reset-faces 'doom-tokyo-night (list f nil))
            (set-face-attribute f nil :inherit 'unspecified)))

        ;; doom-tokyo-night ships the "night" variant; these four faces are the visible
        ;; difference from "storm", so overriding them lands on the same colours the
        ;; terminal and nvim already use.
        (custom-set-faces
         `(default        ((t (:background ,(my/tn 'bg) :foreground ,(my/tn 'fg)))))
         `(hl-line        ((t (:background ,(my/tn 'bg-hl)))))
         `(region         ((t (:background ,(my/tn 'bg-hl)))))
         `(vertical-border ((t (:foreground ,(my/tn 'bg-dark) :background ,(my/tn 'bg-dark)))))
         ;; styles.comments.italic / styles.keywords.italic + bold
         `(font-lock-comment-face ((t (:foreground ,(my/tn 'comment) :slant italic))))
         `(font-lock-keyword-face ((t (:slant italic :weight bold)))))

        ;; styles.floats = "dark" and styles.sidebars = "dark": popups and side panels
        ;; sit a shade below the editor so they stay readable when the editor itself is
        ;; transparent. Same reasoning as the Telescope on_highlights override.
        (custom-set-faces
         `(child-frame-border ((t (:background ,(my/tn 'bg-dark)))))
         `(tooltip            ((t (:background ,(my/tn 'bg-dark) :foreground ,(my/tn 'fg-dark)))))
         `(vertico-posframe        ((t (:background ,(my/tn 'bg-dark) :foreground ,(my/tn 'fg-dark)))))
         `(vertico-posframe-border ((t (:background ,(my/tn 'bg-dark)))))
         `(corfu-default      ((t (:background ,(my/tn 'bg-dark) :foreground ,(my/tn 'fg-dark)))))
         `(corfu-border       ((t (:background ,(my/tn 'bg-dark)))))
         `(corfu-current      ((t (:background ,(my/tn 'prompt) :foreground ,(my/tn 'fg)))))
         `(treemacs-window-background-face ((t (:background ,(my/tn 'bg-dark)))))
         `(lsp-ui-doc-background ((t (:background ,(my/tn 'bg-dark))))))

        (defun my/apply-transparency (&optional frame)
          "Mirror the nvim `transparent = true' background for FRAME.
    Terminal frames drop their background entirely, so the translucent iTerm2 or
    Alacritty window shows through exactly as it does under nvim. GUI frames only get
    real background transparency on pgtk/X, where `alpha-background' exists — the
    macOS NS port ignores it, and plain `alpha' would fade the text too, so a GUI
    frame there keeps the solid storm background instead.

    Each `set-face-background' passes FRAME explicitly. Without it the change is
    global, not frame-local -- `with-selected-frame' does not scope face changes,
    and setting the default face with no frame also rewrites background-color in
    `default-frame-alist'. Under `emacs --fg-daemon' the initial frame F1 is a
    terminal frame, so this ran at startup and left every face, and the alist
    every future frame is built from, holding \"unspecified-bg\" -- a value that
    only means anything on a terminal. Creating a GUI frame then died with
    (error \"Unknown color\"), so `emacsclient -c' could never open a window and
    the daemon was unusable for GUI work."
          (let ((frame (or frame (selected-frame))))
            (if (memq (framep frame) '(pgtk x))
                (set-frame-parameter frame 'alpha-background 90)
              (unless (display-graphic-p frame)
                (set-face-background 'default "unspecified-bg" frame)
                (set-face-background 'line-number "unspecified-bg" frame)
                (set-face-background 'fringe "unspecified-bg" frame)))))

        (add-to-list 'default-frame-alist '(alpha-background . 90))
        (add-hook 'after-make-frame-functions #'my/apply-transparency)
        (add-hook 'server-after-make-frame-hook #'my/apply-transparency)
        (my/apply-transparency)

        ;; dim_inactive: the window you are not in recedes.
        (require 'dimmer)
        (setq dimmer-fraction 0.25
              dimmer-adjustment-mode :foreground
              dimmer-watch-frame-focus-events nil)
        (dimmer-configure-which-key)
        (dimmer-configure-magit)
        (dimmer-mode 1)
  '';
}
