# YNAB, without the bank connection

# What YNAB actually gives you is four things: envelopes you assign money to, a
# fast way to record what you spent, a view of how each envelope is doing this
# month, and a projection of where the balance is heading. None of them need a
# bank feed -- the feed only saves typing, and it is also the part that costs a
# subscription and hands a third party read access to every account.

# hledger has all four. Envelopes are periodic transactions and the report is
# ~balance --budget~; projections are ~--forecast~, which replays those same
# periodic transactions into the future rather than running a separate model.
# So one declaration of "rent is 900 a month" is at once the envelope, the
# budget line and the forecast, and they cannot drift apart. That is the one
# place this is structurally better than YNAB, where the budget and any
# projection are separate screens maintained separately.

# What is genuinely lost: no automatic import, so transactions get typed. In
# practice that is ~SPC $ a~ and about fifteen seconds, and the side effect is
# that every expense gets looked at once -- which is most of what YNAB's method
# is for.

{
  config,
  lib,
  pkgs,
  ...
}:
let
  financeDir = "${config.home.homeDirectory}/finance";

  # Three files, because they answer three different questions

  # ~journal.hledger~ is what happened: append-only in practice, and the only one
  # that grows. ~budget.hledger~ is what is supposed to happen every month, and it
  # is the file you actually open when re-budgeting. ~accounts.hledger~ is the
  # chart of accounts, kept separate so ~hledger check accounts~ can reject a typo
  # rather than silently opening a new envelope called ~expenses:grocerys~.

  # They are seed files rather than store paths: this is data that gets edited
  # every week, and ~home.file~ would make it read-only and clobber those edits on
  # the next rebuild. Written once if absent, then never touched again -- the same
  # reasoning as the readeck secret and the Wallapop searches.

  seeds = {
    "accounts.hledger" = pkgs.writeText "accounts.hledger" ''
      ; Chart of accounts. `hledger check accounts' fails on anything not
      ; listed here, which is what turns a typo into an error instead of an
      ; accidental new envelope.

      account assets:checking
      account assets:savings
      account assets:cash

      account liabilities:card

      account income:salary
      account income:other

      account expenses:housing:rent
      account expenses:housing:utilities
      account expenses:groceries
      account expenses:eating-out
      account expenses:transport
      account expenses:health
      account expenses:subscriptions
      account expenses:gear
      account expenses:fun
      account expenses:other

      account equity:opening
    '';

    "budget.hledger" = pkgs.writeText "budget.hledger" ''
      ; The envelopes. Each `~ monthly' block is at once the budget line that
      ; `hledger balance --budget' reports against and the transaction that
      ; `--forecast' replays into the future, so there is one number to change
      ; when an envelope changes rather than two that can disagree.
      ;
      ; These are what you intend to spend, not what you did.
      ;
      ; Income is declared the same way, and it has to be: --forecast replays
      ; whatever is here and nothing else, so a budget listing only outgoings
      ; projects the balance falling by the whole budget every month forever.
      ; The first thing to correct below is this number.

      ~ monthly  expected income
          assets:checking                2000 EUR
          income:salary

      ~ monthly  planned spending
          expenses:housing:rent           900 EUR
          expenses:housing:utilities      120 EUR
          expenses:groceries              350 EUR
          expenses:eating-out             150 EUR
          expenses:transport               60 EUR
          expenses:subscriptions           40 EUR
          expenses:fun                    100 EUR
          assets:checking
    '';

    "journal.hledger" = pkgs.writeText "journal.hledger" ''
      include accounts.hledger
      include budget.hledger

      ; Opening balances. Replace the zeroes with what is actually in each
      ; account today; everything after this line gets recorded as it happens.
      2026-01-01 opening balances
          assets:checking          0 EUR
          assets:savings           0 EUR
          liabilities:card         0 EUR
          equity:opening
    '';
  };
