# development emacs plugins keybinds

{
  lib,
  ...
}:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      popper
      vterm
      vterm-toggle
    ];

  # Ordered at 1400: after every plugin block, so each command it names...

  # Ordered at 1400: after every plugin block, so each command it names already
  # exists, and before the Colemak rotation at 1500. The leader tree lives in
  # general's `override' keymap, which the rotation never touches — so these keys
  # mean the same thing in a magit buffer as in a source file.

  programs.emacs.extraConfig = lib.mkOrder 1400 ''
    ;;; The leader tree — every nvim which-key group, key for key and label for
    ;;; label.

    ;;; ------------------------------------------------------------------
    ;;; Terminals (toggleterm)
    ;;; ------------------------------------------------------------------

    (require 'vterm)
    (setq vterm-max-scrollback 10000
          vterm-kill-buffer-on-exit t
          vterm-copy-exclude-prompt t)

    ;; size = 10, direction = horizontal: a short window along the bottom, not a
    ;; buffer that steals the frame.
    (add-to-list 'display-buffer-alist
                 `("\\*term:.*\\*"
                   (display-buffer-reuse-window display-buffer-in-side-window)
                   (side . bottom)
                   (slot . 0)
                   (window-height . 10)
                   (dedicated . t)))

    (defun my/term-toggle (name)
      "Show or hide the bottom terminal called NAME, opened at the project root."
      (let* ((bufname (format "*term:%s*" name))
             (buffer (get-buffer bufname))
             (window (and buffer (get-buffer-window buffer))))
        (if window
            (delete-window window)
          (let ((default-directory (my/project-root)))
            (unless buffer
              (setq buffer (save-window-excursion (vterm bufname))))
            (pop-to-buffer buffer)
            (evil-insert-state)))))

    (defun my/term-main ()
      "Toggle the main terminal."
      (interactive)
      (my/term-toggle "main"))

    (defun my/term-extra ()
      "Toggle the second terminal."
      (interactive)
      (my/term-toggle "extra"))

    ;; Popup discipline for everything else that appears at the bottom: compile
    ;; output, test runs, help. popper keeps them out of the window layout.
    (require 'popper)
    (setq popper-reference-buffers
          '("\\*Messages\\*" "\\*Warnings\\*" "\\*compilation\\*" "\\*tests\\*"
            "\\*sonar\\*" "\\*devcontainer\\*" "\\*Backtrace\\*"
            help-mode helpful-mode compilation-mode)
          popper-window-height 15)
    (popper-mode 1)
    (popper-echo-mode 1)

    ;;; ------------------------------------------------------------------
    ;;; Window helpers
    ;;; ------------------------------------------------------------------

    (defun my/split-below-and-focus ()
      "Split downwards and move into the new window — <C-W>s<C-W>j."
      (interactive)
      (evil-window-split)
      (other-window 1))

    (defun my/split-right-and-focus ()
      "Split rightwards and move into the new window — <C-W>v<C-W>l."
      (interactive)
      (evil-window-vsplit)
      (other-window 1))

    ;;; ------------------------------------------------------------------
    ;;; Leader
    ;;; ------------------------------------------------------------------

    (my/leader
      "SPC" '(execute-extended-command :which-key "run command")
      "TAB" '(evil-switch-to-windows-last-buffer :which-key "last buffer")
      "'"   '(my/term-main :which-key "toggle terminal")
      "/"   '(my/term-extra :which-key "toggle extra terminal")
      "c"   '(my/add-cursors :which-key "add cursor")

      ;; ai — no nvim counterpart; the Claude Code CLI, in the editor.
      "a"  '(:ignore t :which-key "ai")
      "aa" '(my/claude-toggle :which-key "toggle claude")
      "ab" '(my/claude-send-region-or-file :which-key "send region or file")
      "ac" '(gptel :which-key "chat")
      "ad" '(claude-code-fix-diagnostic :which-key "fix diagnostic at point")
      "af" '(claude-code-insert-current-file-path-to-session :which-key "send file reference")
      "ag" '(my/claude-search :which-key "search all conversations")
      "ah" '(my/claude-resume :which-key "resume conversation (C-u: any project)")
      "aH" '(my/claude-view :which-key "view transcript (C-u: any project)")
      "al" '(my/claude-switch :which-key "switch live session")
      "am" '(claude-code-transient :which-key "claude menu")
      "ax" '(my/ai-drawer-close :which-key "close drawer")
      "aq" '(claude-code-quit :which-key "quit claude")
      "as" '(gptel-send :which-key "send to chat")
      "aw" '(gptel-rewrite :which-key "rewrite region")

      ;; buffers
      "b"  '(:ignore t :which-key "buffers")
      "bb" '(consult-buffer :which-key "find buffer")
      "bd" '(kill-current-buffer :which-key "destroy buffer")
      "bh" '(my/dashboard-home :which-key "home buffer")
      "bk" '(my/kill-buffer-force :which-key "kill buffer")

      ;; diagnostics
      "d"  '(:ignore t :which-key "diagnostics")
      "db" '(my/diagnostics-buffer :which-key "buffer diagnostics")
      "dl" '(flycheck-list-errors :which-key "loclist")
      "dq" '(consult-compile-error :which-key "quickfixes")
      "dr" '(lsp-treemacs-references :which-key "references")
      "dt" '(my/diagnostics-list :which-key "toggle trouble")

      ;; errors
      "e"  '(:ignore t :which-key "errors")
      "ed" '(my/diagnostic-at-point :which-key "show diagnostics for cursor")
      "eD" '(my/diagnostic-explain :which-key "show diagnostics for line")
      "ee" '(flycheck-previous-error :which-key "prev")
      "en" '(flycheck-next-error :which-key "next")

      ;; files
      "f"  '(:ignore t :which-key "files")
      "fd" '(my/find-files-in-dir :which-key "find files in dir")
      "ff" '(my/find-files :which-key "find files")
      "fr" '(my/recent-files :which-key "recent files")
      "fR" '(my/reload-config :which-key "reload configuration")
      "fs" '(save-buffer :which-key "save files")
      "ft" '(my/treemacs-toggle :which-key "toggle filetree")

      ;; git
      "g"  '(:ignore t :which-key "git")
      "ga" '(my/git-add-all :which-key "add .")
      "gb" '(magit-branch-checkout :which-key "branches")
      "gB" '(browse-at-remote :which-key "git browse")
      "gc" '(magit-commit :which-key "commit")
      "gd" '(magit-diff-unstaged :which-key "diff")
      "gD" '(magit-diff-buffer-file :which-key "diff split")
      "ge" '(diff-hl-previous-hunk :which-key "prev hunk")
      "gf" '(forge-dispatch :which-key "forge (PRs, MRs, issues)")
      "gA" '(my/gitlab-approve-mr :which-key "approve MR (gitlab)")
      "gC" '(forge-create-post :which-key "comment on MR/issue")
      "gM" '(my/forge-mr-diff :which-key "review MR diff")
      "gU" '(my/gitlab-unapprove-mr :which-key "unapprove MR (gitlab)")
      "gg" '(magit-status :which-key "status")
      "gh" '(my/git-toggle-blame :which-key "highlight hunks")
      "gH" '(diff-hl-show-hunk :which-key "preview hunk")
      "gl" '(magit-log-current :which-key "log")
      "gm" '(magit-branch :which-key "toggle merginal")
      "gn" '(diff-hl-next-hunk :which-key "next hunk")
      "go" '(my/git-browse-repo :which-key "open repo")
      "gp" '(magit-push :which-key "push")
      "gP" '(magit-pull :which-key "pull")
      "gr" '(magit-file-delete :which-key "rm")
      "gs" '(my/git-stage-hunk :which-key "stage hunk")
      "gt" '(my/git-toggle-signs :which-key "toggle gutter signs")
      "gT" '(git-timemachine :which-key "time machine")
      "gu" '(diff-hl-revert-hunk :which-key "undo hunk")
      "gv" '(magit-log-all :which-key "view commits")
      "gV" '(magit-log-buffer-file :which-key "view buffer commits")
      "gy" '(git-link :which-key "yank link")

      ;; jump
      "j"  '(:ignore t :which-key "jump")
      "jb" '(my/jump-word-above :which-key "word backwards")
      "jf" '(my/jump-word-below :which-key "word forward")
      "jj" '(my/jump-char :which-key "char")
      "jJ" '(my/jump-char-2 :which-key "2 chars")
      "jl" '(my/jump-line :which-key "line bidirectional")
      "jw" '(my/jump-word :which-key "word bidirectional")

      ;; lsp
      "l"  '(:ignore t :which-key "lsp")
      "lh" '(lsp-ui-doc-glance :which-key "hover doc popup")
      "lb" '(my/diagnostics-buffer :which-key "buffer diagnostics")
      "lc" '(lsp-execute-code-action :which-key "code action")
      "ld" '(consult-lsp-diagnostics :which-key "diagnostics")
      "le" '(flycheck-previous-error :which-key "prev diagnostic")
      "li" '(lsp-describe-session :which-key "info")
      "ln" '(flycheck-next-error :which-key "next diagnostic")
      "lq" '(flycheck-list-errors :which-key "quickfix")
      "lr" '(my/lsp-restart :which-key "restart server")
      "ls" '(consult-lsp-file-symbols :which-key "document symbols")
      "lS" '(consult-lsp-symbols :which-key "workspace symbols")

      ;; notes
      "n"  '(:ignore t :which-key "notes")
      "nn" '(my/obsidian-new :which-key "new note")
      "nN" '(my/obsidian-new-from-template :which-key "new note with template")
      "no" '(my/obsidian-open-note :which-key "open note")
      "nO" '(my/obsidian-open-app :which-key "open app")

      ;; help — diagnostics worth sending to someone else.
      "h"  '(:ignore t :which-key "help")
      "hr" '(my/emacs-report :which-key "write diagnostics report")
      "hp" '(my/report-profiler-start :which-key "start profiler")
      "hP" '(my/report-profiler-stop :which-key "stop profiler + write")
      "hk" '(describe-key :which-key "describe key")
      "hf" '(describe-function :which-key "describe function")
      "hv" '(describe-variable :which-key "describe variable")

      ;; What can I press *here*. which-key already knows every binding the
      ;; current buffer has; these just ask it to draw them without waiting for
      ;; a prefix. It is the answer to "what are the keys in this mu4e /
      ;; telega / smudge buffer", which is otherwise C-h m and a wall of prose.
      ;;
      ;; SPC ? is the buffer's own major-mode map; SPC h ? adds everything it
      ;; inherits, which is longer and usually not what you wanted first.
      "?"  '(which-key-show-major-mode :which-key "keys in this buffer")
      "h?" '(which-key-show-full-major-mode :which-key "keys in this buffer (full)")

      ;; agenda — org owns dates and tasks; notes stay in Obsidian under "n".
      "k"  '(:ignore t :which-key "agenda")
      "kk" '(my/org-agenda-today :which-key "today")
      "ka" '(org-agenda :which-key "agenda menu")
      "kc" '(org-capture :which-key "capture")
      "kt" '(my/org-todos :which-key "todo list")
      "ki" '(my/org-inbox :which-key "open inbox")

      ;; music — the running Spotify client, same one the menu bar item reports.
      "m"  '(:ignore t :which-key "music")
      ;; nix-config -- edit, rebuild, and the housekeeping around it.
      ;;
      ;; N, not c: SPC c is already my/add-cursors. Declaring it a prefix threw
      ;; "Key sequence SPC c e starts with non-prefix key SPC c" at load, which
      ;; aborted the whole init file -- so the Colemak rotation, every leader
      ;; section defined below this point, and the Claude session index all
      ;; silently failed to load. One binding conflict, three unrelated-looking
      ;; symptoms.
      "N"  '(:ignore t :which-key "nix config")
      "Ne" '(my/config-edit :which-key "edit config (literate)")
      "Nr" '(my/config-rebuild :which-key "rebuild")
      "NR" '(my/emacs-restart :which-key "restart emacs daemon")
      "Nu" '(my/config-update :which-key "update inputs + rebuild")
      "Ng" '(my/config-gc :which-key "collect garbage")
      "Np" '(my/config-pins :which-key "check pins")
      "Nt" '(my/config-tangle-check :which-key "check tangle drift")
      "Nd" '(my/config-diff :which-key "diff last generation")

      ;; mail -- `m' is music, so the inbox gets `i'
      "i"  '(:ignore t :which-key "inbox")
      "ii" '(mu4e :which-key "open mail")
      "ic" '(mu4e-compose-new :which-key "compose")
      "is" '(mu4e-search :which-key "search mail")
      "iu" '(mu4e-update-mail-and-index :which-key "fetch now")

      "mm" '(my/music-playpause :which-key "play/pause")
      "mn" '(my/music-next :which-key "next track")
      "mp" '(my/music-previous :which-key "previous track")
      "mc" '(my/music-current :which-key "what is playing")
      "mo" '(my/music-open :which-key "open spotify")
      ;; smudge, over the Web API -- these reach librespot and the phone alike,
      ;; where the osascript commands above only reach a running desktop app.
      "ms" '(smudge-track-search :which-key "search tracks")
      "ml" '(smudge-my-playlists :which-key "my playlists")
      "md" '(smudge-select-device :which-key "select device")
      "ma" '(my/smudge-album-search :which-key "search albums")
      "mr" '(smudge-controller-toggle-repeat :which-key "toggle repeat")
      ;; x for mix: s is already search, and shuffle deserves a key you can
      ;; hit without thinking about which of the two you meant.
      "mx" '(smudge-controller-toggle-shuffle :which-key "toggle shuffle")
      "m=" '(my/music-louder :which-key "louder")
      "m-" '(my/music-quieter :which-key "quieter")

      ;; open — the app surfaces that have no nvim equivalent.
      "o"  '(:ignore t :which-key "open")
      "oc" '(my/devcontainer-up :which-key "devcontainer up + shell")
      "oC" '(my/devcontainer-open :which-key "reopen in container")
      "od" '(docker :which-key "docker")
      "oD" '(my/dashboard :which-key "dashboard")
      "of" '(my/devcontainer-find-file :which-key "file in container")
      "oe" '(my/devcontainer-shell :which-key "shell in container")
      "oX" '(my/devcontainer-down :which-key "stop container")
      "ob" '(my/browse-url-at-point :which-key "browser (in emacs)")
      "og" '(my/open-gchat :which-key "google chat")
      "oG" '(my/open-gmail :which-key "gmail (web)")
      "oh" '(restclient-mode :which-key "http scratchpad")
      "oj" '(my/open-jira :which-key "jira (in emacs)")
      "oJ" '(my/open-jira-external :which-key "jira (system browser, for SSO)")
      "ow" '(my/open-confluence :which-key "confluence (in emacs)")
      "om" '(my/open-meet :which-key "google meet")
      "oM" '(my/open-meet-next :which-key "join next meeting")
      "os" '(my/sql-postgres :which-key "postgres")
      "oS" '(my/sonar-scan :which-key "sonar scan")
      "ot" '(telega :which-key "telegram")

      ;; projects
      "p"  '(:ignore t :which-key "projects")
      "pe" '(my/consult-env :which-key "environment variables")
      "pf" '(projectile-find-file :which-key "find files")
      "pp" '(consult-projectile-switch-project :which-key "switch")
      "ps" '(my/search-project :which-key "search")
      "pS" '(my/search-project-regex :which-key "search regex")
      "pt" '(my/todos-project :which-key "TODOs")

      ;; quit
      "q"  '(:ignore t :which-key "quit")
      "qq" '(my/quit-frame :which-key "close frame")
      "qQ" '(my/quit-force :which-key "quit without saving")

      ;; replace
      "r"  '(:ignore t :which-key "replace")
      "rb" '(my/replace-buffer :which-key "buffer")
      "rp" '(my/replace-project :which-key "project")
      "rw" '(my/replace-word-buffer :which-key "word in buffer")
      "rW" '(my/replace-word-project :which-key "word in project")

      ;; search
      "s"  '(:ignore t :which-key "search")
      "sp" '(my/search-project :which-key "project")
      "sP" '(my/search-project-regex :which-key "project regex")
      "ss" '(consult-line :which-key "buffer")
      "sS" '(my/search-buffer-regex :which-key "buffer regex")
      "st" '(consult-imenu :which-key "buffer tags")
      "sT" '(consult-imenu-multi :which-key "project tags")

      ;; test
      "t"  '(:ignore t :which-key "test")
      "tf" '(my/test-file :which-key "file")
      "tl" '(my/test-last :which-key "last")
      "tn" '(my/test-nearest :which-key "nearest")
      "to" '(my/test-output :which-key "output")
      "ts" '(my/test-summary :which-key "toggle summary")
      "td" '(dape :which-key "debug")

      ;; toggles. precognition and hardtime have no Emacs counterpart, so SPC T p is
      ;; gone; what replaces it are the toggles that do exist.
      "T"  '(:ignore t :which-key "toggles")
      "Tb" '(my/git-toggle-blame :which-key "inline blame")
      "Ti" '(highlight-indent-guides-mode :which-key "indent guides")
      "Tl" '(display-line-numbers-mode :which-key "line numbers")
      "Tm" '(my/toggle-markdown-markup :which-key "markdown markup")
      "TI" '(my/toggle-markdown-images :which-key "markdown images")
      "Ts" '(evil-ex-nohighlight :which-key "search highlight")
      "Tt" '(my/toggle-twilight :which-key "twilight")
      "Tw" '(visual-line-mode :which-key "wrap")
      "Tz" '(my/toggle-zen :which-key "zen")

      ;; windows
      "w"  '(:ignore t :which-key "windows")
      "wd" '(evil-window-delete :which-key "close")
      "we" '(evil-window-up :which-key "up")
      "wE" '(evil-window-decrease-height :which-key "expand up")
      "wh" '(evil-window-left :which-key "left")
      "wH" '(evil-window-decrease-width :which-key "expand left")
      "wi" '(evil-window-right :which-key "right")
      "wI" '(evil-window-increase-width :which-key "expand right")
      "wn" '(evil-window-down :which-key "down")
      "wN" '(evil-window-increase-height :which-key "expand down")
      "wo" '(delete-other-windows :which-key "close others")
      "wr" '(evil-window-rotate-downwards :which-key "rotate")
      "ws" '(my/split-below-and-focus :which-key "split down")
      "wv" '(my/split-right-and-focus :which-key "split right")
      "w=" '(balance-windows :which-key "balance")

      ;; text
      "x"  '(:ignore t :which-key "text")
      "xd" '(delete-trailing-whitespace :which-key "delete trailing whitespace")
      "xf" '(my/format-buffer :which-key "format buffer"))

    ;;; ------------------------------------------------------------------
    ;;; Localleader
    ;;; ------------------------------------------------------------------

    (my/localleader
      ;; The emmet leader in nvim is also ",", so ", ," expands the abbreviation —
      ;; which is how HTML5 and CSS3 authoring actually happens.
      ","  '(emmet-expand-line :which-key "expand emmet")

      ;; go to
      "g"  '(:ignore t :which-key "go to")
      "gd" '(lsp-find-definition :which-key "definition")
      "gD" '(lsp-find-declaration :which-key "declaration")
      "gI" '(lsp-find-implementation :which-key "implementation")
      "gr" '(lsp-find-references :which-key "references")
      "gT" '(lsp-find-type-definition :which-key "type definition")
      "gx" '(browse-url-at-point :which-key "open link")

      ;; code
      "c"  '(:ignore t :which-key "code")
      "ca" '(lsp-execute-code-action :which-key "code action")
      "cd" '(my/diagnostic-at-point :which-key "diagnostics")
      "cf" '(my/format-buffer :which-key "format")
      "cn" '(my/symbol-outline :which-key "navigate")
      "cr" '(lsp-rename :which-key "rename")
      "cR" '(my/lsp-restart :which-key "restart server")

      ;; extract. The server implements the refactor.extract kind, which covers
      ;; block, function and variable in one action picker. refactoring.nvim's
      ;; extract-to-a-new-file variants (ceB, ceF) have no equivalent anywhere in
      ;; Emacs and are deliberately left unbound rather than faked.
      "ce"  '(:ignore t :which-key "extract")
      "ceb" '(my/lsp-extract :which-key "block")
      "cef" '(my/lsp-extract :which-key "function")
      "cev" '(my/lsp-extract :which-key "variable")
      "cem" '(emr-show-refactor-menu :which-key "menu")

      ;; inline
      "ci"  '(:ignore t :which-key "inline")
      "cif" '(my/lsp-inline :which-key "function")
      "civ" '(my/lsp-inline :which-key "variable"))
  '';
}
