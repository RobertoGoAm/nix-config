{
  lib,
  pkgs,
  ...
}:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      telega
    ];

  programs.emacs.extraConfig = ''
    ;;; Telegram — telega.el, a real client rather than a bridge.
    ;;;
    ;;; It talks to Telegram through tdlib, the same library the official desktop
    ;;; client uses, so chats, media and replies all work. First run asks for the
    ;;; phone number and the login code; the session is then kept under
    ;;; ~/.telega and survives restarts.
    ;;;
    ;;; Chrome, the Google suite and the rest of the app list stay outside the editor
    ;;; on purpose — nothing in Emacs improves on them, and pretending otherwise
    ;;; would mean a worse Gmail, not a better Emacs. GhostText (see
    ;;; plugins/vim/default.nix) is the useful half of the browser integration: it
    ;;; hands any textarea to Emacs with evil and the full config attached.

    ;; Autoloaded, not required: telega is something you open on purpose, and loading
    ;; a whole chat client (and its tdlib session handling) into every Emacs startup
    ;; buys nothing. `M-x telega' or SPC o t pulls it in.
    (autoload 'telega "telega" nil t)

    (setq telega-directory (expand-file-name "~/.telega")
          telega-use-images (display-graphic-p)
          telega-emoji-use-images nil
          telega-chat-fill-column 80
          telega-completing-read-function #'completing-read)

    (custom-set-faces
     `(telega-msg-heading ((t (:foreground ,(my/tn 'blue) :weight bold))))
     `(telega-unmuted-count ((t (:foreground ,(my/tn 'green))))))
  '';
}
