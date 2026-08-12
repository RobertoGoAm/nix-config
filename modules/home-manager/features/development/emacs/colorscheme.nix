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
    frame there keeps the solid storm background instead."
          (let ((frame (or frame (selected-frame))))
            (if (memq (framep frame) '(pgtk x))
                (set-frame-parameter frame 'alpha-background 90)
              (unless (display-graphic-p frame)
                (with-selected-frame frame
                  (set-face-background 'default "unspecified-bg")
                  (set-face-background 'line-number "unspecified-bg")
                  (set-face-background 'fringe "unspecified-bg"))))))

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
