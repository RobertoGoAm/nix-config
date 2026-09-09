# Mail — mbsync pulls into a Maildir, mu indexes it, mu4e reads it

# Nothing identifying is in this file, and that is the point. Addresses live in
# the gitignored ~/.config/nix-secrets/mail-accounts.nix, read at eval under
# --impure -- the same privatePath pattern as work-extras.nix -- and passwords
# are sops secrets read at runtime from /var/run/secrets. An address is as
# revealing as the password here: this repo is public and names the employer
# nowhere else.

# With the private file absent the module defines no accounts and does nothing,
# so a fresh machine, or an adopter, still builds.

# ~/.config/nix-secrets/mail-accounts.nix looks like:

#   { ... }:
#   {
#     accounts.work = {
#       address = "someone@example.com";
#       realName = "Some One";
#       flavor = "gmail.com";        # sets imap/smtp hosts for you
#       passwordSecret = "mail_work"; # -> /var/run/secrets/mail_work
#       primary = true;               # exactly one account must set this
#     };
#   }

{
  config,
  lib,
  pkgs,
  ...
}:
let
  privatePath = "${config.home.homeDirectory}/.config/nix-secrets/mail-accounts.nix";
  private =
    if builtins.pathExists privatePath then
      import privatePath { inherit lib pkgs; }
    else
      { accounts = { }; };

  mailAccounts = private.accounts or { };
  enable = mailAccounts != { };

  # The primary account first, everything else after it.
  #
  # mu4e picks a context by asking each one's match-func about a message, and
  # at startup there is no message -- so the choice falls to
  # `mu4e-context-policy', which is set to `pick-first' below so that starting
  # mail in the background never stops to ask. First is therefore the account
  # a reply with no context behind it is sent from, and alphabetical order has
  # no opinion about which account that should be. This does.
  orderedNames =
    let
      byPrimary = lib.partition (n: mailAccounts.${n}.primary or false) (lib.attrNames mailAccounts);
    in
    byPrimary.right ++ byPrimary.wrong;

  maildir = "${config.home.homeDirectory}/Mail";

  # mbsync and msmtp both take the password from a command rather than...

  # mbsync and msmtp both take the password from a command rather than a file
  # they read themselves, which keeps the secret out of every generated config
  # in the nix store -- those are world-readable.

  toAccount =
    _name: a:
    {
      inherit (a) address realName;
      primary = a.primary or false;
      flavor = a.flavor or "plain";
      userName = a.userName or a.address;
      passwordCommand = "cat /var/run/secrets/${a.passwordSecret}";

      mbsync = {
        enable = true;
        create = "maildir";
        expunge = "both";
        patterns = a.patterns or [ "*" ];
      };
      msmtp.enable = true;
      mu.enable = true;
    }
    // (a.extra or { });
