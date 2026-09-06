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

  # Every figure below is a round, invented placeholder, and it stays that way.
  # This repository is public, so real salaries, real balances and real direct
  # debits do not belong in it -- and unlike a leaked credential there is nothing
  # to rotate afterwards. The actual numbers live only in ~~/finance~, which is
  # backed up (features/backup/restic) but never committed. Editing these seeds to
  # match reality would quietly publish it, so change ~~/finance~ instead: after
  # the first activation these files are never read again.

  seeds = {
    "accounts.hledger" = pkgs.writeText "accounts.hledger" ''
      ; Chart of accounts. `hledger check accounts' fails on anything not
      ; listed here, which is what turns a typo into an error instead of an
      ; accidental new envelope.

      ; Two banks. Rename these to whatever you actually call them -- the
      ; names appear in every report and in the completion list for SPC $ a.
      account assets:bank:main            ; salary lands here, mortgage leaves here
      account assets:bank:second
      account assets:cash

      ; The card is a liability, not a wallet: a purchase on it increases what
      ; is owed and is an expense the day it happens, not the day the bill is
      ; paid. Paying the bill is then a transfer, and budgeting for it as well
      ; would count the same money twice.
      account liabilities:card            ; limit: 2500 EUR

      account income:salary
      account income:other

      account expenses:housing:mortgage
      account expenses:housing:utilities
      account expenses:groceries
      account expenses:eating-out
      account expenses:transport
      account expenses:health
      account expenses:subscriptions
      account expenses:gear
      account expenses:fun
      account expenses:other

      ; A target says what an envelope is adding up to. `goal:' is the total,
      ; `by:' an optional month to reach it, and between those and whether the
      ; account has a periodic transaction in budget.hledger you get the four
      ; shapes a target comes in:
      ;
      ;   periodic only          spend this much every month -- groceries
      ;   periodic + goal        put this aside monthly until the total is
      ;                          reached -- a yearly restock
      ;   periodic + goal + by:  the same, and the screen says what the monthly
      ;                          has to be to arrive on time
      ;   goal only              a total to work toward, topped up whenever
      ;                          there is something spare
      ;
      ; Progress is measured against the rolled-over available, so an envelope
      ; funded and never touched shows the money as set aside rather than as
      ; nothing having happened.
      account expenses:restock            ; goal: 150
      account expenses:insurance          ; goal: 480 by: 2027-06

      account equity:opening
    '';

    "budget.hledger" = pkgs.writeText "budget.hledger" ''
      ; The envelopes. Each periodic transaction is at once the budget line
      ; that `hledger balance --budget' reports against and the transaction
      ; that `--forecast' replays into the future, so there is one number to
      ; change when an envelope changes rather than two that can disagree.
      ;
      ; These are what you intend to spend, not what you did.

      ; Income has to be declared too: --forecast replays what is in this file
      ; and nothing else, so a budget listing only outgoings projects the
      ; balance falling by the whole budget every month, forever.
      ;
      ; TODO: the real net salary and the day it lands.
      ~ every 1st day of month  salary
          assets:bank:main               2000 EUR
          income:salary

      ; Anything fixed, dated and known to the cent belongs in its own periodic
      ; transaction on its own day rather than folded into a category envelope,
      ; so the forecast shows the balance dipping when it actually does.
      ;
      ; Modelled as a pure expense, which is what YNAB does and what makes the
      ; budget read correctly. It does mean net worth ignores the principal
      ; being paid down: to fix that, add `account liabilities:mortgage', split
      ; this into an interest part and a principal part, and open the loan
      ; balance in the journal.
      ~ every 1st day of month  mortgage
          expenses:housing:mortgage     500 EUR
          assets:bank:main

      ; Everything else, monthly. The balancing account is the bank rather
      ; than the card even for things bought on the card: this side of the
      ; budget is about when the money leaves, and the card only delays that
      ; by a few weeks. The forecast ignores that float.
      ~ monthly  planned spending
          expenses:housing:utilities      120 EUR
          expenses:groceries              350 EUR
          expenses:eating-out             150 EUR
          expenses:transport               60 EUR
          expenses:subscriptions           40 EUR
          expenses:fun                    100 EUR
          assets:bank:main
    '';

    "journal.hledger" = pkgs.writeText "journal.hledger" ''
      include accounts.hledger
      include budget.hledger

      ; Opening balances. Replace the zeroes with what is actually in each
      ; account today, and move the date to today -- everything after this
      ; line gets recorded as it happens.
      ;
      ; liabilities:card is negative when you owe money on it.
      2026-09-01 opening balances
          assets:bank:main             0 EUR
          assets:bank:second           0 EUR
          assets:cash                  0 EUR
          liabilities:card             0 EUR
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
          (special-mode)
          (display-line-numbers-mode -1))
        (pop-to-buffer buffer)))

    (defun my/hledger--period (prefix)
      "Report period: this month, or whatever PREFIX asks for.
    A plain call means the current month, which is the question almost every
    time; C-u prompts, so \"last month\" or \"2026-03\" needs no second command."
      (if prefix (read-string "Period (e.g. last month, 2026-03): ") "this month"))

    (defun my/hledger--payees ()
      "Every payee already in the journal, for completion.

    hledger keeps the list, so nothing has to be maintained by hand: type a few
    letters of a shop you have been to and it is there, type a new one and it
    simply becomes part of the list next time."
      (let ((default-directory my/hledger-dir))
        (split-string
         (with-output-to-string
           (with-current-buffer standard-output
             (call-process (my/hledger--binary) nil t nil
                           "-f" hledger-jfile "payees")))
         "\n" t)))

    (defun my/hledger--read-payee (prompt)
      "Read a payee, completing over the ones already used.

    Not require-match: a shop you have never been to before still has to be
    typeable, and the whole point is that it joins the list afterwards."
      (completing-read prompt (my/hledger--payees) nil nil))

    (defun my/hledger--read-date (prompt)
      "Read a date, with a calendar where org provides one.

    org-read-date understands \"yesterday\", \"-3\", \"fri\" and shows a calendar
    to arrow around, which beats typing four digits of year that are almost
    always this one. Falls back to a plain prompt if org is not loaded."
      (if (fboundp 'org-read-date)
          (org-read-date nil nil nil prompt)
        (read-string prompt (format-time-string "%Y-%m-%d"))))

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
             (date (my/hledger--read-date "Date"))
             (payee (my/hledger--read-payee (if income "From: " "Payee: ")))
             (category (completing-read (if income "Income account: " "Category: ")
                                        accounts nil nil
                                        (if income "income:" "expenses:")))
             (amount (abs (read-number "Amount (EUR): ")))
             ;; A default rather than initial input: RET takes the common case
             ;; and typing filters the whole list, where prefilled text has to
             ;; be deleted first. Most spending goes on the card, so that is
             ;; the default; income lands in the bank.
             (account (completing-read
                       (if income "Into (default main): " "Paid from (default card): ")
                       accounts nil nil nil nil
                       (if income "assets:bank:main" "liabilities:card"))))
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
             (date (my/hledger--read-date "Date"))
             (from (completing-read "From (default main): " accounts nil nil nil nil
                                    "assets:bank:main"))
             (to (completing-read "To: " accounts))
             (amount (abs (read-number "Amount (EUR): ")))
             ;; A description, not a payee: nobody is being paid. Defaults to
             ;; the destination's own name, so a register of transfers reads
             ;; "emergency fund" and "mortgage" rather than twenty lines of
             ;; "transfer" that have to be decoded from the accounts.
             (what (my/hledger--read-payee
                    (format "What for (default %s): "
                            (car (last (split-string to ":")))))) )
        (my/hledger--append
         (my/hledger--entry date
                            (if (string-empty-p what)
                                (car (last (split-string to ":")))
                              what)
                            to from amount))
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

    (defcustom my/hledger-card-limit 2500
      "Credit limit, in EUR. hledger has no notion of one, so it lives here."
      :type 'number
      :group 'my/hledger)

    (defun my/hledger--amount (account &optional period)
      "The balance of ACCOUNT over PERIOD, as a float."
      (let ((default-directory my/hledger-dir))
        (string-to-number
         (with-output-to-string
           (with-current-buffer standard-output
             (apply #'call-process (my/hledger--binary) nil t nil
                    "-f" hledger-jfile "balance" account
                    "--format" "%(total)" "--no-total" "-N"
                    (when period (list "-p" period))))))))

    (defun my/hledger-card ()
      "What is on the card and how much of the limit is left."
      (interactive)
      (let* ((owed (abs (my/hledger--amount "liabilities:card")))
             (left (- my/hledger-card-limit owed)))
        (message "Card: %.2f EUR owed, %.2f of %d left (%.0f%% used)"
                 owed left my/hledger-card-limit
                 (* 100 (/ owed (float my/hledger-card-limit))))))

    (defun my/hledger-card-payment ()
      "Pay the card off in full for a month, as a transfer rather than a spend.

    The purchases were already recorded as expenses on the days they happened;
    this only moves the money that settles them, so budgeting for it as well
    would count it twice. Defaults to last month, because that is the bill
    that comes due."
      (interactive)
      (let* ((period (read-string "Pay the balance from which month: " "last month"))
             (owed (abs (my/hledger--amount "liabilities:card" period)))
             (date (my/hledger--read-date "Payment date"))
             (amount (read-number "Amount (EUR): " owed))
             (from (completing-read "Paid from (default main): " (my/hledger--accounts)
                                    nil nil nil nil "assets:bank:main")))
        (my/hledger--append
         (my/hledger--entry date "card payment" "liabilities:card" from amount))
        (message "Card payment %.2f EUR from %s" amount from)))

    ;;; ------------------------------------------------------------------
    ;;; The envelope screen
    ;;;
    ;;; `hledger balance --budget' already says everything, in a table that is
    ;;; correct and hard to read at a glance -- which is the one thing YNAB is
    ;;; genuinely good at. Same numbers, drawn as bars, one row per envelope,
    ;;; with the month on arrow keys.
    ;;;
    ;;; It reads the CSV output rather than scraping the text table: the text
    ;;; one packs spent and budgeted into a single "0 [0% of 350.00 EUR]" cell
    ;;; that would have to be parsed back apart, and its column widths move
    ;;; with the data.
    ;;;
    ;;; Flat, not --tree. A tree adds parent rows that are sums of their
    ;;; children, and on this screen every row should be an envelope you can
    ;;; act on.

    (defvar-local my/hledger-budget--time nil
      "The month the envelope screen is showing.")

    (defcustom my/hledger-budget-bar-width 22
      "Width of the bars on the envelope screen."
      :type 'integer
      :group 'my/hledger)

    (defun my/hledger--csv (&rest args)
      "Run hledger with ARGS plus -O csv and return a list of field lists.

    The fields of a balance report are account names and amounts, neither of
    which contains a comma or a quote, so splitting on the quoted separator is
    enough and a real CSV reader would be ceremony."
      (let ((default-directory my/hledger-dir))
        (delq nil
              (mapcar
               (lambda (line)
                 (when (string-prefix-p "\"" line)
                   (split-string (substring line 1 (1- (length line))) "\",\"")))
               (split-string
                (with-output-to-string
                  (with-current-buffer standard-output
                    (apply #'call-process (my/hledger--binary) nil t nil
                           "-f" hledger-jfile (append args '("-O" "csv")))))
                "\n" t)))))

    (defun my/hledger--goals ()
      "Targets, read off the chart of accounts.

    hledger has no notion of one, so it lives where the account is declared --
    `account expenses:insurance  ; goal: 480 by: 2027-03' -- rather than in a
    second file that could disagree with the first. hledger ignores the
    comment, so nothing about what the reports compute changes.

    Returns an alist of account to (AMOUNT . BY), BY being a YYYY-MM string or
    nil. Between this and whether the account has a periodic transaction, the
    four shapes a target comes in are all expressible:

      periodic only            spend this much every month
      periodic + goal          put this much aside monthly until the total is
                               reached -- the yearly insurance, the restock
      periodic + goal + by     the same, but the screen says what the monthly
                               has to be to arrive on time
      goal only                a total to work toward, topped up whenever
                               there is something spare"
      (let ((file (expand-file-name "accounts.hledger" my/hledger-dir))
            (goals nil))
        (when (file-readable-p file)
          (with-temp-buffer
            (insert-file-contents file)
            (goto-char (point-min))
            (while (re-search-forward
                    "^account +\\([^ ;\n]+\\).*;.*goal: *\\([0-9.]+\\)" nil t)
              (let ((account (match-string 1))
                    (amount (string-to-number (match-string 2)))
                    (by (save-excursion
                          (goto-char (line-beginning-position))
                          (when (re-search-forward "by: *\\([0-9]\\{4\\}-[0-9]\\{2\\}\\)"
                                                   (line-end-position) t)
                            (match-string 1)))))
                (push (cons account (cons amount by)) goals)))))
        goals))

    (defun my/hledger--months-until (ym now)
      "Whole months from NOW to the first of YM, at least one."
      (let* ((target (parse-time-string (concat ym "-01 00:00:00")))
             (here (decode-time now)))
        (max 1 (+ (* 12 (- (nth 5 target) (nth 5 here)))
                  (- (nth 4 target) (nth 4 here))))))

    (defun my/hledger--goal-line (account progress monthly now &optional depth)
      "The target line under an envelope, or nil when it has no target.

    PROGRESS is what has accumulated toward it -- for an envelope that is the
    rolled-over available, because money not yet spent is money still set
    aside; MONTHLY is what the budget puts in each month."
      (when-let* ((goal (alist-get account (my/hledger--goals) nil nil #'equal))
                  (amount (car goal))
                  (_ (> amount 0)))
        (let* ((by (cdr goal))
               (short (max 0 (- amount progress)))
               (note (cond
                      ;; A date changes the question from "how long at this
                      ;; rate" to "what does the rate have to be", which is the
                      ;; only one worth answering when the date is fixed.
                      (by (let ((months (my/hledger--months-until by now)))
                            (if (<= short 0)
                                (format "funded, %s" by)
                              (format "%.0f/mo to %s" (/ short months) by))))
                      ((and monthly (> monthly 0))
                       (if (<= short 0) "funded"
                         (format "%d mo left" (ceiling (/ short monthly)))))
                      (t "no monthly set"))))
          (propertize
           (format "  %-26s %9.2f / %-9.0f %s %5s  %s\n"
                   (concat (make-string (* 2 (1+ (or depth 0))) ?\s) "toward target")
                   progress amount
                   (my/hledger-budget--bar (/ progress (float amount)))
                   (my/hledger--percent progress amount)
                   note)
           'face 'shadow))))

    (defun my/hledger--account-tag (account tag)
      "Read a numeric TAG off ACCOUNT's directive in the chart of accounts."
      (let ((file (expand-file-name "accounts.hledger" my/hledger-dir)))
        (when (file-readable-p file)
          (with-temp-buffer
            (insert-file-contents file)
            (goto-char (point-min))
            (when (re-search-forward
                   (format "^account +%s\\b.*;.*%s: *\\(-?[0-9.]+\\)"
                           (regexp-quote account) (regexp-quote tag))
                   nil t)
              (string-to-number (match-string 1)))))))

    (defun my/hledger--amortise (balance monthly-rate payment)
      "Months to clear BALANCE at PAYMENT, or nil if the payment never will."
      (let ((b balance) (n 0))
        (while (and (> b 0.01) (< n 2000))
          (let ((interest (* b monthly-rate)))
            (when (<= payment interest) (setq n nil b 0))
            (when n (setq b (- (+ b interest) payment) n (1+ n)))))
        n))

    (defun my/hledger--payment-for (balance monthly-rate months)
      "The level payment that clears BALANCE in MONTHS."
      (if (zerop monthly-rate) (/ balance months)
        (/ (* balance monthly-rate) (- 1 (expt (+ 1 monthly-rate) (- months))))))

    (defun my/hledger--count-postings (account since)
      "How many postings to ACCOUNT increase what is owed on it, SINCE a date.

    A purchase credits the card, so it lands in the register negative; a
    payment lands positive. Counting only the negatives is what separates
    twelve purchases from twelve monthly settlements."
      (let ((default-directory my/hledger-dir)
            (count 0))
        (with-temp-buffer
          (call-process (my/hledger--binary) nil t nil "-f" hledger-jfile
                        "register" account "-b" since "-O" "csv")
          (goto-char (point-min))
          (forward-line 1)
          (while (not (eobp))
            (let ((fields (split-string
                           (string-trim (thing-at-point 'line t) "\"" "\"?\n?")
                           "\",\"")))
              (when (and (> (length fields) 5)
                         (string-prefix-p "-" (string-trim (nth 5 fields))))
                (setq count (1+ count))))
            (forward-line 1)))
        count))

    (defun my/hledger--last-posting-date (account)
      "The date of the most recent posting to ACCOUNT, or nil."
      (let ((default-directory my/hledger-dir))
        (with-temp-buffer
          (call-process (my/hledger--binary) nil t nil "-f" hledger-jfile
                        "register" account "-O" "csv")
          (goto-char (point-max))
          (forward-line -1)
          (let ((fields (split-string
                         (string-trim (or (thing-at-point 'line t) "") "\"" "\"?\n?")
                         "\",\"")))
            (when (and (> (length fields) 1)
                       (string-match "\\`[0-9]\\{4\\}-" (nth 1 fields)))
              (nth 1 fields))))))

    (defun my/hledger--bonifications ()
      "The state of the conditions the mortgage rate depends on.

    None of them is a live risk as things stand: the salary arrives on its own,
    and the gym subscription alone is twelve card purchases a year, so the
    count is satisfied before any other spending is considered.

    It is here as a tripwire rather than a worry -- for the year the gym is
    cancelled, or the salary starts landing somewhere else. 0.17 points is not
    a large number until it is applied to sixty-six thousand euros for
    twenty-five years, and nothing about losing it would announce itself."
      (let* ((year (format-time-string "%Y-01-01"))
             (purchases (my/hledger--count-postings "liabilities:card" year))
             (salary (my/hledger--last-posting-date "income:salary")))
        (list (list "life insurance" t "budgeted monthly")
              (list "house insurance" t "budgeted monthly")
              (list "12 card purchases" (>= purchases 12)
                    (format "%d so far in %s" purchases (format-time-string "%Y")))
              (list "salary into the account" (and salary t)
                    (if salary (concat "last seen " salary) "none recorded")))))

    (defun my/hledger--year-total (query year)
      "The total of QUERY over calendar YEAR, as a positive number."
      (abs (my/hledger--amount query (format "%d-01-01..%d-12-31" year year))))

    (defun my/hledger--salary-months (year)
      "The months of YEAR that have a payslip, as a list of (GROSS IRPF SS).

    Read off the monthly matrix and filtered to the months that actually have
    a salary. The matrix always returns twelve columns, the later ones empty,
    which is the trap: the last column is December whether or not December has
    happened, so taking it as the run rate reads zero every time."
      (let* ((m (my/hledger--matrix "balance" "^income:salary" "^expenses:tax:irpf"
                                    "^expenses:tax:social-security"
                                    "-b" (format "%d-01-01" year)
                                    "-e" (format "%d-01-01" (1+ year))))
             (row (lambda (a) (cdr (assoc a (cdr m)))))
             (gross (funcall row "income:salary"))
             (irpf (funcall row "expenses:tax:irpf"))
             (ss (funcall row "expenses:tax:social-security"))
             (out nil))
        (dotimes (i (length gross))
          (let ((g (abs (or (nth i gross) 0))))
            (when (> g 0)
              (push (list g (abs (or (nth i irpf) 0)) (abs (or (nth i ss) 0))) out))))
        (nreverse out)))

    (defun my/hledger--run-rate (months)
      "The ordinary month to project the rest of the year from.

    The most recent one, unless it is a bonus month -- projecting a bonus into
    every remaining month would roughly double the estimate. Anything more
    than a quarter above the median is treated as a bonus and the median month
    is used instead."
      (if (null months) (list 0.0 0.0 0.0)
        (let* ((grosses (sort (mapcar #'car months) #'<))
               (median (nth (/ (length grosses) 2) grosses))
               (latest (car (last months))))
          (if (> (car latest) (* 1.25 median))
              (seq-find (lambda (m) (<= (car m) (* 1.25 median))) (reverse months) latest)
            latest))))

    (defun my/hledger-renta (&optional year)
      "Estimate the AEAT settlement for YEAR from the payslips in the journal.

    Spain settles income tax a year in arrears: what is withheld monthly is an
    estimate, and the following June the difference is charged or refunded. The
    bill is therefore knowable long before it arrives, provided the payslips
    have been recorded with their three parts -- what was earned, what was
    withheld for IRPF, and what went to Seguridad Social.

    The model is a straight line fitted to two settled years, and it is a
    straight line for a reason: two points cannot describe a progressive tax
    system, only the slope between them. It is accurate near that income and
    increasingly wrong away from it. The coefficients live on the account so a
    third settled year can improve them:

      account expenses:tax:renta  ; marginal: 43.99  offset: -8444.67

    What it cannot know: anything outside the payslips. Deductions, a second
    income, a joint return, regional variations -- none of that is here, and
    any of it moves the answer. It is a forecast to save for against, not a
    figure to file."
      (interactive)
      (let* ((year (or year (string-to-number (format-time-string "%Y"))))
             (marginal (or (my/hledger--account-tag "expenses:tax:renta" "marginal") 0))
             (offset (or (my/hledger--account-tag "expenses:tax:renta" "offset") 0))
             (payslips (my/hledger--salary-months year))
             (recorded (length payslips))
             (so-far (my/hledger--year-total "^income:salary" year))
             (held-so-far (my/hledger--year-total "^expenses:tax:irpf" year))
             (ss-so-far (my/hledger--year-total "^expenses:tax:social-security" year))
             ;; Project the rest of the year at the most recent month's rate.
             ;; Deliberately without a bonus: one may not come, and a forecast
             ;; that quietly assumes one is how a bill becomes a surprise.
             (last-month (my/hledger--run-rate payslips))
             (left (max 0 (- 12 recorded)))
             (gross (+ so-far (* left (nth 0 last-month))))
             (withheld (+ held-so-far (* left (nth 1 last-month))))
             (social (+ ss-so-far (* left (nth 2 last-month))))
             (taxable (- gross social))
             (liability (+ (* (/ marginal 100.0) taxable) offset))
             (settlement (- liability withheld))
             (buffer (get-buffer-create "*renta*")))
        (with-current-buffer buffer
          (let ((inhibit-read-only t))
            (erase-buffer)
            (insert (format "  Income tax, %d -- settled June %d\n\n" year (1+ year)))
            (if (zerop gross)
                (progn
                  (insert "  No payslips recorded for this year.\n\n")
                  (insert "  Record them in full and this fills itself in: income:salary\n")
                  (insert "  for the gross, expenses:tax:irpf for what was withheld,\n")
                  (insert "  expenses:tax:social-security, and the benefit in kind.\n"))
              (insert (format "  recorded so far    %10.2f   over %d month%s\n"
                              so-far recorded (if (= recorded 1) "" "s")))
              (when (> left 0)
                (insert (format "  projected to Dec   %10.2f   %d more at %.2f, no bonus assumed\n"
                                gross left (nth 0 last-month))))
              (insert (format "  Seguridad Social   %10.2f\n" social))
              (insert (format "  taxable            %10.2f\n\n" taxable))
              (insert (format "  tax due            %10.2f   at %.2f%% marginal\n"
                              liability marginal))
              (insert (format "  already withheld   %10.2f\n" withheld))
              (insert (format "  %-18s %10.2f\n\n"
                              (if (> settlement 0) "TO PAY next June" "refund next June")
                              (abs settlement)))
              (insert (format "  Set aside %.2f a month from now until June to cover it.\n"
                              (/ (max 0 settlement) 9.0)))
              ;; What one more bonus would do to the answer, because that is
              ;; the single thing most likely to move it.
              (when (> left 0)
                (let* ((bonus 4500.0)
                       (with-bonus (- (+ (* (/ marginal 100.0) (+ taxable bonus)) offset)
                                      (+ withheld (* bonus 0.249)))))
                  (insert (format "  A December bonus of 4,500 would make it %.2f.\n"
                                  with-bonus))))
              (insert "\n  Two settled years fitted with a straight line: accurate near\n")
              (insert "  this income, less so away from it, and blind to anything the\n")
              (insert "  payslips do not show. A forecast to save against, not a return.\n")))
          (goto-char (point-min))
          (special-mode)
          (display-line-numbers-mode -1))
        (pop-to-buffer buffer)))

    (defun my/hledger-mortgage ()
      "Where the mortgage stands, and what finishing early costs per month.

    The rate is read from the chart of accounts. Everything below is only as
    good as that number, and a variable-rate loan will drift from it, so the
    statement is the thing that settles it."
      (interactive)
      (let* ((balance (abs (my/hledger--amount "liabilities:mortgage")))
             (original (or (my/hledger--account-tag "liabilities:mortgage" "original") 0))
             (annual (or (my/hledger--account-tag "liabilities:mortgage" "rate") 0))
             (r (/ (expt (+ 1 (/ annual 100.0)) (/ 1.0 12)) 1))
             (r (- r 1))
             (payment (or (my/hledger--account-tag "liabilities:mortgage" "payment") 0))
             (left (my/hledger--amortise balance r payment))
             (target (read-number "Finish in how many more months? " 130))
             (needed (my/hledger--payment-for balance r target))
             (buffer (get-buffer-create "*mortgage*")))
        (with-current-buffer buffer
          (let ((inhibit-read-only t))
            (erase-buffer)
            (insert (format "  Mortgage\n\n"))
            (insert (format "  balance        %10.2f of %.2f borrowed   %.1f%% paid off\n"
                            balance original
                            (if (> original 0) (* 100 (/ (- original balance) original)) 0)))
            (insert (format "  rate           %10.3f%% a year, from the chart of accounts\n" annual))
            (insert (format "  payment        %10.2f a month\n\n" payment))
            (if left
                (insert (format "  at that rate   %4d months left (%.1f years), %.2f interest still to pay\n"
                                left (/ left 12.0) (- (* left payment) balance)))
              (insert "  at that rate   the payment does not cover the interest\n"))
            (insert (format "\n  to finish in %d months instead:\n" target))
            (insert (format "    payment      %10.2f a month  (+%.2f)\n" needed (- needed payment)))
            (insert (format "    interest     %10.2f  (%.2f less)\n"
                            (- (* target needed) balance)
                            (- (- (* (or left 0) payment) balance)
                               (- (* target needed) balance))))
            (insert (format "\n  bonifications -- %.2f%% with them, and the cuota is priced at 1.30%%\n"
                            annual))
            (dolist (item (my/hledger--bonifications))
              (insert (format "    %-24s %s  %s\n"
                              (nth 0 item)
                              (if (nth 1 item)
                                  (propertize "ok" 'face 'success)
                                (propertize "AT RISK" 'face 'error))
                              (nth 2 item))))
            (insert "\n  Spanish lenders usually let an overpayment either shorten the term or\n")
            (insert "  cut the monthly payment, and some charge for early amortisation.\n")
            (insert "  Which of those you get is agreed with the bank, not decided here.\n"))
          (goto-char (point-min))
          (special-mode)
          (display-line-numbers-mode -1))
        (pop-to-buffer buffer)))

    (defun my/hledger--num (field)
      "The number in a hledger CSV amount FIELD, which may be a bare 0."
      (string-to-number (or field "0")))

    (defface my/hledger-budget-heading
      '((t :inherit font-lock-keyword-face :weight bold))
      "Face for the month and the column headings."
      :group 'my/hledger)

    (defcustom my/hledger-budget-graphics 'auto
      "Whether the envelope screen draws its bars and trends as images.
    `auto' uses SVG on a graphical frame and characters everywhere else, which
    is what a terminal frame, the echo area and copied-out text get. `text'
    forces the character version."
      :type '(choice (const auto) (const text))
      :group 'my/hledger)

    (defun my/hledger--graphical-p ()
      (and (eq my/hledger-budget-graphics 'auto)
           (display-graphic-p)
           (image-type-available-p 'svg)))

    (defun my/hledger--image (svg columns)
      "SVG as a string COLUMNS wide, so it lines up with the text around it.

    The spaces underneath are not decoration: they are what the buffer falls
    back to when the image cannot be shown, and what ends up on the kill ring
    when a row is copied, so the column has to be the right width either way."
      (propertize (make-string columns ?\s)
                  'display (svg-image svg :ascent 'center)))

    (defun my/hledger--percent (part whole)
      "PART of WHOLE as a percentage, or -- when that would say nothing.
    Anything past 999% is a row where something is wrong with the data rather
    than the spending, and printing six digits of it only hides the rest."
      (if (or (null whole) (<= whole 0)) "--"
        (let ((p (round (* 100 (/ (float part) whole)))))
          (if (> (abs p) 999) ">999%" (format "%d%%" p)))))

    (defun my/hledger--bar-color (fraction)
      (cond ((> fraction 1.0) (my/hledger--color 'error "#b22222"))
            ((> fraction 0.85) (my/hledger--color 'warning "#b8860b"))
            (t (my/hledger--color 'success "#2e8b57"))))

    (defun my/hledger-budget--bar (fraction)
      "A FRACTION of the way along a bar, coloured by how close to over it is."
      (let ((width my/hledger-budget-bar-width))
        (if (not (my/hledger--graphical-p))
            (let ((filled (max 0 (min width (round (* fraction width)))))
                  (face (cond ((> fraction 1.0) 'error)
                              ((> fraction 0.85) 'warning)
                              (t 'success))))
              (concat (propertize (make-string filled ?#) 'face face)
                      (propertize (make-string (- width filled) ?.) 'face 'shadow)))
          (let* ((w (* width (default-font-width)))
                 (h (max 6 (- (default-font-height) 4)))
                 (svg (svg-create w h))
                 (track (my/hledger--color 'shadow "#cccccc"))
                 (fill (my/hledger--bar-color fraction))
                 ;; Over budget is drawn full and red rather than overflowing
                 ;; the track; the percentage next to it already says by how
                 ;; much, and a bar that runs past its own end reads as a
                 ;; rendering fault.
                 (filled (* w (min 1.0 (max 0.0 (float fraction))))))
            (svg-rectangle svg 0 0 w h :fill track :fill-opacity 0.25 :rx 2)
            (when (> filled 0)
              (svg-rectangle svg 0 0 filled h :fill fill :rx 2))
            (my/hledger--image svg width)))))

    (defun my/hledger-budget--with-goals (csv prefix)
      "The rows of CSV, plus any account under PREFIX with a goal and no row.

    A fund with no monthly contribution has neither budget nor activity in a
    quiet month, so `balance --budget' omits it -- and a target you fill from a
    bonus is quiet by definition. It would therefore be invisible in exactly
    the months you want it to nag. Any goal-bearing savings or liability
    account missing from the report is added back with zeroes; the goal line
    underneath still shows the balance and what is left to find."
      (let* ((rows (my/hledger-budget--leaves
                    (seq-remove (lambda (r) (equal (nth 0 r) "Total:")) (cdr csv))))
             (present (mapcar #'car rows)))
        (append rows
                (delq nil
                      (mapcar (lambda (goal)
                                (let ((account (car goal)))
                                  (when (and (string-match-p prefix account)
                                             (not (member account present)))
                                    (list account "0" "0"))))
                              (my/hledger--goals))))))

    (defun my/hledger-budget--saving-rows (csv)
      "Saving and paydown rows, including funds the report left out."
      (my/hledger-budget--with-goals csv "\\`\\(assets:savings\\|liabilities\\)"))

    (defun my/hledger-budget--leaves (rows)
      "ROWS with the aggregates removed.

    hledger emits a parent row per branch -- a bare `expenses', and one per
    subtree -- whose amount is the sum of its children plus anything below it
    with no budget at all. Those are not envelopes, and the unbudgeted part
    they hide is reported on its own line instead."
      (let ((names (mapcar #'car rows)))
        (seq-remove
         (lambda (row)
           (seq-some (lambda (other) (string-prefix-p (concat (car row) ":") other))
                     names))
         rows)))

    (defcustom my/hledger-budget-rollover t
      "Whether an unspent envelope carries its balance into the next month.

    hledger's budget report compares one period at a time and has no notion of
    a leftover, so with this off the screen shows what is left of THIS month
    and a sinking fund can never visibly accumulate -- travel would read 0/50
    every month and then 469/50 the month you book a hotel.

    With it on the column is what YNAB calls available: everything budgeted
    since the journal began, minus everything spent, so an envelope nobody
    touched for three months genuinely has three months in it."
      :type 'boolean
      :group 'my/hledger)

    (defun my/hledger--journal-start ()
      "Where a rollover starts.

    `budget-start:' on equity:opening if it is set, otherwise the first
    transaction. The distinction matters the day a year of history is imported:
    the envelopes were derived FROM that history, so measuring the history
    against them counts it twice and every envelope opens deep in the red. The
    rollover should begin when the budget did, not when the records do.

    It cannot start before the journal either way: --budget generates the
    periodic transactions across whatever range it is given, so reaching back
    further invents budget for months that never happened."
      (or (my/hledger--account-tag-string "equity:opening" "budget-start")
          (let ((default-directory my/hledger-dir))
            (with-temp-buffer
              (call-process (my/hledger--binary) nil t nil "-f" hledger-jfile "stats")
              (goto-char (point-min))
              (if (re-search-forward "^Txns span *: *\\([0-9-]+\\)" nil t)
                  (match-string 1)
                (format-time-string "%Y-01-01"))))))

    ;; Queries are anchored with ^ throughout. hledger matches an account
    ;; query as a substring regex, so a bare "income" also selects
    ;; expenses:tax:income -- which quietly subtracted 159 from the month's
    ;; expected income and made the budget look 159 over.
    (defun my/hledger--available (end)
      "Available per envelope at END: everything budgeted since the journal
    started, less everything spent. An alist of account to a float."
      (let* ((csv (my/hledger--csv
                   "balance" "--budget" "--flat" "^expenses"
                   "-b" (my/hledger--journal-start)
                   "-e" (format-time-string "%Y-%m-01" (time-add end (days-to-time 31)))
                   "--cumulative" "-M"))
             (rows (seq-remove (lambda (r) (equal (car r) "Total:")) (cdr csv))))
        ;; Every month is a pair of columns, actual then budget; the running
        ;; totals mean only the last pair matters.
        (mapcar (lambda (r)
                  (let* ((cells (cdr r))
                         (n (length cells)))
                    (cons (car r)
                          (if (>= n 2)
                              (- (my/hledger--num (nth (- n 1) cells))
                                 (my/hledger--num (nth (- n 2) cells)))
                            0.0))))
                rows)))

    (defvar-local my/hledger-budget--available nil
      "Account to its rolled-over balance, when rollover is on.")

    (defvar-local my/hledger-budget--trends nil
      "Account to its last six monthly totals, for the sparkline column.")

    (defun my/hledger-budget--load-trends (end)
      "Six months of history up to and including END, as an alist."
      (let* ((start (let ((d (decode-time end)))
                      (setf (nth 4 d) (- (nth 4 d) 5))
                      (encode-time d)))
             (matrix (my/hledger--matrix
                      "balance" "^expenses" "--flat"
                      "-b" (format-time-string "%Y-%m-01" start)
                      "-e" (format-time-string "%Y-%m-01"
                                               (time-add end (days-to-time 31))))))
        (cdr matrix)))

    (defun my/hledger-budget--row (account spent budgeted &optional label depth override)
      "One envelope, as a line.
    LABEL overrides the name, DEPTH indents it, OVERRIDE replaces the computed
    remaining -- a group heading has no account of its own to look up, so it is
    handed the sum of its children."
      (let* ((label (or label (replace-regexp-in-string "\\`expenses:?" "" account)))
             (label (if (string-empty-p label) "unbudgeted" label))
             (label (concat (make-string (* 2 (or depth 0)) ?\s) label))
             (fraction (if (> budgeted 0) (/ spent budgeted) (if (> spent 0) 1.5 0.0)))
             ;; What is left of this month, or -- when the rollover is on --
             ;; everything never spent since the journal began.
             (remaining (or override
                            (if (and my/hledger-budget-rollover
                                     my/hledger-budget--available)
                                (or (alist-get account my/hledger-budget--available
                                               nil nil #'equal)
                                    (- budgeted spent))
                              (- budgeted spent))))
             (over (< remaining 0)))
        (propertize
         (format "  %-26s %9.2f / %-9.2f %s %5s  %10.2f  %s\n"
                 (truncate-string-to-width label 26)
                 spent budgeted
                 (my/hledger-budget--bar fraction)
                 (my/hledger--percent spent budgeted)
                 remaining
                 ;; Six months of what was SPENT -- not budgeted, not
                 ;; available. Rising means the spending rose. Scaled from
                 ;; zero, so the height is comparable between months rather
                 ;; than being stretched to fill whatever range it happens to
                 ;; have.
                 (my/hledger--sparkline
                  (or (alist-get account my/hledger-budget--trends nil nil #'equal)
                      '())))
         'hledger-account account
         'face (if over 'error 'default))))

    (defconst my/hledger-budget-sections
      '(("needs"    . "NEEDS -- every month, and not optional")
        ("periodic" . "PERIODIC -- not every month, still not optional")
        ("wants"    . "WANTS -- a choice, every month")
        ("goals"    . "GOALS -- wanted, and can wait"))
      "The sections of the envelope screen, in the order they are drawn.

    The order is the point: what has to be paid comes first and what is
    optional comes last, so reading down the screen is reading down a list of
    priorities. An account says which section it is in with a `section:' tag
    in the chart of accounts.")

    (defun my/hledger--section (account)
      "Which section ACCOUNT belongs to.

    Inherited from the nearest ancestor that declares one, so tagging
    `expenses:housing' covers mortgage, water, community and utilities without
    four more tags. Anything untagged falls to the end, visibly, rather than
    being quietly dropped."
      (let ((parts (split-string account ":"))
            (found nil))
        (while (and parts (not found))
          (setq found (my/hledger--account-tag-string
                       (string-join parts ":") "section"))
          (setq parts (butlast parts)))
        (or found "untagged")))

    (defun my/hledger--account-tag-string (account tag)
      "Read a word-valued TAG off ACCOUNT's directive."
      (let ((file (expand-file-name "accounts.hledger" my/hledger-dir)))
        (when (file-readable-p file)
          (with-temp-buffer
            (insert-file-contents file)
            (goto-char (point-min))
            (when (re-search-forward
                   (format "^account +%s *\\(;.*\\)?$" (regexp-quote account)) nil t)
              (let ((line (match-string 0)))
                (when (string-match (format "%s: *\\([a-z0-9-]+\\)" (regexp-quote tag)) line)
                  (match-string 1 line))))))))

    (defun my/hledger-budget--insert-sections (rows)
      "Draw ROWS grouped into sections, each with its own subtotal."
      (let ((buckets nil))
        (dolist (row rows)
          (let* ((section (my/hledger--section (nth 0 row)))
                 (cell (assoc section buckets)))
            (if cell (setcdr cell (append (cdr cell) (list row)))
              (push (cons section (list row)) buckets))))
        (dolist (entry (append my/hledger-budget-sections '(("untagged" . "UNTAGGED"))))
          (when-let* ((members (cdr (assoc (car entry) buckets))))
            (let ((spent (apply #'+ (mapcar (lambda (r) (my/hledger--num (nth 1 r))) members)))
                  (budget (apply #'+ (mapcar (lambda (r) (my/hledger--num (nth 2 r))) members))))
              (insert (propertize (format "\n  %s\n" (cdr entry))
                                  'face 'my/hledger-budget-heading))
              (my/hledger-budget--insert-rows members)
              ;; The subtotal is the reason for the sections. One number for
              ;; what has to be paid and one for what does not is the whole
              ;; question a budget is asked.
              (insert (propertize
                       (format "  %-26s %9.2f / %-9.2f\n" "" spent budget)
                       'face 'shadow)))))))

    (defun my/hledger-budget--group (account)
      "The heading ACCOUNT belongs under, or nil when it is a top-level one."
      (let ((tail (replace-regexp-in-string "\\`expenses:" "" account)))
        (when (string-match "\\`\\([^:]+\\):" tail)
          (match-string 1 tail))))

    (defun my/hledger-budget--insert-rows (rows)
      "Insert ROWS, gathering anything with a parent under a heading.

    Every account with a parent gets one, even when it is the only child in
    this section. Consistency wins here: sections split siblings apart -- the
    pharmacy is a need and the gym is a want -- so without a heading some rows
    read `health:medical' and others read `gym', and the colons make the screen
    look like it forgot to indent."
      (let ((groups nil))
        (dolist (row rows)
          (let* ((account (nth 0 row))
                 (group (my/hledger-budget--group account))
                 (cell (assoc group groups)))
            (if cell (setcdr cell (append (cdr cell) (list row)))
              (push (cons group (list row)) groups))))
        (dolist (entry (nreverse groups))
          (let ((group (car entry)) (members (cdr entry)))
            (if (or (null group) (= 1 (length members)))
                ;; No heading. A parent above a single child repeats its own
                ;; numbers on two lines and says nothing twice -- but the child
                ;; still needs its parent's name to mean anything, so the two
                ;; are joined on one line instead.
                (dolist (row members)
                  (insert (my/hledger-budget--row
                           (nth 0 row) (my/hledger--num (nth 1 row))
                           (my/hledger--num (nth 2 row))
                           (when group
                             (replace-regexp-in-string
                              ":" " \u00b7 "
                              (replace-regexp-in-string "\\`expenses:" "" (nth 0 row))))))
                  (my/hledger-budget--insert-goal row 0))
              (let ((spent (apply #'+ (mapcar (lambda (r) (my/hledger--num (nth 1 r))) members)))
                    (budget (apply #'+ (mapcar (lambda (r) (my/hledger--num (nth 2 r))) members))))
                ;; The heading carries the totals, so the group can be read
                ;; without adding its children up by eye.
                (insert (my/hledger-budget--row
                         (concat "expenses:" group) spent budget group 0
                         (when (and my/hledger-budget-rollover
                                    my/hledger-budget--available)
                           (apply #'+ (mapcar
                                       (lambda (r)
                                         (or (alist-get (nth 0 r)
                                                        my/hledger-budget--available
                                                        nil nil #'equal)
                                             (- (my/hledger--num (nth 2 r))
                                                (my/hledger--num (nth 1 r)))))
                                       members)))))
                (dolist (row members)
                  (insert (my/hledger-budget--row
                           (nth 0 row) (my/hledger--num (nth 1 row))
                           (my/hledger--num (nth 2 row))
                           (replace-regexp-in-string
                            (format "\\`expenses:%s:" (regexp-quote group)) ""
                            (nth 0 row))
                           1))
                  (my/hledger-budget--insert-goal row 1))))))))

    (defun my/hledger-budget--insert-goal (row &optional depth)
      "Draw ROW's target line, if it has a target.

    Progress is the rolled-over available rather than what was spent: an
    envelope funded at 13 a month for six months and never touched has 78 set
    aside toward its target, and that is the number the target is about."
      (let* ((account (nth 0 row))
             (monthly (my/hledger--num (nth 2 row)))
             (available (or (and my/hledger-budget--available
                                 (alist-get account my/hledger-budget--available
                                            nil nil #'equal))
                            (- monthly (my/hledger--num (nth 1 row)))))
             (line (my/hledger--goal-line account available monthly
                                          (or my/hledger-budget--time (current-time))
                                          depth)))
        (when line (insert line))))

    (defun my/hledger-budget--month-string (time)
      (format-time-string "%Y-%m" time))

    (defun my/hledger-budget--shift (months)
      "Move the screen MONTHS along."
      (interactive)
      (let ((decoded (decode-time my/hledger-budget--time)))
        (setf (nth 4 decoded) (+ (nth 4 decoded) months))
        (setq my/hledger-budget--time (encode-time decoded)))
      (my/hledger-budget--render))

    (defun my/hledger-budget-next-month () (interactive) (my/hledger-budget--shift 1))
    (defun my/hledger-budget-previous-month () (interactive) (my/hledger-budget--shift -1))

    (defun my/hledger-budget--account-at-point ()
      (get-text-property (line-beginning-position) 'hledger-account))

    (defun my/hledger-budget-register ()
      "Every transaction behind the envelope on this line."
      (interactive)
      (if-let* ((account (my/hledger-budget--account-at-point)))
          (my/hledger--report "*hledger register*" "register" account
                              "-p" (my/hledger-budget--month-string
                                    my/hledger-budget--time))
        (user-error "No envelope on this line")))

    (defun my/hledger-budget-add ()
      "Record something against the envelope on this line."
      (interactive)
      (call-interactively #'my/hledger-add)
      (my/hledger-budget--render))

    (defvar my/hledger-budget-mode-map
      (let ((map (make-sparse-keymap)))
        (define-key map (kbd "]") #'my/hledger-budget-next-month)
        (define-key map (kbd "[") #'my/hledger-budget-previous-month)
        (define-key map (kbd "RET") #'my/hledger-budget-register)
        (define-key map (kbd "a") #'my/hledger-budget-add)
        (define-key map (kbd "b") #'my/hledger-budget-file)
        (define-key map (kbd "r") #'my/hledger-budget--render)
        map)
      "Keys avoid h/n/e/i/p/f, which are movement and scrolling on this layout.")

    (define-derived-mode my/hledger-budget-mode special-mode "Budget"
      "Envelopes for one month, spent against budgeted."
      ;; The columns are the layout; a gutter of line numbers beside them is
      ;; noise, and no row here is ever addressed by number.
      (display-line-numbers-mode -1)
      (setq-local truncate-lines t))

    (with-eval-after-load 'evil
      (evil-set-initial-state 'my/hledger-budget-mode 'normal)
      ;; The major mode map alone loses to evil's normal state for plain
      ;; letters, so the same keys are declared again where evil can see them.
      (evil-define-key 'normal my/hledger-budget-mode-map
        (kbd "]") #'my/hledger-budget-next-month
        (kbd "[") #'my/hledger-budget-previous-month
        (kbd "RET") #'my/hledger-budget-register
        (kbd "a") #'my/hledger-budget-add
        (kbd "b") #'my/hledger-budget-file
        (kbd "r") #'my/hledger-budget--render))

    (defun my/hledger-budget--render ()
      "Draw the envelope screen for the month it is currently showing."
      (interactive)
      (let* ((period (my/hledger-budget--month-string my/hledger-budget--time))
             (expenses (my/hledger--csv "balance" "--budget" "--flat" "^expenses"
                                        "-p" period))
             (income (my/hledger--csv "balance" "--budget" "--flat" "^income"
                                      "-p" period))
             (inhibit-read-only t)
             (line (line-number-at-pos))
             spent-total budget-total income-actual income-budget)
        (setq my/hledger-budget--trends
              (my/hledger-budget--load-trends my/hledger-budget--time))
        (setq my/hledger-budget--available
              (when my/hledger-budget-rollover
                (my/hledger--available my/hledger-budget--time)))
        (erase-buffer)
        (dolist (row (cdr income))
          (when (equal (nth 0 row) "Total:")
            (setq income-actual (- (my/hledger--num (nth 1 row)))
                  income-budget (- (my/hledger--num (nth 2 row))))))
        (dolist (row (cdr expenses))
          (when (equal (nth 0 row) "Total:")
            (setq spent-total (my/hledger--num (nth 1 row))
                  budget-total (my/hledger--num (nth 2 row)))))
        (let* ((rows (my/hledger-budget--with-goals expenses "\\`expenses"))
               (envelope-spend (apply #'+ (mapcar (lambda (r) (my/hledger--num (nth 1 r)))
                                                  rows)))
               ;; What the envelopes do not account for. Derived rather than
               ;; read off a row, because hledger folds it into the parent.
               (unbudgeted (- (or spent-total 0) envelope-spend)))
          (insert (propertize
                   (format "  %s\n\n"
                           (format-time-string "%B %Y" my/hledger-budget--time))
                   'face 'my/hledger-budget-heading))
          (insert (format "  Income     %10.2f received of %.2f expected\n"
                          (or income-actual 0) (or income-budget 0)))
          ;; The filler is fixed rather than eyeballed: " of %-10.2f budgeted  "
          ;; is 25 columns whatever the number, so the second pair of labels
          ;; stays in the same place when the amounts grow a digit.
          (insert (format "  Budgeted   %10.2f%sUnassigned %10.2f\n"
                          (or budget-total 0) (make-string 25 ?\s)
                          (- (or income-budget 0) (or budget-total 0))))
          (insert (format "  Spent      %10.2f of %-10.2f budgeted  Left       %10.2f\n\n"
                          (or spent-total 0) (or budget-total 0)
                          (- (or budget-total 0) (or spent-total 0))))
          (insert (propertize
                   (format "  %-26s %9s / %-9s %s %5s  %10s  %s\n"
                           "envelope" "spent" "budget"
                           (make-string my/hledger-budget-bar-width ?\s) ""
                           (if my/hledger-budget-rollover "available" "left")
                           "6 mo spend")
                   'face 'my/hledger-budget-heading))
          (my/hledger-budget--insert-sections rows)
          (when (> (abs unbudgeted) 0.005)
            (insert (my/hledger-budget--row "expenses:<unbudgeted>" unbudgeted 0))))

        ;; Saving is budgeted too. Money moved to a fund is not spending, so it
        ;; is not an expense account and would never appear above -- but a
        ;; budget that shows only what leaves and never what accumulates is the
        ;; half of YNAB that makes the other half feel pointless.
        ;;
        ;; The sign flips: a transfer in is a debit on an asset, which hledger
        ;; reports positive, and "spent 200 of 200" is the right reading of a
        ;; fund that got its contribution this month.
        ;; not:desc:opening -- the opening balances are dated inside the first
        ;; tracked month, and without excluding them the mortgage row reports
        ;; the whole outstanding loan as this month's movement.
        (let ((saving (my/hledger--csv "balance" "--budget" "--flat"
                                       "^assets:savings" "^liabilities:mortgage"
                                       "not:desc:opening" "-p" period)))
          (when (> (length saving) 2)
            ;; Paying down a mortgage belongs here rather than among the
            ;; envelopes: it is not a cost, it is net worth moving from the
            ;; bank into the house, which is the same thing a savings transfer
            ;; does. Only the interest is spending, and that has its own row up
            ;; in the envelopes.
            (insert (propertize (format "\n  %-26s %9s / %-9s\n" "saving and paydown" "moved" "planned")
                                'face 'my/hledger-budget-heading))
            ;; One pass, so a fund's goal line sits under its own month row
            ;; rather than after every other fund's.
            (dolist (row (my/hledger-budget--saving-rows saving))
              (let* ((account (nth 0 row))
                     (moved (my/hledger--num (nth 1 row)))
                     (planned (my/hledger--num (nth 2 row)))
                     (label (replace-regexp-in-string
                             "\\`\\(assets:savings:?\\|liabilities:\\)" "" account))
                     ;; A debt's target is zero, so progress runs up from what
                     ;; was borrowed rather than toward a goal.
                     (original (my/hledger--account-tag account "original"))
                     (goal (or original
                               (car (alist-get account (my/hledger--goals)
                                               nil nil #'equal))))
                     (owed (abs (my/hledger--amount account)))
                     (done (if original (- original owed) owed)))
                (insert (propertize
                         (format "  %-26s %9.2f / %-9.2f %s %5s  %10.2f\n"
                                 (truncate-string-to-width
                                  (if (string-empty-p label) "savings" label) 26)
                                 moved planned
                                 (my/hledger-budget--bar
                                  (if (> planned 0) (/ moved planned) 0.0))
                                 (my/hledger--percent moved planned)
                                 (- planned moved))
                         'hledger-account account))
                (if original
                    ;; A debt: progress runs up from what was borrowed, and the
                    ;; time left is a real amortisation rather than the balance
                    ;; divided by this month's principal -- the principal share
                    ;; grows every month, and ignoring that overstated the term
                    ;; by 57 months.
                    (when (> goal 0)
                      (let* ((rate (my/hledger--account-tag account "rate"))
                             (payment (my/hledger--account-tag account "payment"))
                             (months (cond ((and rate payment)
                                            (my/hledger--amortise
                                             owed (- (expt (+ 1 (/ rate 100.0)) (/ 1.0 12)) 1)
                                             payment))
                                           ((> planned 0)
                                            (ceiling (/ (max 0 (- goal done)) planned))))))
                        (insert
                         (propertize
                          (format "  %-26s %9.2f / %-9.0f %s %5s  %s\n"
                                  "    paid off" done goal
                                  (my/hledger-budget--bar (/ done goal))
                                  (my/hledger--percent done goal)
                                  (if months (format "%d mo left" months) "no rate set"))
                          'face 'shadow))))
                  ;; A fund: the same target line the envelopes use, so a `by:'
                  ;; date and a reached target read the same wherever they are.
                  (when-let* ((line (my/hledger--goal-line
                                     account done planned
                                     (or my/hledger-budget--time (current-time)) 0)))
                    (insert line)))))))
        ;; Whether the plan is backed by money that exists.
        ;;
        ;; `unallocated' is what sits in the current accounts and the wallet,
        ;; less the card -- deliberately not counting the savings funds, since
        ;; money already inside one is spoken for. Moving 5,600 into the
        ;; emergency fund therefore lowers this line and lowers what is still
        ;; to fund by the same amount, and the difference does not move. That
        ;; difference is the only number here that matters.
        ;;
        ;; This is the one thing hledger's budget model does not check and
        ;; YNAB's does. A periodic transaction declares an intention; it never
        ;; asks whether the euro is in the account. So the totals are shown
        ;; against what is actually held, and if the goals ever exceed it the
        ;; plan has stopped being a plan.
        (let* ((liquid (+ (my/hledger--amount "^assets:bank")
                          (my/hledger--amount "^assets:cash")
                          (my/hledger--amount "^liabilities:card")))
               ;; Only what is meant to be funded within a year counts. A
               ;; target four years out is incomplete, not unbacked, and
               ;; letting it into this sum turns the check into an alarm that
               ;; is always on -- which is the same as no check at all.
               (near (seq-remove
                      (lambda (g)
                        (or (my/hledger--account-tag (car g) "original")
                            (let ((by (cdr (cdr g))))
                              (and by (> (my/hledger--months-until
                                          by (or my/hledger-budget--time (current-time)))
                                         12)))))
                      (my/hledger--goals)))
               (outstanding
                (apply #'+ (mapcar
                            (lambda (goal)
                              (max 0 (- (car (cdr goal))
                                        (let ((bal (abs (my/hledger--amount (car goal))))
                                              (orig (my/hledger--account-tag (car goal) "original")))
                                          (if orig (- orig bal) bal)))))
                            near))))
          (insert (propertize
                   (format "\n  %-26s %9.2f   in the accounts, not yet in a fund\n"
                           "unallocated" liquid)
                   'face 'my/hledger-budget-heading))
          (insert (format "  %-26s %9.2f   targets due within a year\n"
                          "still to fund" outstanding))
          (insert (propertize
                   (format "  %-26s %9.2f   %s\n" "free" (- liquid outstanding)
                           (if (>= liquid outstanding)
                               "every fund is backed"
                             "THE GOALS EXCEED THE MONEY"))
                   'face (if (>= liquid outstanding) 'success 'error))))

        (insert (propertize "\n  [ ] month   RET register   a add   b edit budget   r refresh\n"
                            'face 'shadow))
        (goto-char (point-min))
        (forward-line (1- line))))

    ;;; ------------------------------------------------------------------
    ;;; Charts
    ;;;
    ;;; Two kinds, on purpose. Sparklines are Unicode blocks, so they render in
    ;;; a terminal frame, in the echo area, and in a copied-out plain-text
    ;;; report -- they go on the envelope screen where they answer "is this
    ;;; envelope drifting?" at a glance. The dashboard is real SVG, because a
    ;;; net worth line or twelve months of income against spending is not
    ;;; something eight block characters can carry.
    ;;;
    ;;; Colours come from faces rather than literals so both follow the theme,
    ;;; and every one has a fallback: in batch, and on a frame that has not
    ;;; realised faces yet, face-attribute returns `unspecified'.

    ;; Periods are written "12 months ago.." rather than "last 12 months".
    ;; hledger rejects the latter -- `last' takes a bare unit, so "last month"
    ;; parses and "last 12 months" is an error -- and it is an error the report
    ;; swallows, coming back as an empty table rather than a complaint.
    (defun my/hledger--matrix (&rest args)
      "Run a monthly hledger report and return (MONTHS . ROWS).
    MONTHS is the header, ROWS an alist of account to a list of floats."
      (let* ((csv (apply #'my/hledger--csv (append args '("-M"))))
             (months (cdr (car csv)))
             (rows (mapcar (lambda (r)
                             (cons (car r) (mapcar #'my/hledger--num (cdr r))))
                           (seq-remove (lambda (r) (equal (car r) "Total:")) (cdr csv)))))
        (cons months rows)))

    (defconst my/hledger--spark "▁▂▃▄▅▆▇█")

    (defun my/hledger--sparkline (values)
      "VALUES as a small trend: an SVG line on a graphical frame, blocks otherwise."
      (cond
       ((or (null values) (zerop (apply #'max 0 (mapcar #'abs values))))
        (make-string (max 1 (length values)) ?\s))
       ((not (my/hledger--graphical-p))
        ;; float, or elisp does integer division and every value below the
        ;; largest collapses to the lowest block.
        (let ((top (float (apply #'max (mapcar #'abs values)))))
          (mapconcat (lambda (v)
                       (string (aref my/hledger--spark
                                     (min 7 (floor (* 7.99 (/ (abs v) top)))))))
                     values "")))
       (t
        ;; Scaled from zero rather than from the smallest month. A sparkline
        ;; normalised to its own range turns a flat envelope into a dramatic
        ;; zigzag, which is the opposite of what the column is for.
        (let* ((columns (max 6 (length values)))
               (w (* columns (default-font-width)))
               (h (max 8 (- (default-font-height) 2)))
               (svg (svg-create w h))
               (top (float (apply #'max (mapcar #'abs values))))
               (n (max 1 (1- (length values))))
               (accent (my/hledger--color 'success "#2e8b57"))
               (points (cl-loop for v in values for i from 0
                                collect (cons (* w (/ (float i) n))
                                              (- h 1 (* (- h 3) (/ (abs v) top)))))))
          (svg-polyline svg points :fill "none" :stroke accent :stroke-width 1.2)
          ;; The last point marked, so "where it is now" is readable without
          ;; counting along the line.
          (let ((last (car (last points))))
            (svg-circle svg (min (- w 1.5) (car last)) (cdr last) 1.6 :fill accent))
          (my/hledger--image svg columns)))))

    (defun my/hledger--color (face fallback)
      (let ((c (face-attribute face :foreground nil t)))
        (if (or (null c) (eq c 'unspecified)) fallback c)))

    (defun my/hledger-chart--line (values labels width height title)
      "A line chart of VALUES, one point per month."
      (setq values (or values '(0)))
      (let* ((svg (svg-create width height))
             (pad 46)
             (fg (my/hledger--color 'default "#333333"))
             (grid (my/hledger--color 'shadow "#999999"))
             (accent (my/hledger--color 'success "#2e8b57"))
             (lo (min 0 (apply #'min values)))
             (hi (max 0 (apply #'max values)))
             (span (max 1.0 (- hi lo)))
             (plot-w (- width pad 8))
             (plot-h (- height 44))
             (n (max 1 (1- (length values))))
             (x (lambda (i) (+ pad (* plot-w (/ (float i) n)))))
             (y (lambda (v) (+ 22 (* plot-h (- 1 (/ (- v lo) span)))))))
        (svg-text svg title :x 4 :y 14 :fill fg :font-size 12 :font-weight "bold")
        ;; A zero line, because a net worth chart that does not show where zero
        ;; is says nothing about whether the number is positive.
        (when (and (< lo 0) (> hi 0))
          (svg-line svg pad (funcall y 0) (+ pad plot-w) (funcall y 0)
                    :stroke grid :stroke-width 1 :stroke-dasharray "3 3"))
        (svg-polyline svg
                      (cl-loop for v in values for i from 0
                               collect (cons (funcall x i) (funcall y v)))
                      :fill "none" :stroke accent :stroke-width 2)
        (svg-text svg (format "%.0f" hi) :x 2 :y 26 :fill grid :font-size 9)
        (svg-text svg (format "%.0f" lo) :x 2 :y (+ 22 plot-h) :fill grid :font-size 9)
        (when labels
          (svg-text svg (car labels) :x pad :y (- height 6) :fill grid :font-size 9)
          (svg-text svg (car (last labels)) :x (- width 46) :y (- height 6)
                    :fill grid :font-size 9))
        svg))

    (defun my/hledger-chart--paired-bars (a b labels width height title)
      "Two series side by side, one pair per month -- income against spending."
      (setq a (or a '(0)) b (or b '(0)))
      (let* ((svg (svg-create width height))
             (fg (my/hledger--color 'default "#333333"))
             (grid (my/hledger--color 'shadow "#999999"))
             (ca (my/hledger--color 'success "#2e8b57"))
             (cb (my/hledger--color 'error "#b22222"))
             (top (max 1.0 (apply #'max (append (mapcar #'abs a) (mapcar #'abs b)))))
             (pad 46) (plot-h (- height 44))
             (n (max 1 (length a)))
             (slot (/ (float (- width pad 8)) n))
             (bw (max 2 (/ (- slot 4) 2))))
        (svg-text svg title :x 4 :y 14 :fill fg :font-size 12 :font-weight "bold")
        (cl-loop for i from 0 below n do
                 (let ((va (abs (nth i a))) (vb (abs (nth i b)))
                       (x0 (+ pad (* i slot))))
                   (svg-rectangle svg x0 (+ 22 (* plot-h (- 1 (/ va top))))
                                  bw (* plot-h (/ va top)) :fill ca)
                   (svg-rectangle svg (+ x0 bw 1) (+ 22 (* plot-h (- 1 (/ vb top))))
                                  bw (* plot-h (/ vb top)) :fill cb)))
        (svg-text svg (format "%.0f" top) :x 2 :y 26 :fill grid :font-size 9)
        (when labels
          (svg-text svg (car labels) :x pad :y (- height 6) :fill grid :font-size 9)
          (svg-text svg (car (last labels)) :x (- width 46) :y (- height 6)
                    :fill grid :font-size 9))
        svg))

    (defun my/hledger-chart--hbars (pairs width height title)
      "Horizontal bars for PAIRS of (label . value), largest first."
      (let* ((svg (svg-create width height))
             (fg (my/hledger--color 'default "#333333"))
             (grid (my/hledger--color 'shadow "#999999"))
             (accent (my/hledger--color 'success "#2e8b57"))
             (top (max 1.0 (apply #'max (mapcar #'cdr pairs))))
             (label-w 150)
             (row-h (/ (float (- height 26)) (max 1 (length pairs)))))
        (svg-text svg title :x 4 :y 14 :fill fg :font-size 12 :font-weight "bold")
        (cl-loop for (label . value) in pairs for i from 0 do
                 (let ((y (+ 22 (* i row-h))))
                   (svg-text svg (truncate-string-to-width label 22)
                             :x 4 :y (+ y (* row-h 0.7)) :fill fg :font-size 10)
                   (svg-rectangle svg label-w (+ y (* row-h 0.2))
                                  (* (- width label-w 60) (/ value top))
                                  (* row-h 0.6) :fill accent)
                   (svg-text svg (format "%.0f" value)
                             :x (- width 52) :y (+ y (* row-h 0.7))
                             :fill grid :font-size 10)))
        svg))

    (defun my/hledger-charts ()
      "A dashboard: net worth, income against spending, and where it goes."
      (interactive)
      (unless (image-type-available-p 'svg)
        (user-error "This Emacs has no SVG support; the sparklines on SPC $ b still work"))
      (require 'svg)
      (let* ((buffer (get-buffer-create "*finance charts*"))
             (width (min 900 (max 480 (- (* (window-body-width) (default-font-width)) 40))))
             (period "12 months ago..")
             (worth (my/hledger--matrix "balance" "^assets" "^liabilities" "-H" "-p" period))
             (flow (my/hledger--matrix "balance" "^income" "^expenses" "-p" period))
             (spend (my/hledger--csv "balance" "^expenses" "--flat" "-p" period))
             (inhibit-read-only t))
        (with-current-buffer buffer
          (erase-buffer)
          ;; Net worth is the sum of every asset and liability row, month by
          ;; month; -H makes each column a running total rather than that
          ;; month's movement.
          (let* ((months (car worth))
                 (series (cl-loop for i from 0 below (length months)
                                  collect (cl-loop for row in (cdr worth)
                                                   sum (nth i (cdr row))))))
            (when series
              (insert-image (svg-image (my/hledger-chart--line
                                        series months width 170 "Net worth")
                                       :scale 1))
              (insert "\n\n")))
          (let* ((months (car flow))
                 (income (cl-loop for i from 0 below (length months)
                                  collect (cl-loop for row in (cdr flow)
                                                   when (string-prefix-p "income" (car row))
                                                   sum (nth i (cdr row)))))
                 (spent (cl-loop for i from 0 below (length months)
                                 collect (cl-loop for row in (cdr flow)
                                                  when (string-prefix-p "expenses" (car row))
                                                  sum (nth i (cdr row))))))
            (when (car flow)
              (insert-image (svg-image (my/hledger-chart--paired-bars
                                        income spent months width 170
                                        "In against out, by month")
                                       :scale 1))
              (insert "\n\n")))
          (let ((pairs (seq-take
                        (sort (mapcar (lambda (r)
                                        (cons (replace-regexp-in-string
                                               "\\`expenses:" "" (car r))
                                              (my/hledger--num (nth 1 r))))
                                      (my/hledger-budget--leaves
                                       (seq-remove (lambda (r) (equal (car r) "Total:"))
                                                   (cdr spend))))
                              (lambda (a b) (> (cdr a) (cdr b))))
                        10)))
            (when pairs
              (insert-image (svg-image (my/hledger-chart--hbars
                                        pairs width (+ 30 (* 20 (length pairs)))
                                        "Where it went, last 12 months")
                                       :scale 1))
              (insert "\n")))
          (goto-char (point-min))
          (special-mode)
          (display-line-numbers-mode -1))
        (pop-to-buffer buffer)))

    (defun my/hledger-budget (&optional prefix)
      "The envelope screen: spent against budgeted, this month.
    With PREFIX, start on a month you name instead."
      (interactive "P")
      (let ((buffer (get-buffer-create "*budget*")))
        (with-current-buffer buffer
          (my/hledger-budget-mode)
          (setq my/hledger-budget--time
                (if prefix
                    (encode-time (parse-time-string
                                  (concat (read-string "Month (YYYY-MM): ") "-01 00:00:00")))
                  (current-time)))
          (my/hledger-budget--render))
        (pop-to-buffer buffer)))

    (defun my/hledger-budget-table (&optional prefix)
      "hledger's own budget table, for when the numbers matter more than the shape."
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
                          "balance" "^expenses" "--tree" "-M"
                          "-p" (if prefix
                                   (read-string "Period: ")
                                 "12 months ago..")))

    (defun my/hledger-networth ()
      "What is owned against what is owed, month by month."
      (interactive)
      (my/hledger--report "*hledger net worth*"
                          "balancesheet" "--tree" "-M" "-p" "12 months ago.."))

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