in
{
  home.packages = [ pkgs.hledger ];

  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      hledger-mode
    ];

  home.activation.financeJournal = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    ''
      run mkdir -p "${financeDir}"
    ''
    + lib.concatStrings (
      lib.mapAttrsToList (name: source: ''
        if [ ! -e "${financeDir}/${name}" ]; then
          run cp ${source} "${financeDir}/${name}"
          run chmod 644 "${financeDir}/${name}"
        fi
      '') seeds
    )
  );

  # The Emacs side

  # hledger-mode brings the major mode: highlighting, amount alignment, and
  # completion over the accounts already in the file. Everything below is the YNAB
  # verbs on top of it -- each one a report you would otherwise have to remember
  # the flags for.

  # Reports render through ~my/hledger--report~ rather than ~compile~. These are
  # output to read, not builds to navigate, and a compilation buffer would offer
  # to recompile them and go hunting for error patterns in a balance sheet.

  programs.emacs.extraConfig = ''
    (setq hledger-jfile "${financeDir}/journal.hledger"
          hledger-currency-string "EUR")

    (defvar my/hledger-dir "${financeDir}"
      "Where the journal, the envelopes and the chart of accounts live.")

    (defun my/hledger--binary ()
      (or (executable-find "hledger") "hledger"))

    (defun my/hledger--report (name &rest args)
      "Run hledger with ARGS and show the output in a buffer called NAME."
      (let ((buffer (get-buffer-create name))
            (default-directory my/hledger-dir))
        (with-current-buffer buffer
          (let ((inhibit-read-only t))
            (erase-buffer)
            (insert (format "hledger %s\n\n" (string-join args " ")))
            (apply #'call-process (my/hledger--binary) nil t nil
                   "-f" hledger-jfile args))
          (goto-char (point-min))
          (special-mode))
        (pop-to-buffer buffer)))

    (defun my/hledger--period (prefix)
      "Report period: this month, or whatever PREFIX asks for.
    A plain call means the current month, which is the question almost every
    time; C-u prompts, so \"last month\" or \"2026-03\" needs no second command."
      (if prefix (read-string "Period (e.g. last month, 2026-03): ") "this month"))

    (defun my/hledger--accounts ()
      "Every account hledger knows about, for completion."
      (let ((default-directory my/hledger-dir))
        (split-string
         (with-output-to-string
           (with-current-buffer standard-output
             (call-process (my/hledger--binary) nil t nil
                           "-f" hledger-jfile "accounts")))
         "\n" t)))

    (defun my/hledger-journal ()
      "Open the journal -- the file every transaction gets appended to."
      (interactive)
      (find-file hledger-jfile))

    (defun my/hledger-budget-file ()
      "Open the envelopes. This is the file to edit when re-budgeting."
      (interactive)
      (find-file (expand-file-name "budget.hledger" my/hledger-dir)))

    (defun my/hledger-accounts-file ()
      "Open the chart of accounts."
      (interactive)
      (find-file (expand-file-name "accounts.hledger" my/hledger-dir)))

    ;;; ------------------------------------------------------------------
    ;;; Recording a transaction
    ;;;
    ;;;
    ;;; The one thing that has to be fast, because it is the one thing done daily and
    ;;; the whole system is worthless the moment it stops being done. Four prompts,
    ;;; all completing over what is already in the journal, and the entry is appended
    ;;; and saved without opening the file.
    ;;;
    ;;; Written to the buffer rather than the file on disk: if the journal is already
    ;;; open and modified, appending behind Emacs' back would lose whichever copy got
    ;;; written second.
    ;;;
    ;;; Income is the same command with the signs the other way round, so there is one
    ;;; flow to remember rather than two.

    (defun my/hledger--append (lines)
      "Append LINES to the journal buffer and save it."
      (with-current-buffer (find-file-noselect hledger-jfile)
        (save-excursion
          (goto-char (point-max))
          (unless (bolp) (insert "\n"))
          (insert "\n" lines))
        (save-buffer)))

    (defun my/hledger--entry (date payee debit credit amount)
      (format "%s %s\n    %-34s %8.2f EUR\n    %s\n"
              date payee debit amount credit))

    (defun my/hledger-add (&optional income)
      "Record a transaction. With a prefix argument, record INCOME instead.

    Expense: money leaves an asset or arrives on a card, and lands in an
    expenses: account. Income is the same entry with the two sides swapped."
      (interactive "P")
      (let* ((accounts (my/hledger--accounts))
             (date (read-string "Date: " (format-time-string "%Y-%m-%d")))
             (payee (read-string (if income "From: " "Payee: ")))
             (category (completing-read (if income "Income account: " "Category: ")
                                        accounts nil nil
                                        (if income "income:" "expenses:")))
             (amount (abs (read-number "Amount (EUR): ")))
             (account (completing-read (if income "Into: " "Paid from: ")
                                       accounts nil nil "assets:")))
        (my/hledger--append
         (if income
             (my/hledger--entry date payee account category amount)
           (my/hledger--entry date payee category account amount)))
        (message "%s  %s  %.2f EUR  %s"
                 date payee amount (if income category account))))

    (defun my/hledger-transfer ()
      "Move money between two accounts you own -- checking to savings, a card
    payment. Not an expense: nothing left the balance sheet."
      (interactive)
      (let* ((accounts (my/hledger--accounts))
             (date (read-string "Date: " (format-time-string "%Y-%m-%d")))
             (from (completing-read "From: " accounts nil nil "assets:"))
             (to (completing-read "To: " accounts nil nil "assets:"))
             (amount (abs (read-number "Amount (EUR): "))))
        (my/hledger--append (my/hledger--entry date "transfer" to from amount))
        (message "%s  %.2f EUR  %s -> %s" date amount from to)))

    ;;; ------------------------------------------------------------------
    ;;; The reports
    ;;;
    ;;;
    ;;; ~--budget~ is the envelope view and the one worth looking at most: each line
    ;;; is spent against budgeted, and hledger marks the ones that are over. ~--tree~
    ;;; because envelopes nest -- housing is rent plus utilities, and the total is the
    ;;; number you care about when deciding whether housing is the problem.
    ;;;
    ;;; The forecast deserves a note. ~--forecast~ replays the periodic transactions
    ;;; from ~budget.hledger~ forward from the last real transaction, so the projection
    ;;; is literally the budget carried on into the future. If it looks wrong, the
    ;;; budget is wrong: there is no second set of assumptions to check.

    (defun my/hledger-budget (&optional prefix)
      "Envelopes: spent against budgeted, this month. C-u for another period."
      (interactive "P")
      (my/hledger--report "*hledger budget*"
                          "balance" "--budget" "--tree" "--no-total"
                          "-p" (my/hledger--period prefix)))

    (defun my/hledger-forecast ()
      "Where the balances are heading, with the envelopes replayed forward.
    Six months by default -- far enough to see a problem, near enough that the
    assumptions still hold."
      (interactive)
      (let ((end (read-string "Project until: "
                              (format-time-string
                               "%Y-%m-%d"
                               (time-add (current-time) (days-to-time 182))))))
        (my/hledger--report "*hledger forecast*"
                            "balance" "--forecast" "--tree"
                            "assets" "liabilities"
                            "-e" end "-M")))

    (defun my/hledger-spending (&optional prefix)
      "Where the money went, by category, month by month.
    Twelve months so a category that crept up is visible as a trend rather than
    as one number with nothing to compare it to."
      (interactive "P")
      (my/hledger--report "*hledger spending*"
                          "balance" "expenses" "--tree" "-M"
                          "-p" (if prefix
                                   (read-string "Period: ")
                                 "last 12 months")))

    (defun my/hledger-networth ()
      "What is owned against what is owed, month by month."
      (interactive)
      (my/hledger--report "*hledger net worth*"
                          "balancesheet" "--tree" "-M" "-p" "last 12 months"))

    (defun my/hledger-income (&optional prefix)
      "In against out for the period -- whether the month actually worked."
      (interactive "P")
      (my/hledger--report "*hledger income*"
                          "incomestatement" "--tree"
                          "-p" (my/hledger--period prefix)))

    (defun my/hledger-register ()
      "Every movement through one account, most recent last."
      (interactive)
      (my/hledger--report "*hledger register*"
                          "register"
                          (completing-read "Account: " (my/hledger--accounts))))

    (defun my/hledger-check ()
      "Check the journal before trusting a report.

    `accounts' rejects anything not in the chart of accounts, which is how a
    misspelled category gets caught rather than quietly becoming a new one.
    `balanced' catches an entry that does not add up.

    `ordereddates' is deliberately not checked. `my/hledger-add' appends, and
    recording yesterday's coffee this morning puts the file out of date order
    immediately -- so it would fail almost always, for something that is not
    a problem. hledger does not care about the order."
      (interactive)
      (my/hledger--report "*hledger check*"
                          "check" "accounts" "balanced"))

    (defun my/hledger-command (command)
      "Run an arbitrary hledger COMMAND, for the report with no key."
      (interactive "shledger: ")
      (apply #'my/hledger--report "*hledger*" (split-string-and-unquote command)))
  '';
}
