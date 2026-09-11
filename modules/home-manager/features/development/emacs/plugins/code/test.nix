# development emacs plugins code test

{
  ...
}:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      dape

      # jest.el, with the one line that stops it working on Emacs 31 taken out.
      #
      # jest-traversal.el reads its buffer a character at a time through
      # `c-int-to-char', a cc-mode compatibility macro from the XEmacs era,
      # when a character and an integer were different types. On GNU Emacs it
      # has always expanded to its argument and nothing else.
      #
      # It is a MACRO, and it lives in cc-defs, which is not among the
      # package's requirements -- so jest-traversal.el is byte-compiled with
      # the symbol unbound and the call compiles to an ordinary function call.
      # By the time it runs, some other package has loaded cc-defs and the
      # symbol is a macro, and calling a macro as a function is
      #
      #   Invalid function: c-int-to-char
      #
      # which is what `jest-function' -- the test under the cursor -- died
      # with, every time, before it could read the name. Substituting the
      # expansion the macro would have produced is the whole fix.
      (jest.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace jest-traversal.el \
            --replace-fail "(c-int-to-char (aref text i))" "(aref text i)"
        '';
      }))
    ];

  programs.emacs.extraConfig = ''
        ;;; Tests — jest.el runs them, and this file only tells it which runner the
        ;;; project in front of it uses.
        ;;;
        ;;; What used to be here was a second test runner written by hand: its own
        ;;; nearest-test regex, its own `npx ...' command strings, its own compile
        ;;; buffer. jest.el was installed, required at the top of it, and then never
        ;;; called once. It is the better of the two by some distance — a popup
        ;;; carrying the runner's switches (watch, coverage, bail, --config, -t),
        ;;; file / file-dwim / function / repeat as separate commands, a comint
        ;;; buffer under `compilation-setup' so a failure is a jump rather than a
        ;;; read, and a per-project command history behind `jest-repeat'. So the
        ;;; hand-written half is gone and the package is wired up in its place.
        ;;;
        ;;; vitest is reached through the same package rather than through a second
        ;;; one. `jest-executable' is a whole command PREFIX rather than a program
        ;;; name, and the only things jest.el appends to it are the file path and
        ;;; `--testNamePattern NAME' — both of which vitest takes unchanged. So
        ;;; pointing it at vitest is a complete integration, not an approximation of
        ;;; one, and `my/jest-executable' below picks per project.
        ;;;
        ;;; What is deliberately NOT here, because no package does it and a
        ;;; hand-rolled one is what this file just stopped being:
        ;;;
        ;;;   - Playwright. Its filter is `-g', not `--testNamePattern', and its
        ;;;     tiers are `--project' rather than a config file each. There is no
        ;;;     Emacs package for it at all, so an application test runs from the
        ;;;     terminal and nothing here pretends otherwise.
        ;;;
        ;;;   - Failures as overlays in the code. flycheck-jest exists and is
        ;;;     jest-only; on a vitest project there is nothing to install.
        ;;;     `next-error' from the run buffer is what there is, and the
        ;;;     patterns below are what make that much work.
        ;;;
        ;;;   - "the tests related to this function". No JS runner exposes that.
        ;;;     jest's `--findRelatedTests' is per FILE, and per file is exactly what
        ;;;     `jest-file-dwim' already does -- with the caveat below.
        ;;;
        ;;;   - A unit / component / application tier switch. vitest expresses tiers
        ;;;     as projects or as separate config files, and which of the two differs
        ;;;     per repository — so the popup's own `--config=' option is the honest
        ;;;     answer rather than a guess baked in here.

        (require 'jest)

        ;; jest.el is a port of python-pytest.el and this is one of the seams: the
        ;; tracker hooks a Python debugger prompt into the comint filter, and there
        ;; is no Python anywhere near a jest run.
        (setq jest-pdb-track nil)

        ;; A test run saves first rather than asking whether to.
        ;;
        ;; The default is `ask-all', which puts a y-or-n prompt in front of every
        ;; single run. Running the tests on the buffer as it was two edits ago is
        ;; never the intent, so the question only ever has one answer.
        (setq jest-unsaved-buffers-behavior 'save-all)

        ;; A note about `jest-file-dwim', which is SPC t F rather than SPC t f.
        ;;
        ;; "dwim" means: from a source file, find and run its test; from a test
        ;; file, run that file. Which of the two you are looking at is a question
        ;; jest.el hands to projectile, and projectile answers it from the project
        ;; type's `:test-suffix'. Every JS type it knows -- npm, yarn, pnpm, bun --
        ;; registers that as ".test", so in a repository whose tests are named
        ;; `.spec.ts' projectile says the spec file is NOT a test, and dwim goes
        ;; looking for `thing.spec.test.ts', which exists nowhere.
        ;;
        ;; It is a per-repository fact and it belongs in the repository, so the fix
        ;; is a line in that project's .dir-locals.el and not a global setting here:
        ;;
        ;;   ((nil . ((projectile-project-test-suffix . ".spec"))))
        ;;
        ;; Until that is there, SPC t f -- plain `jest-file' -- is the one to use;
        ;; it runs the file in front of it and asks projectile nothing.

        (defun my/jest-vitest-project-p ()
          "Non-nil when the project in front of us runs vitest rather than jest."
          (let ((pkg (expand-file-name "package.json"
                                       (or (my/project-root) default-directory))))
            (and (file-readable-p pkg)
                 (with-temp-buffer
                   (insert-file-contents pkg)
                   (goto-char (point-min))
                   (search-forward "\"vitest\"" nil t)
                   t))))

        (defconst my/jest-watch-switches '("--watch" "--watchAll")
          "Popup switches that mean \"do not stop after one run\".")

        (defun my/jest-executable (&optional args)
          "The command prefix this project's tests run under, given popup ARGS.

    Three cases rather than two, because vitest decides between running once
    and watching from its SUBCOMMAND and not from a flag:

      npx vitest run     one pass, and the default here
      npx vitest watch   the popup's `w' switch, held open
      npx jest           everything the popup emits is jest's own

    Plain `npx vitest' is not one of them. jest.el runs its command through a
    comint buffer, a comint buffer has a pty, and vitest watches whenever it
    finds a tty — so `SPC t f' would have opened a run that never finishes.

    And `vitest run --watch' is not the watch: `run' wins, the flag is
    ignored, and the popup's own switch silently did nothing at all. That is
    what the subcommand here is for."
          (cond
           ((not (my/jest-vitest-project-p)) "npx jest")
           ((seq-intersection args my/jest-watch-switches #'string=) "npx vitest watch")
           (t "npx vitest run")))

        ;; Bound around the one call that reads it, rather than set globally.
        ;;
        ;; `jest-executable' is a single global, and two projects open at once do
        ;; not necessarily share a runner. `jest--run' is the only place the value
        ;; is consulted, and it is consulted from the source buffer — so a dynamic
        ;; binding there is both the narrowest fix and the correct one. `jest-repeat'
        ;; deliberately does not go through it: it replays the command line it
        ;; stored, runner included.
        ;; Declared because the `let' below binds it and jest is not loaded when
        ;; this file is compiled: an unbound-at-compile-time symbol binds
        ;; lexically, and jest would keep running its global executable.
        (defvar jest-executable)

        (defun my/jest--with-project-runner (fn &rest args)
          "Call FN with `jest-executable' set to this project's runner."
          (let ((jest-executable (my/jest-executable (plist-get args :args))))
            (apply fn args)))

        (advice-add 'jest--run :around #'my/jest--with-project-runner)

        ;; And the one popup switch vitest cannot be handed.
        ;;
        ;; `jest--transform-arguments' is jest.el's own hook for "make the popup's
        ;; switches mean to the runner what they mean on the popup", which is
        ;; exactly the question here, so the translation rides on it.
        ;;
        ;; `--watchAll' is jest's spelling. vitest does not merely ignore an option
        ;; it does not know, it exits with a usage error and a node backtrace — so
        ;; `W' on a vitest project produced a crash rather than a test run. The
        ;; intent is carried by the `watch' subcommand above; the flag itself is
        ;; dropped.
        (defun my/jest--vitest-arguments (args)
          "Drop the switches vitest would refuse from ARGS."
          (if (my/jest-vitest-project-p)
              (remove "--watchAll" args)
            args))

        (advice-add 'jest--transform-arguments
                    :filter-return #'my/jest--vitest-arguments)

        ;; Where a failure happened, so `next-error' can go there.
        ;;
        ;; `jest-mode' is derived from comint-mode and calls `(compilation-setup t)'
        ;; in its body, so the run buffer is already a compilation buffer and
        ;; `next-error' is already bound. What it has never had is a pattern that
        ;; matches the output it is looking at: compile.el ships rules for cc, gcc,
        ;; ant, maven and thirty other things, and nothing for a JavaScript test
        ;; runner. Parsing this file's own failing run found zero locations.
        ;;
        ;; Two patterns cover both runners:
        ;;
        ;;   ❯ src/thing.spec.ts:4:19          vitest, the assertion
        ;;   ❯ boom src/thing.spec.ts:2:25     vitest, a stack frame -- the
        ;;                                     function name comes FIRST, which is
        ;;                                     why the file is the last field
        ;;                                     rather than everything after the ❯
        ;;   at Object.<anonymous> (src/thing.spec.ts:4:19)   jest, and node
        ;;
        ;; The file may not contain a space or a colon. A path with a space in it
        ;; would be indistinguishable from the function name in front of it.
        (require 'compile)

        (dolist (rule
                 '((jest-vitest
                    "^[ \t]*❯[ \t]+\\(?:[^ \t\n]+[ \t]+\\)*\\([^ \t\n:]+\\):\\([0-9]+\\):\\([0-9]+\\)$"
                    1 2 3)
                   (jest-node-stack
                    "^[ \t]*at [^\n]*(\\([^()\n]+\\):\\([0-9]+\\):\\([0-9]+\\))$"
                    1 2 3)))
          (setf (alist-get (car rule) compilation-error-regexp-alist-alist) (cdr rule)))

        ;; Buffer-local, and in the mode hook rather than globally: these patterns
        ;; are loose enough to be worth confining to the buffer whose output they
        ;; describe.
        (defun my/jest-mode-error-patterns ()
          "Teach this run buffer where a JS test failure points."
          (setq-local compilation-error-regexp-alist
                      (append '(jest-vitest jest-node-stack)
                              compilation-error-regexp-alist)))

        (add-hook 'jest-mode-hook #'my/jest-mode-error-patterns)

        ;; dap + dap-ui + dap-virtual-text, all three in one package. dape reads
        ;; launch.json, so a project that already debugs in VS Code debugs here.
        (require 'dape)
        (setq dape-buffer-window-arrangement 'right
              dape-inlay-hints t)
        (add-hook 'dape-compile-hook #'kill-buffer)
  '';
}
