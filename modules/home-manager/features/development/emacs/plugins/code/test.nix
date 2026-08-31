# development emacs plugins code test

{
  ...
}:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      dape
      jest
    ];

  programs.emacs.extraConfig = ''
        ;;; Tests — the weakest point of the port, and the one place a plugin had to be
        ;;; written rather than swapped.
        ;;;
        ;;; neotest has no Emacs equivalent: nothing offers its adapter model, its
        ;;; nearest-test detection or its summary tree. jest.el covers jest alone. So
        ;;; what follows is a small runner that reads the project's package.json to pick
        ;;; between jest, vitest and playwright — the three adapters the nvim config
        ;;; enables — and finds the enclosing test by name the way neotest does. It runs
        ;;; through `compile', so failures are navigable with the usual error commands.

        (require 'jest)
        (setq jest-pdb-track nil)

        (defun my/project-has-dep (dep)
          "Non-nil when the project's package.json mentions DEP."
          (let ((pkg (expand-file-name "package.json" (my/project-root))))
            (and (file-readable-p pkg)
                 (with-temp-buffer
                   (insert-file-contents pkg)
                   (goto-char (point-min))
                   (search-forward (format "\"%s\"" dep) nil t)))))

        (defun my/test-runner ()
          "Which runner this project uses: `vitest', `playwright' or `jest'.
    Playwright is checked before the unit runners because a repo commonly has both,
    and a .spec file under a playwright directory belongs to playwright."
          (cond
           ((and (my/project-has-dep "@playwright/test")
                 (string-match-p "\\(e2e\\|playwright\\)" (or (buffer-file-name) "")))
            'playwright)
           ((my/project-has-dep "vitest") 'vitest)
           ((my/project-has-dep "@playwright/test") 'playwright)
           (t 'jest)))

        (defun my/nearest-test-name ()
          "Name of the test enclosing point.
    Reads backwards for the nearest it/test/describe and returns its title, which is
    what the -t filter of every one of these runners takes."
          (save-excursion
            (when (re-search-backward
                   (concat "^[ \t]*\\(?:it\\|test\\|describe\\)"
                           "\\(?:\\.\\(?:only\\|skip\\|concurrent\\|each\\)\\)?"
                           "[ \t]*(\\s-*\\([\"'`]\\)\\(\\(?:[^\\\\]\\|\\\\.\\)*?\\)\\1")
                   nil t)
              (match-string 3))))

        (defvar my/test-last-command nil
          "The last test command run, for `my/test-last'.")

        (defun my/test-run (command)
          "Run COMMAND from the project root in a dedicated compilation buffer."
          (setq my/test-last-command command)
          (let ((default-directory (my/project-root))
                (compilation-buffer-name-function (lambda (_) "*tests*")))
            (compile command)))

        (defun my/test-file ()
          "Run every test in the current file."
          (interactive)
          (let ((file (file-relative-name (buffer-file-name) (my/project-root))))
            (my/test-run
             (pcase (my/test-runner)
               ('vitest     (format "npx vitest run %s" (shell-quote-argument file)))
               ('playwright (format "npx playwright test %s" (shell-quote-argument file)))
               (_           (format "npx jest %s" (shell-quote-argument file)))))))

        (defun my/test-nearest ()
          "Run only the test the cursor is inside."
          (interactive)
          (let ((name (my/nearest-test-name))
                (file (file-relative-name (buffer-file-name) (my/project-root))))
            (if (not name)
                (my/test-file)
              (my/test-run
               (pcase (my/test-runner)
                 ('vitest     (format "npx vitest run %s -t %s"
                                      (shell-quote-argument file) (shell-quote-argument name)))
                 ('playwright (format "npx playwright test %s -g %s"
                                      (shell-quote-argument file) (shell-quote-argument name)))
                 (_           (format "npx jest %s -t %s"
                                      (shell-quote-argument file) (shell-quote-argument name))))))))

        (defun my/test-last ()
          "Re-run the last test command."
          (interactive)
          (if my/test-last-command
              (my/test-run my/test-last-command)
            (message "No test has been run yet")))

        (defun my/test-output ()
          "Show the test output buffer."
          (interactive)
          (if-let ((buffer (get-buffer "*tests*")))
              (pop-to-buffer buffer)
            (message "No test output yet")))

        (defun my/test-summary ()
          "Closest thing to neotest's summary tree: the whole suite, watched.
    neotest's collapsible per-test tree has no Emacs counterpart; a watch run in the
    output buffer is the honest substitute."
          (interactive)
          (my/test-run
           (pcase (my/test-runner)
             ('vitest     "npx vitest")
             ('playwright "npx playwright test --reporter=list")
             (_           "npx jest --watch"))))

        ;; dap + dap-ui + dap-virtual-text, all three in one package. dape reads
        ;; launch.json, so a project that already debugs in VS Code debugs here.
        (require 'dape)
        (setq dape-buffer-window-arrangement 'right
              dape-inlay-hints t)
        (add-hook 'dape-compile-hook #'kill-buffer)
  '';
}
