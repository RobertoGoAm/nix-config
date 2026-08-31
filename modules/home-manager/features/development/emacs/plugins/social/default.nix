# development emacs plugins social

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

  # telega renders the login QR code by shelling out to qrencode....

  # telega renders the login QR code by shelling out to qrencode. Without it on
  # PATH the QR branch is skipped silently and telega falls back to asking for a
  # phone number -- see the login note in extraConfig below.

  home.packages = [
    pkgs.qrencode
  ]

  # Notification transport on macOS -- see the notify override in...

  # Notification transport on macOS -- see the notify override in extraConfig.

  ++ lib.optional pkgs.stdenv.hostPlatform.isDarwin pkgs.terminal-notifier;

  programs.emacs.extraConfig = ''
    ;;; Telegram — telega.el, a real client rather than a bridge.
    ;;;
    ;;; It talks to Telegram through tdlib, the same library the official desktop
    ;;; client uses, so chats, media and replies all work. The session is kept
    ;;; under ~/.telega and survives restarts.
    ;;;
    ;;; First run should show a QR CODE to scan from a phone that is already
    ;;; logged in, not ask for a phone number. telega only falls back to the
    ;;; phone prompt when the QR branch is unavailable:
    ;;;
    ;;;   (if (and (not telega--relogin-with-phone-number)
    ;;;            telega-use-images
    ;;;            (or (executable-find "qrencode") telega-use-docker))
    ;;;       (telega--requestQrCodeAuthentication)
    ;;;     (telega--setAuthenticationPhoneNumber (read-string ...)))
    ;;;
    ;;; and that fallback is a dead end on an account whose login codes are
    ;;; delivered in-app: Telegram reports next_type = null, so it never offers
    ;;; SMS, and the code lands in a service chat that may not be visible.
    ;;; qrencode is now installed above, and telega-use-images is set below when
    ;;; telega loads rather than when this file does.
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

    ;; Asked when telega loads, not when this file does.
    ;;
    ;; This was `telega-use-images (display-graphic-p)' in the setq below, and
    ;; under `emacs --fg-daemon' that runs with no graphical frame in
    ;; existence, so it was pinned nil for the life of the daemon. Images off
    ;; also disables telega's QR login branch, which is why first run asked for
    ;; a phone number instead of showing a code to scan.
    ;;
    ;; telega is autoloaded and opened deliberately, so load time is the frame
    ;; you invoked it from -- the right one to ask.
    (with-eval-after-load 'telega
      (setq telega-use-images (display-graphic-p)))

    ;; Keeps telega's unread counters current, and calls
    ;; `force-mode-line-update' when they change -- which is what makes the
    ;; my/telega segment in statusline.nix refresh. Its own mode-line string
    ;; goes to `mode-line-misc-info', which this modeline does not render; the
    ;; mode is enabled for the bookkeeping, not the string.
    (with-eval-after-load 'telega
      (telega-mode-line-mode 1))

    ;; Desktop notifications on macOS.
    ;;
    ;; telega-notifications--notify calls `notifications-notify', which is
    ;; D-Bus and therefore Linux-only: on darwin telega-notifications-mode runs
    ;; and silently produces nothing. terminal-notifier is the usual bridge to
    ;; Notification Center for a program that is not itself an .app.
    ;;
    ;; -sender org.gnu.Emacs makes the banner carry the Emacs icon and raise
    ;; Emacs when clicked, and -group replaces the previous banner rather than
    ;; stacking one per message -- the same intent as the
    ;; notifications-close-notification call in the function being replaced.
    ;;
    ;; Properties are stripped: telega's :title and :body carry faces and image
    ;; specs for the Emacs display, and terminal-notifier wants plain argv.
    ;; call-process with a destination of 0 does not wait, so a slow banner
    ;; never blocks the chat.
    ${lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
      (defun my/telega-notify-macos (notify-spec)
        "Show NOTIFY-SPEC through terminal-notifier instead of D-Bus."
        (let ((title (substring-no-properties
                      (or (plist-get notify-spec :title) "Telegram")))
              (body (substring-no-properties
                     (or (plist-get notify-spec :body) ""))))
          (call-process "${lib.getExe pkgs.terminal-notifier}" nil 0 nil
                        "-title" title
                        "-message" body
                        "-group" "emacs.telega"
                        "-sender" "org.gnu.Emacs")))

      (with-eval-after-load 'telega
        (advice-add 'telega-notifications--notify
                    :override #'my/telega-notify-macos)
        (telega-notifications-mode 1))
    ''}

    (setq telega-directory (expand-file-name "~/.telega")
          telega-emoji-use-images nil
          telega-chat-fill-column 80
          telega-completing-read-function #'completing-read)

    (custom-set-faces
     `(telega-msg-heading ((t (:foreground ,(my/tn 'blue) :weight bold))))
     `(telega-unmuted-count ((t (:foreground ,(my/tn 'green))))))
  '';
}
