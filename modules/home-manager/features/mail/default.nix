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
          ;; mu4e run the fetch AND the index itself while it is open. The
          ;; agent still earns its place for the hours Emacs is closed -- the
          ;; next update indexes whatever it collected.
          mu4e-update-interval 300
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
      lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: a: ''
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
                   (mu4e-trash-folder  . "/${name}/Trash")))'') mailAccounts
      )
    })))
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
          ${pkgs.isync}/bin/mbsync -a
          # Index what was just fetched. Without this the Maildir grows while
          # mu's view of it does not, so everything reading the index -- the
          # dashboard count, the status-bar badge -- reports the store as mu
          # last saw it, which stays wrong for as long as Emacs is closed.
          #
          # Skipped while mu4e holds the server open: mu4e indexes on its own
          # timer, and a second indexer fights it for the write lock. With
          # Emacs closed there is no contention, and this is then the only
          # thing keeping the index current.
          if ! ${pkgs.procps}/bin/pgrep -f "mu server" >/dev/null 2>&1; then
            ${pkgs.mu}/bin/mu index --quiet || true
          fi
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
