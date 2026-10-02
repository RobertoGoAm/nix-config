# development emacs plugins apps browser

{
  lib,
  pkgs,
  user,
  ...
}:
{

  # browser-gt: Emacs and the browser on speaking terms

  # The browser keeps a WebSocket open to Emacs on =127.0.0.1:9130= and the two
  # drive each other over it. What is wanted from it here is the tab manager:
  # =browser-gt-tab-jump= lists every tab in every connected browser in one
  # completion prompt, with a client column once more than one is attached, and
  # focuses the chosen tab and its window in whichever browser it came from. That
  # is the half that is awkward from the browser side -- Vimium is already the
  # better answer for everything inside a page.

  # The extension is a separate package (=pkgs/browser-gt-extension.nix=), installed
  # into Zen by the zen module; Chrome's copy is loaded by hand, since current
  # Chrome has no way to install one from a path.

  # ~browser-gt-babel~ is deliberately not required. It is the only module that uses
  # =EVAL_IN_ACTIVE_TAB=, which runs arbitrary JavaScript inside a page and can read
  # its DOM, cookies and storage; the tab manager, the capture actions, and the
  # YouTube and ChatGPT savers all use their own handlers and need none of it.
  # Leaving the module unloaded means the capability is simply absent rather than
  # merely unused -- worth having in a browser signed into three organisations.

  # The socket itself has no authentication: it is bound to the loopback interface,
  # so nothing off this machine can reach it, but any local process can. That is
  # the same trust boundary as the Emacs server, and the reason to keep the set of
  # registered handlers small.

  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      browser-gt
      websocket
    ];

  # A real browser inside Emacs. This build has xwidgets compiled in

  # (withXwidgets = true, xwidget-internal present), so xwidget-webkit renders
  # actual WebKit -- CSS, JavaScript, logins -- not eww's text approximation.

  # It is not a replacement for the system browser, and two things in particular
  # must stay outside it:
  #   - Google Meet and anything else needing WebRTC. xwidget-webkit has no
  #     camera or microphone permission path, so a call cannot work there.
  #   - Anything wanting your logged-in profile, extensions or a password
  #     manager. The xwidget has its own empty cookie jar.
  # my/browse-external exists for exactly those. It takes a URL and is interactive,
  # so it is reachable with M-x without a command per site: the pinned tabs in the
  # Zen personal space cover the ones worth a shortcut, and a browser is one key
  # away regardless.

  programs.emacs.extraConfig = lib.mkOrder 1450 ''
    ;;; Browser -- xwidget-webkit for reading, the system browser for the rest.

    (require 'xwidget)
    (setq xwidget-webkit-enable-plugins t
          ;; Follow links in the same xwidget instead of spawning one buffer per
          ;; click, which is how you end up with forty of them.
          xwidget-webkit-buffer-name-format "*web: %T*")

    (defun my/browse-external (url)
      "Open URL in the system browser."
      (interactive "sURL: ")
      (browse-url-default-browser url))

    (defun my/browse-internal (url)
      "Open URL in an xwidget-webkit buffer inside Emacs."
      (interactive "sURL: ")
      (xwidget-webkit-browse-url url t))

    (defun my/browse-url-at-point ()
      "Open the URL at point in Emacs, or prompt when there is none."
      (interactive)
      (let ((url (or (thing-at-point 'url t)
                     (read-string "URL: " "https://"))))
        (my/browse-internal url)))

    ;; eww stays available for the cases where text really is better -- man
    ;; pages, RFCs, anything you want to search and yank as plain text.
    (setq browse-url-browser-function 'browse-url-default-browser
          eww-search-prefix "https://duckduckgo.com/html/?q=")

    ;;; browser-gt: the tab manager, and nothing that evaluates JavaScript.
    (require 'browser-gt)
    (require 'browser-gt-tab-manager)
    (browser-gt-start)

    ;; Focusing a tab does not bring the browser forward on macOS, so browser-gt
    ;; nudges it afterwards. Its precise path asks lsof which process holds the
    ;; socket and matches the client's name against that process's command line
    ;; -- and the client calls itself "firefox" while Zen's binary is
    ;; .../Zen Browser (Beta).app/Contents/MacOS/zen. Nothing matches, so the
    ;; lookup finds no pid and the `open -a' fallback is what actually runs.
    ;;
    ;; The full bundle path rather than a name: `open -a Zen' leaves the choice
    ;; to LaunchServices, and the darwin build is the beta channel, whose bundle
    ;; is named for it.
    (setq browser-gt-client-app-names
          '(("firefox" . "/Users/${user}/Applications/Home Manager Apps/Zen Browser (Beta).app")))

    ;; The tab manager is a tabulated list with dired-style keys -- d to mark
    ;; for deletion, x to execute, u to unmark, s to cycle the sort -- and
    ;; evil-collection has no module for a package this new, so in normal state
    ;; evil's own d/u/x/s would shadow every one of them. Making the map
    ;; overriding hands those keys back without touching the motions: n and e
    ;; are not in the map, so they still move between rows the way they do
    ;; everywhere else.
    (with-eval-after-load 'browser-gt-tab-manager
      (evil-make-overriding-map browser-gt-tab-manager-mode-map 'normal))
  '';
}
