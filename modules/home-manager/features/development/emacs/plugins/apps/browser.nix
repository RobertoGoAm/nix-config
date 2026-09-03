# development emacs plugins apps browser

{
  lib,
  pkgs,
  ...
}:
{

  # A real browser inside Emacs. This build has xwidgets compiled in

  # (withXwidgets = true, xwidget-internal present), so xwidget-webkit renders
  # actual WebKit -- CSS, JavaScript, logins -- not eww's text approximation.

  # It is not a replacement for the system browser, and two things in particular
  # must stay outside it:
  #   - Google Meet and anything else needing WebRTC. xwidget-webkit has no
  #     camera or microphone permission path, so a call cannot work there.
  #   - Anything wanting your logged-in profile, extensions or a password
  #     manager. The xwidget has its own empty cookie jar.
  # my/browse-external exists for exactly those, and the Meet/Chat commands use it.

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

    ;;; ---- Google Workspace surfaces ------------------------------------
    ;;
    ;; Gmail renders inside the xwidget. Meet and Chat do not, for different
    ;; reasons: Meet needs camera and microphone access xwidget-webkit cannot
    ;; grant, and Chat is blocked at sign-in because Google rejects embedded
    ;; browsers. Both go to the system browser.
    ;;
    ;; Chat is a web app either way -- there is no Emacs client for Google
    ;; Chat, the protocol is not open and nothing on MELPA speaks it.

    ;; Google Workspace goes to the real browser, never the xwidget.
    ;;
    ;; The organisation does not permit work services through an unmanaged
    ;; browser engine, and the xwidget is exactly that: its own WebKit with
    ;; its own cookie jar, outside the managed browser and its policies.
    ;; gchat and meet were already external; mail and calendar were not, which
    ;; was the whole of the exposure. Do not switch these back to
    ;; my/browse-internal.

    (defun my/open-gmail ()
      "Open Gmail in Emacs."
      (interactive)
      (my/browse-external "https://mail.google.com/"))

    (defun my/open-gcalendar ()
      "Open Google Calendar in Emacs."
      (interactive)
      (my/browse-external "https://calendar.google.com/"))

    (defun my/open-gchat ()
      "Open Google Chat in the system browser.
    Deliberately not an xwidget, for the same reason as Meet but a different
    cause: Google refuses to complete sign-in inside an embedded WebKit view,
    answering with \"This browser or app may not be secure\". Workspace
    policies tighten that further, so an account under an organisation cannot
    get past the login screen in xwidget at all. The session lives in the
    system browser, where the org's sign-in already works."
      (interactive)
      (my/browse-external "https://chat.google.com/"))

    (defun my/open-meet ()
      "Start or join a Google Meet in the system browser.
    Deliberately not an xwidget: Meet needs camera and microphone access, which
    xwidget-webkit cannot grant."
      (interactive)
      (my/browse-external "https://meet.google.com/"))

    (defun my/open-meet-next ()
      "Open the next Meet link found in the agenda, else Meet's home page."
      (interactive)
      (let ((url (my/agenda-next-meet-url)))
        (my/browse-external (or url "https://meet.google.com/"))))

    ;;; ---- Atlassian ----------------------------------------------------
    ;;
    ;; Jira and Confluence both render and sign in inside the xwidget. Their
    ;; login form is an ordinary one, so it does not hit the refusal Google
    ;; answers embedded WebKit with -- but an instance fronted by Google or
    ;; Microsoft SSO inherits that refusal, which is what my/open-jira-external
    ;; is for.
    ;;
    ;; The site URL comes from sops rather than being written here: this repo is
    ;; public and the subdomain names the client. With no secret in place the
    ;; commands prompt, so they still work on a machine without one.

    (defun my/atlassian-site ()
      "Return the Atlassian site URL, prompting when the secret is absent."
      (let ((f "/var/run/secrets/atlassian_site"))
        (string-trim
         (if (file-readable-p f)
             (with-temp-buffer (insert-file-contents f) (buffer-string))
           (read-string "Atlassian site (https://example.atlassian.net): ")))))

    (defun my/open-jira ()
      "Open Jira in Emacs."
      (interactive)
      (my/browse-internal (concat (my/atlassian-site) "/jira")))

    (defun my/open-confluence ()
      "Open Confluence in Emacs."
      (interactive)
      (my/browse-internal (concat (my/atlassian-site) "/wiki")))

    (defun my/open-jira-external ()
      "Open Jira in the system browser.
    For an instance behind Google or Microsoft SSO, where the embedded WebKit
    view cannot get past the identity provider's sign-in screen."
      (interactive)
      (my/browse-external (concat (my/atlassian-site) "/jira")))

    ;; eww stays available for the cases where text really is better -- man
    ;; pages, RFCs, anything you want to search and yank as plain text.
    (setq browse-url-browser-function 'browse-url-default-browser
          eww-search-prefix "https://duckduckgo.com/html/?q=")
  '';
}
