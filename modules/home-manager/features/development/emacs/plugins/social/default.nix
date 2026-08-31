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

    ;; Your own Telegram API credentials, or no login code ever arrives.
    ;;
    ;; telega ships
    ;;
    ;;   (defconst telega-app '(72239 . "bbf972f94cc6f0ee5da969d8d42a6c76"))
    ;;
    ;; -- one api_id shared by every telega user and published in the package
    ;; source. Telegram silently stops delivering login codes for api_ids it
    ;; considers abused, and the failure gives nothing away: the auth state
    ;; reaches authorizationStateWaitCode with
    ;; authenticationCodeTypeTelegramMessage, no message is delivered to any
    ;; session or by SMS, and anything entered comes back PHONE_CODE_INVALID.
    ;;
    ;; Register an application at https://my.telegram.org/apps and put the pair
    ;; in ~/.config/telega/app.el, which is deliberately outside this public
    ;; repository because api_hash is a credential:
    ;;
    ;;   (setq telega-app '(1234567 . "0123456789abcdef0123456789abcdef"))
    ;;
    ;; after-load, not here: telega-app is a defconst, so loading telega.el
    ;; would overwrite anything set beforehand. Missing file is not an error --
    ;; telega still loads, and still cannot log in.
    (with-eval-after-load 'telega
      (let ((f (expand-file-name "~/.config/telega/app.el")))
        (when (file-readable-p f)
          (load f nil :nomessage))))

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
