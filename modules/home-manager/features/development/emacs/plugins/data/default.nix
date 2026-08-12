{
  lib,
  pkgs,
  ...
}:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      prisma-mode
      sql-indent
      sqlformat
    ];

  home.packages = with pkgs; [
    postgresql
  ];

  programs.emacs.extraConfig = ''
    ;;; Data layer — PostgreSQL, Prisma and Drizzle.
    ;;;
    ;;; Drizzle needs nothing of its own: its schemas are TypeScript, so ts-ls already
    ;;; gives full completion and go-to-definition over them. Prisma gets its own
    ;;; major mode and language server (registered in plugins/lsp/lsp.nix), and raw
    ;;; SQL gets sqls plus pg_format.

    (require 'sql)
    (require 'sql-indent)
    (require 'prisma-mode)

    (add-to-list 'auto-mode-alist '("\\.prisma\\'" . prisma-mode))
    (add-hook 'sql-mode-hook #'sqlind-minor-mode)

    ;; psql as the default interactive product, and the pager off so results land in
    ;; the Emacs buffer instead of waiting on a `less' that has no terminal.
    (setq sql-product 'postgres
          sql-postgres-program "${pkgs.postgresql}/bin/psql"
          sql-postgres-options '("--no-psqlrc" "--pset=pager=off")
          ;; Long result sets are the norm; do not truncate them.
          sql-send-terminator t
          comint-buffer-maximum-size 8192)

    ;; Connections are deliberately not declared here: this repo is public, and
    ;; credentials belong in ~/.pgpass or $DATABASE_URL. `sql-postgres' then prompts
    ;; for host and database and picks the password up from there.
    (defun my/sql-postgres ()
      "Open a psql session, reading credentials from ~/.pgpass or the environment."
      (interactive)
      (let ((url (getenv "DATABASE_URL")))
        (if (and url (string-match
                      "postgres\\(?:ql\\)?://\\([^:]+\\)\\(?::[^@]*\\)?@\\([^:/]+\\)\\(?::\\([0-9]+\\)\\)?/\\(.+\\)"
                      url))
            (let ((sql-user (match-string 1 url))
                  (sql-server (match-string 2 url))
                  (sql-port (string-to-number (or (match-string 3 url) "5432")))
                  (sql-database (match-string 4 url)))
              (sql-postgres))
          (call-interactively #'sql-postgres))))

    ;; sqls gives completion and go-to-definition over a live schema; it reads its
    ;; connections from ~/.config/sqls/config.yaml.
    (add-hook 'sql-mode-hook #'lsp-deferred)

    ;; sqlformat runs pg_format, the same binary apheleia uses on save, for the times
    ;; you want to reformat a region by hand.
    (setq sqlformat-command 'pgformatter
          sqlformat-args '("-s2" "-g" "-u1"))
  '';
}