in
lib.mkIf enable {
  programs.mbsync.enable = true;
  programs.msmtp.enable = true;
  programs.mu.enable = true;

  programs.emacs.extraPackages = epkgs: [ epkgs.mu4e ];

  # mu4e, with one context per account.
  #
  # Contexts are generated from the same private list as the mbsync channels,
  # so no address appears here either -- switching context is what picks the
  # right From, the right sent folder and the right msmtp account.
  #
  # mu4e-change-filenames-when-moving is not optional with mbsync: mbsync
  # tracks messages by filename, and mu4e's default of preserving names on
  # move makes the next sync see a duplicate and resurrect the message.
  programs.emacs.extraConfig = ''
    (setq mu4e-maildir "${maildir}"
          mu4e-get-mail-command "${pkgs.isync}/bin/mbsync -a"
          ;; mbsync alone is not enough: the launchd agent pulls new mail into
          ;; the Maildir every 15 minutes, but nothing indexes it, so mu4e
          ;; keeps showing the store as it was when it last looked. This makes
          ;; mu4e run the fetch AND the index itself. Now that mu4e is started
          ;; in the background at the first frame (below), this is the loop
          ;; that runs all day, and the agent is the one that covers the hours
          ;; the daemon is down.
          mu4e-update-interval 300
          ;; Every one of those updates would otherwise narrate itself in the
          ;; echo area -- "Indexing... checked 41283, updated 2" -- five
          ;; minutes apart, forever, over whatever you were reading. The
          ;; arrival of mail is announced by the banner below; the mechanics
          ;; of fetching it are not news.
          mu4e-hide-index-messages t
          ;; Never stop to ask which account this is.
          ;;
          ;; The default is `ask-if-none', and with no context yet and no
          ;; message to match against, starting mu4e in the background would
          ;; open with a prompt -- in the minibuffer, in whatever frame
          ;; happened to be in front, seconds after login. `pick-first' takes
          ;; the head of `mu4e-contexts', which is why the list above is built
          ;; with the primary account first.
          mu4e-context-policy 'pick-first
          mu4e-change-filenames-when-moving t
          mu4e-completing-read-function #'completing-read
          mu4e-confirm-quit nil
          mu4e-headers-date-format "%d/%m/%y"
          message-send-mail-function #'message-send-mail-with-sendmail
          sendmail-program "${pkgs.msmtp}/bin/msmtp"
          message-sendmail-f-is-evil t
          message-sendmail-extra-arguments '("--read-envelope-from"))

    ;; after-load, because make-mu4e-context does not exist until mu4e is
    ;; loaded -- calling it at init time aborts the whole init file with
    ;; "Symbol's function definition is void". mu4e is autoloaded, so this
    ;; runs when `mu4e' first opens, before it reads mu4e-contexts.
    (with-eval-after-load 'mu4e
      (setq mu4e-contexts
            (list
    ${
      lib.concatMapStringsSep "\n" (
        name:
        let
          a = mailAccounts.${name};
        in
        ''
          (make-mu4e-context
           :name "${name}"
           :match-func
           (lambda (msg)
             (when msg
               (string-prefix-p "/${name}" (mu4e-message-field msg :maildir))))
           :vars '((user-mail-address . "${a.address}")
                   (user-full-name    . "${a.realName}")
                   (mu4e-sent-folder   . "/${name}/Sent")
                   (mu4e-drafts-folder . "/${name}/Drafts")
                   (mu4e-trash-folder  . "/${name}/Trash")))''
      ) orderedNames
    })))

    ;; One inbox across every account.
    ;;
    ;; mu4e is per-context by default: switching account switches what you are
    ;; looking at, which is the wrong shape when the question is "is there
    ;; anything to answer" rather than "what did this address receive". The
    ;; query is built from the same private list as the contexts, so no address
    ;; appears here either -- only the folder names, which are all `Inbox'.
    (setq mu4e-bookmarks
          '((:name "All inboxes"  :key ?i
             :query "${
               lib.concatMapStringsSep " or " (name: "maildir:/${name}/Inbox") (lib.attrNames mailAccounts)
             }")
            (:name "Unread"       :key ?u :query "flag:unread AND NOT flag:trashed")
            (:name "Today"        :key ?t :query "date:today..now AND NOT flag:trashed")
            (:name "Last 7 days"  :key ?w :query "date:7d..now AND NOT flag:trashed")
            (:name "Flagged"      :key ?f :query "flag:flagged AND NOT flag:trashed")
            (:name "Attachments"  :key ?a :query "flag:attach AND NOT flag:trashed")))

    ;; A banner when mail arrives.
    ;;
    ;; mu4e only tells you while it is open, and the badge in the status line
    ;; is a number you have to look at. This is the other direction: the
    ;; message announces itself.
    ;;
    ;; Ids already announced are remembered, so the same message is not
    ;; announced again every time the index is rebuilt -- and the first scan
    ;; after a restart only records what is already unread. Without that,
    ;; starting Emacs with a full inbox would fire a banner per message.
    (defvar my/mail--announced (make-hash-table :test 'equal)
      "Message ids already announced.")

    (defvar my/mail--seeded nil
      "Non-nil once the first scan has recorded what was already unread.")

    (defun my/mail--banner (title body)
      "Post TITLE and BODY through the config's one notification door.

    `my/notify' -- plugins/ui/notifications.nix -- posts from inside Emacs' own
    bundle, so the banner carries Emacs' icon and clicking it raises Emacs. The
    osascript subprocess this used to call is attributed to Script Editor
    instead, which is whose icon every mail banner was wearing; it survives
    there only as the fallback for a session with no graphical frame."
      (my/notify title body))

    (defun my/mail--announce (json)
      "Announce anything in JSON that has not been announced before."
      (let ((messages (ignore-errors (json-parse-string json :object-type 'alist)))
            (fresh nil))
        (when (vectorp messages)
          (seq-doseq (m messages)
            (let ((id (alist-get :message-id m nil nil #'equal)))
              (when (and id (not (gethash id my/mail--announced)))
                (puthash id t my/mail--announced)
                (push m fresh))))
          (when (and my/mail--seeded fresh)
            (if (= 1 (length fresh))
                (let* ((m (car fresh))
                       (from (aref (alist-get :from m nil nil #'equal) 0))
                       (who (or (alist-get :name from nil nil #'equal)
                                (alist-get :email from nil nil #'equal)
                                "someone")))
                  (my/mail--banner
                   who (or (alist-get :subject m nil nil #'equal) "(no subject)")))
              (my/mail--banner
               "Mail" (format "%d new messages" (length fresh)))))
          (setq my/mail--seeded t))))

    (defun my/mail-notify-new ()
      "Look for unread mail and announce whatever is new.
    Asynchronous: this runs on a timer and after every index, and neither
    should ever be waiting on mu."
      (when (executable-find "mu")
        (let ((buffer (generate-new-buffer " *mail-notify*")))
          (make-process
           :name "mail-notify" :buffer buffer :noquery t
           :command (list "mu" "find" "flag:unread AND NOT flag:trashed"
                          "--format=json")
           :sentinel
           (lambda (proc _event)
             (unless (process-live-p proc)
               (let ((out (with-current-buffer (process-buffer proc)
                            (buffer-string))))
                 (kill-buffer (process-buffer proc))
                 (my/mail--announce out))))))))

    ;; Both, because they cover different hours. The hook is immediate but only
    ;; fires while mu4e is open; the timer is what notices mail that the
    ;; fifteen-minute mbsync agent pulled in while it was not.
    (add-hook 'mu4e-index-updated-hook #'my/mail-notify-new)
    (run-with-timer 30 180 #'my/mail-notify-new)

    ;; Mail that arrives without being asked for.
    ;;
    ;; `mu4e-update-interval' only means anything while mu4e is running, and
    ;; nothing ran it: the fetch loop began when the mailbox was opened and
    ;; stopped when it was quit, so on a day mu4e was never opened the only
    ;; thing pulling mail was the quarter-hourly agent. This starts mu4e with
    ;; the first frame instead -- `mu4e' with a non-nil argument is mu4e's own
    ;; "start the server and the update timer, do not show the main view", so
    ;; there is nothing to look at unless you ask for it.
    ;;
    ;; The first fetch is immediate: mu4e's update timer is created with a
    ;; delay of 0, so the inbox is current by the time you first look at it.
    (defun my/mail-start-in-background ()
      "Start mu4e without showing it, so mail keeps arriving on its own."
      (unless (bound-and-true-p mu4e--started)
        (mu4e t)))

    (add-hook 'my/startup-hook #'my/mail-start-in-background)

    ;; Jumping straight at one account's inbox, for when the question is the
    ;; other one.
    ;;
    ;; Numbered rather than keyed by initial: two of these accounts begin with
    ;; the same letter, and mu4e takes the last of a duplicate pair, so one of
    ;; them would have had no shortcut at all.
    (setq mu4e-maildir-shortcuts
          '(${
            lib.concatStringsSep "\n            " (
              lib.imap1 (i: name: ''(:maildir "/${name}/Inbox" :key ?${toString i})'') (
                lib.attrNames mailAccounts
              )
            )
          }))
  '';

  accounts.email = {
    maildirBasePath = maildir;
    accounts = lib.mapAttrs toAccount mailAccounts;
  };

  # services.mbsync is Linux-only (it asserts the platform and builds a...

  # services.mbsync is Linux-only (it asserts the platform and builds a systemd
  # timer), so darwin gets the same launchd shape as the restic agent: every 15
  # minutes, background priority, logs where you can find them.

  launchd.agents.mbsync = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.writeShellScript "mbsync-and-index" ''
          # Nothing to do while mu4e has the store open.
          #
          # mu4e is started with the first Emacs frame now, and it fetches
          # every five minutes against this agent's fifteen -- so for as long
          # as the daemon is up this agent has nothing to add, and running
          # anyway is worse than idling. Two mbsyncs over one Maildir contend
          # for the per-channel lock and the loser aborts, and a second
          # indexer fights mu4e's own for the write lock.
          #
          # What is left is the case this agent exists for: the hours the
          # daemon is down, when it is the only thing pulling mail in and the
          # only thing keeping the index current. Without the index step the
          # Maildir grows while mu's view of it does not, and everything
          # reading that index -- the dashboard count, the status-bar badge --
          # reports the store as mu last saw it.
          if ${pkgs.procps}/bin/pgrep -f "mu server" >/dev/null 2>&1; then
            exit 0
          fi

          ${pkgs.isync}/bin/mbsync -a
          ${pkgs.mu}/bin/mu index --quiet || true
        ''}"
      ];
      RunAtLoad = true;
      StartInterval = 900;
      ProcessType = "Background";
      LowPriorityIO = true;
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/mbsync.out.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/mbsync.err.log";
    };
  };
}
