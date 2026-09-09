# development emacs plugins ai

{
  lib,
  pkgs,
  ...
}:
let

  # claude-code-ide.el, built from the Axiweave fork rather than taken from...

  # claude-code-ide.el, built from the Axiweave fork rather than taken from
  # nixpkgs, for one feature: the manager sidebar. A single pane listing every
  # live session across every project, each row prefixed with a state glyph,
  # =RET= to switch into it.

  # Neither alternative has that. nixpkgs carries stevemolitor's claude-code.el,
  # whose switcher only ever reaches the current project's session -- so a second
  # repository is unreachable the moment you leave its buffer. Upstream
  # claude-code-ide.el (manzaltu) has =claude-code-ide-list-sessions=, a
  # minibuffer list with no state and nothing remembered between calls.

  # Pinned by commit, not by tag: the fork is three days younger than this
  # module and does not tag.

  rev = "994549008acdf179041e5482c8085c30cf68de72";

  claude-code-ide-src = pkgs.fetchFromGitHub {
    owner = "Axiweave";
    repo = "claude-code-ide.el";
    inherit rev;
    hash = "sha256-3/GW3x4vPMuDcMnr5tc8QQu/nRdzR3zm8b6j7DoqMj0=";
  };
in
{
  imports = [ ./sessions.nix ];

  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      (melpaBuild {
        pname = "claude-code-ide";
        version = "0.2.6";
        commit = rev;
        src = claude-code-ide-src;

        # No :files, so package-build uses :defaults -- which excludes
        # *-tests.el. That matters here: claude-code-ide-tests.el is 15k lines
        # of ert, and it would otherwise be byte-compiled on every rebuild.
        recipe = pkgs.writeText "recipe" ''
          (claude-code-ide :fetcher github :repo "Axiweave/claude-code-ide.el")
        '';

        # websocket and web-server are required lazily, from inside the
        # functions that start the MCP transport, so byte-compilation does not
        # need them -- but the running Emacs does, and only a declared
        # dependency ends up on its load-path. flycheck is a soft require
        # (diagnostics fall back to flymake without it).
        packageRequires = [
          websocket
          web-server
          transient
          persist
          with-editor
          vterm
          flycheck
        ];

        meta = {
          description = "Claude Code integration for Emacs, with a multi-session manager sidebar";
          homepage = "https://github.com/Axiweave/claude-code-ide.el";
          license = lib.licenses.gpl3Plus;
        };
      })
      gptel
    ];

  programs.emacs.extraConfig = ''
    ;;; AI — claude-code-ide.el drives the Claude Code CLI; gptel is the chat
    ;;; buffer.
    ;;;
    ;;; Nothing in the nvim config to mirror here. The package runs the same
    ;;; `claude' binary the terminal does, inside a vterm, so it is one Claude
    ;;; session whichever editor is in front — and it hands Claude the region,
    ;;; a file reference, or the diagnostic under the cursor. It goes further
    ;;; than claude-code.el did in one direction that matters: an MCP server
    ;;; per session, exposing Emacs' own tooling — xref and the LSP behind it,
    ;;; tree-sitter, imenu, project.el, flycheck — as tools Claude can call.
    ;;;
    ;;; Sessions are workspaces. The first switch into one builds a layout
    ;;; (magit on the left, the session on the right) and switching away
    ;;; captures whatever layout you leave, so coming back restores it. That
    ;;; is the package's model rather than a setting, and it is why live
    ;;; sessions no longer want a `display-buffer-alist' rule of their own —
    ;;; see the drawer at the bottom of this file, which now covers only gptel
    ;;; and the read-only transcripts.

    ;; `use-side-window' nil, and the drawer at the foot of this file places
    ;; every Claude buffer instead. With it on, the package calls
    ;; `display-buffer-in-side-window' itself and its own width wins, so the
    ;; pane a session opened in depended on which command opened it -- the
    ;; package's toggle, the chat list, or the sidebar. One rule for all three.
    (setq claude-code-ide-cli-path "claude"
          claude-code-ide-use-side-window nil
          claude-code-ide-focus-on-open t)

    ;; The sidebar is a column of names and glyphs, so it wants far less width
    ;; than the session. It puts itself on the left, slot -1.
    (setq claude-code-ide-manager-window-width 26
          claude-code-ide-manager-persist-state t)

    ;; Without this the state glyphs are blank for a plain `claude' session.
    ;; The rich states — needs-input, done, failed — arrive over MCP from
    ;; agents that report their turn, which Claude Code does not; the hooks in
    ;; the claude-code module push them in from the CLI side instead. This
    ;; enables the other half, the output-derived fallback, which is what
    ;; draws the working glyph while a turn is in flight.
    (setq claude-code-ide-session-idle-default-enabled t
          claude-code-ide-session-idle-delay 4)

    ;; Everything else on SPC a carries its own autoload cookie; the manager
    ;; commands do not, so without these three the sidebar binding is void
    ;; until something else has pulled the package in. Declaring them keeps the
    ;; package lazy — loading it costs a websocket client, an HTTP server and a
    ;; set of per-session timers, none of which is wanted before a session
    ;; exists.
    ;;
    ;; Pointed at claude-code-ide rather than at claude-code-ide-manager, which
    ;; is where the commands actually live. The manager's own requires stop at
    ;; project.el and persist: it reaches the session registry through
    ;; `declare-function' and nothing else, so loading it alone gives a sidebar
    ;; that dies on void-function the moment it looks for a session. Loading the
    ;; entry point instead pulls in the manager as one of its requires, so
    ;; either order arrives complete.
    (autoload 'claude-code-ide-manager-toggle-global-sidebar "claude-code-ide" nil t)
    (autoload 'claude-code-ide-manager-toggle-repo-sidebar "claude-code-ide" nil t)
    (autoload 'claude-code-ide-manager-focus "claude-code-ide" nil t)

    (with-eval-after-load 'claude-code-ide
      (claude-code-ide-emacs-tools-setup))

    ;;; ------------------------------------------------------------------
    ;;; Theme colours for the session states
    ;;; ------------------------------------------------------------------
    ;;
    ;; The package paints its sidebar rows with fixed hex backgrounds and white
    ;; text -- #8a6a14 for gone-quiet, #3f6b4f for working, plain red for
    ;; needs-input. Those were chosen against some other background; on
    ;; doom-tokyo-night they are bands of mud with white on top, and the red row
    ;; is the least readable line on the screen.
    ;;
    ;; Re-specified as foreground only, inheriting the faces a theme is obliged
    ;; to define. `error', `warning' and `success' already mean stop, look and
    ;; done in every theme, so the states keep their meaning and the row keeps
    ;; the theme's own background -- including the transparency this config
    ;; applies to it.
    ;;
    ;; `custom-set-faces' rather than `set-face-attribute', for the reason the
    ;; colorscheme module documents: every new frame re-applies the theme's
    ;; specs and undoes an attribute set behind them.
    (custom-set-faces
     '(claude-code-ide-manager-current-session-face
       ((t (:inherit highlight :weight bold))))
     '(claude-code-ide-manager-current-marker-face
       ((t (:inherit success :weight bold))))
     '(claude-code-ide-manager-idle-session-face ((t (:inherit warning))))
     '(claude-code-ide-manager-working-session-face
       ((t (:inherit font-lock-keyword-face))))
     '(claude-code-ide-manager-attention-session-face
       ((t (:inherit error :weight bold))))
     '(claude-code-ide-manager-done-session-face ((t (:inherit success)))))

    ;;; ------------------------------------------------------------------
    ;;; The two panes
    ;;; ------------------------------------------------------------------
    ;;
    ;; Sidebar on the left, session on the right, the file being read between
    ;; them. Both edges toggle and neither moves.
    ;;
    ;; This replaces the package's workspace model, where the first switch into
    ;; a session ran `delete-other-windows' and rebuilt the frame around it --
    ;; magit on the left, the session on the right -- and switching away
    ;; captured whatever was left. Coherent, and not what is wanted here: a
    ;; session is a pane, not a desktop, and losing the window layout on the way
    ;; into a conversation is a high price for a magit buffer nobody asked for.
    ;; Bypassed rather than configured off, since it is the package's model
    ;; rather than a setting: `claude-code-ide-manager-switch-to-session' is
    ;; overridden below, so every route into a session -- the sidebar's RET, its
    ;; `n' and `p', a click on a row, the transient, a reattached zmx session --
    ;; lands in the pane rather than rebuilding the frame around it.

    (defun my/claude--pane-windows ()
      "Windows showing a Claude session on this frame."
      (seq-filter (lambda (win)
                    (and (fboundp 'claude-code-ide-session-buffer-p)
                         (claude-code-ide-session-buffer-p (window-buffer win))))
                  (window-list nil 'no-minibuffer)))

    (defun my/claude--pane-window ()
      "The window showing a Claude session on this frame, if one is."
      (car (my/claude--pane-windows)))

    (defun my/claude--collapse-stray-panes ()
      "Close the windows showing a session outside the drawer.
    One conversation at a time in one column is the point of the drawer, and a
    session in an ordinary window is a second pane doing the drawer's job. It is
    also sticky: `display-buffer-reuse-window' finds a window already showing
    the buffer before the drawer rule is ever consulted, so every later switch
    into that conversation goes back to the stray window."
      (dolist (win (my/claude--pane-windows))
        (when (and (window-live-p win)
                   (not (window-parameter win 'window-side))
                   (not (one-window-p)))
          (ignore-errors (delete-window win)))))

    (defun my/claude-show-session (key)
      "Show the session KEY in the Claude pane and put the point in it.
    `pop-to-buffer', so the drawer rule decides where it lands -- the same rule
    every other route to a session goes through."
      (let ((buf (claude-code-ide-manager--session-buffer key)))
        (unless (buffer-live-p buf)
          (user-error "That session is no longer running"))
        ;; Recency bookkeeping the package does on its own switch path, so
        ;; `claude-code-ide' still reopens the session last looked at.
        (when (fboundp 'claude-code-ide--touch-session)
          (ignore-errors (claude-code-ide--touch-session key)))
        (my/claude--collapse-stray-panes)
        (pop-to-buffer buf)))

    (defun my/claude-pane-toggle ()
      "Show or hide the Claude pane, leaving the session running behind it.
    Starts one when this project has none, which is what makes this the only
    binding needed to get to Claude from cold."
      (interactive)
      (require 'claude-code-ide)
      (if-let* ((win (my/claude--pane-window)))
          (delete-window win)
        (claude-code-ide)))

    (defun my/claude-sidebar-visit ()
      "Show the session on this sidebar row in the Claude pane."
      (interactive)
      (let ((item (claude-code-ide-manager--item-at-point)))
        (unless item (user-error "No session on this line"))
        (my/claude-show-session
         (claude-code-ide-manager-item-session-key item))))

    (defun my/claude-sidebar-peek ()
      "Show the session on this row but keep the point in the sidebar."
      (interactive)
      (save-selected-window (my/claude-sidebar-visit)))

    (with-eval-after-load 'claude-code-ide-manager
      (define-key claude-code-ide-manager-mode-map (kbd "RET") #'my/claude-sidebar-visit)
      (define-key claude-code-ide-manager-mode-map (kbd "SPC") #'my/claude-sidebar-peek)
      (with-eval-after-load 'evil
        (evil-define-key 'normal claude-code-ide-manager-mode-map
          (kbd "RET") #'my/claude-sidebar-visit
          (kbd "SPC") #'my/claude-sidebar-peek)))

    (defun my/claude--manager-switch-in-pane (session-key &optional keep-manager-focus scope)
      "Show SESSION-KEY in the Claude pane, in place of the package's workspace.

    The override for `claude-code-ide-manager-switch-to-session', which
    otherwise captures the frame's layout under the session being left, runs
    `delete-other-windows', and rebuilds the frame as a status buffer -- magit,
    or dired when magit is absent -- beside the session. Switching conversation
    is not switching project here: the pane is somewhere to talk to Claude, and
    the windows around it belong to whatever you were reading. A conversation
    that has nothing to do with the code in front of you is the ordinary case,
    not the exception.

    The sidebar's own bookkeeping is kept: the row for SESSION-KEY becomes the
    current one, its state glyph clears on the way in, and the recency order
    `claude-code-ide' reopens by is updated. KEEP-MANAGER-FOCUS leaves the point
    where it is, which is what the sidebar passes while `n' and `p' walk it."
      (let ((scope (or scope (claude-code-ide-manager--scope-for-command))))
        (unless (claude-code-ide-manager--ensure-live-target session-key scope)
          (user-error "No live session buffer for %s" session-key))
        ;; Best-effort on purpose: all of this only decides how the sidebar
        ;; draws itself, and a private function moving under the fork is not
        ;; worth an error between you and the conversation.
        (ignore-errors
          (setq claude-code-ide-manager--current-session-key session-key)
          (claude-code-ide-manager--set-scope-active-session-key scope session-key)
          (claude-code-ide-manager--mark-session-managed session-key)
          (claude-code-ide-manager--reset-session-idle-state session-key)
          (claude-code-ide-manager--save-state)
          (claude-code-ide-manager--refresh-sidebar-state scope nil))
        (if keep-manager-focus
            (save-selected-window (my/claude-show-session session-key))
          (my/claude-show-session session-key))
        (my/claude--pane-window)))

    (defun my/claude--manager-layout-in-pane (session-key &optional _scope)
      "Show SESSION-KEY in the pane and return the window it is in.
    The override for `claude-code-ide-manager--build-default-layout', which is
    what opens the project: it is the frame-rebuilding half of the workspace
    model, reached from the restore path and from `R' on a sidebar row. There is
    nothing to rebuild when the layout is one pane."
      (my/claude-show-session session-key)
      (my/claude--pane-window))

    (with-eval-after-load 'claude-code-ide-manager
      (advice-add 'claude-code-ide-manager-switch-to-session
                  :override #'my/claude--manager-switch-in-pane)
      (advice-add 'claude-code-ide-manager--build-default-layout
                  :override #'my/claude--manager-layout-in-pane))

    (defun my/claude-sidebar-open-maybe (&optional _frame)
      "Open the live-session sidebar on this frame, once.
    Per frame rather than once per Emacs: a side window belongs to a frame, and
    these are daemon frames -- `emacsclient -c' makes a new one every time, and
    each one starts without it.

    The frame parameter is what makes it once: without it, toggling the sidebar
    off and opening another frame would put it back on the first one too.

    `ignore-errors' because this runs on the path that creates a frame. The
    sidebar is worth having by default; it is not worth a frame that will not
    open.

    `save-selected-window', because opening the sidebar selects it and a frame
    must not open with the point in a side pane. The pane is in emacs state --
    so hnei do not move -- and every later hook that asks what the frame is
    showing gets the sidebar as the answer: the dashboard's own new-frame hook
    read that, decided the frame had something of its own to show, and stood
    down. A frame that opened on an empty strip with the point in it and no
    home screen behind it is what that looked like."
      (unless (frame-parameter nil 'my/claude-sidebar-shown)
        (set-frame-parameter nil 'my/claude-sidebar-shown t)
        (ignore-errors
          (require 'claude-code-ide)
          (save-selected-window
            (claude-code-ide-manager-toggle-global-sidebar)))))

    (add-hook 'server-after-make-frame-hook #'my/claude-sidebar-open-maybe)
    (add-hook 'emacs-startup-hook #'my/claude-sidebar-open-maybe)

    (defvar-local my/claude--transcript-path nil
      "Transcript the Claude session in this buffer is writing.
    The only exact handle between a running session and its file on disk:
    claude-code-ide's session id is its own and the CLI never sees it, while
    the CLI's id is not something the package is told. The hooks know both, so
    they carry the path across. `my/claude-chats' uses it to recognise that a
    row in the history and a row in the session list are one conversation.")

    (defun my/claude-set-session-state (buffer-name state &optional transcript)
      "Record STATE as the agent state of the Claude session in BUFFER-NAME.
    TRANSCRIPT, when given, is the conversation's file on disk.

    The entry point for the Claude Code hooks in the claude-code module, which
    reach it over emacsclient: the CLI knows it has stopped, or wants an
    answer, and only Emacs can draw that beside the session's name.

    The sidebar refreshes itself from here — claude-code-ide-manager advises
    the setter — so there is nothing to redraw by hand.

    Tolerant on purpose. It is called from outside Emacs with a name that may
    belong to a session that has since exited, and the setter it wraps errors
    on a buffer that is not a live session."
      (let ((buf (get-buffer buffer-name)))
        (when (and buf
                   (fboundp 'claude-code-ide-session-idle-set-agent-state)
                   (fboundp 'claude-code-ide-session-buffer-p))
          (with-current-buffer buf
            (when (claude-code-ide-session-buffer-p buf)
              (when (and transcript (not (string-empty-p transcript)))
                (setq-local my/claude--transcript-path transcript))
              (claude-code-ide-session-idle-set-agent-state state))))))

    (defun my/claude-send-region-or-file ()
      "Send the region to Claude, or a reference to this file when nothing is selected."
      (interactive)
      (if (use-region-p)
          (claude-code-ide-send-prompt
           (buffer-substring-no-properties (region-beginning) (region-end)))
        (claude-code-ide-send-current-file-line-reference)))

    (defun my/claude--diagnostic-at-point ()
      "Text of the diagnostic under point, from flycheck or flymake."
      (or (when-let* ((errs (and (bound-and-true-p flycheck-mode)
                                (fboundp 'flycheck-overlay-errors-at)
                                (flycheck-overlay-errors-at (point)))))
            (mapconcat #'flycheck-error-message errs "\n"))
          (when-let* ((diags (and (bound-and-true-p flymake-mode)
                                  (fboundp 'flymake-diagnostics)
                                  (flymake-diagnostics (point)))))
            (mapconcat #'flymake-diagnostic-text diags "\n"))))

    (defun my/claude-fix-diagnostic ()
      "Ask Claude to fix the diagnostic under point.
    claude-code-ide has no equivalent of claude-code.el's
    `claude-code-fix-diagnostic'; it exposes the diagnostics to Claude as an
    MCP tool instead, which is the right primitive but not a command. This is
    the command, built on `claude-code-ide-send-prompt' — the session already
    knows which file and line the point is on, so the prompt only has to carry
    the message itself."
      (interactive)
      (let ((msg (my/claude--diagnostic-at-point)))
        (unless msg
          (user-error "No diagnostic under point"))
        (claude-code-ide-send-prompt
         (format "Fix this error at %s:%d\n\n%s"
                 (if buffer-file-name
                     (file-name-nondirectory buffer-file-name)
                   (buffer-name))
                 (line-number-at-pos)
                 msg))))

    ;; gptel for the ask-a-question case, where a chat buffer beats a coding agent.
    ;; The key is read from the auth source at call time, never stored in the config:
    ;;   machine api.anthropic.com login apikey password <key>
    ;; in ~/.authinfo.gpg, which the existing gpg setup already unlocks.
    (require 'gptel)
    (setq gptel-default-mode 'markdown-mode
          gptel-model 'claude-sonnet-4-5-20250929
          gptel-backend (gptel-make-anthropic "Claude"
                          :stream t
                          :key (lambda ()
                                 (or (auth-source-pick-first-password
                                      :host "api.anthropic.com" :user "apikey")
                                     (getenv "ANTHROPIC_API_KEY")))))

    ;;; ------------------------------------------------------------------
    ;;; The drawer
    ;;; ------------------------------------------------------------------
    ;;
    ;; Every AI buffer lands in one column on the right, and the slot decides
    ;; where in that column. Without this a session went wherever the window
    ;; tree had room -- splitting the file being read, or replacing it, and
    ;; `C-x 1' discarded it outright. The terminals already solve this with a
    ;; bottom side window; this is the same arrangement on the right, where a
    ;; conversation's long lines fit far better than in a ten-line strip.
    ;;
    ;; The order down the column is the order things are used in. The chat list
    ;; is above the session because you pick from it and it closes; the session
    ;; is the one that stays. gptel and the read-only transcripts sit below,
    ;; so opening either beside a running session stacks them in the same
    ;; column instead of fighting over it.
    ;;
    ;;   -1  *claude chats*        the picker
    ;;    0  *claude-code[...]*    the session
    ;;    1  gptel
    ;;    2  *claude transcript:*

    (defvar my/ai-drawer-width 0.4
      "Fraction of the frame width the AI drawer occupies.")

    (defun my/ai-gptel-buffer-p (buffer &optional _alist)
      "Non-nil when BUFFER has gptel-mode turned on.

    A predicate rather than the `(derived-mode . gptel-mode)' condition this
    rule used to carry, which never matched anything: gptel-mode is a minor
    mode, and that condition tests the major mode -- so a chat buffer is
    markdown-mode with gptel-mode on top, and the rule looked right while
    silently doing nothing. gptel windows have been landing wherever the window
    tree had room this whole time."
      (let ((buf (get-buffer buffer)))
        (and (buffer-live-p buf)
             (buffer-local-value 'gptel-mode buf)
             t)))

    (dolist (rule `(("\\*claude chats\\*" . -1)
                    ("\\*claude-code\\[.*\\]\\*" . 0)
                    (my/ai-gptel-buffer-p . 1)
                    ("\\*claude transcript:.*\\*" . 2)))
      (add-to-list 'display-buffer-alist
                   `(,(car rule)
                     (display-buffer-reuse-window display-buffer-in-side-window)
                     (side . right)
                     (slot . ,(cdr rule))
                     (window-width . ,my/ai-drawer-width)
                     (preserve-size . (t . nil))
                     (window-parameters . ((no-delete-other-windows . t))))))

    (defun my/ai-drawer-close ()
      "Close the AI drawer, leaving the sessions running behind it.
    Deliberately narrower than `window-toggle-side-windows', which would take
    the bottom terminal down with it."
      (interactive)
      (dolist (win (window-list))
        (when (and (window-parameter win 'window-side)
                   (or (my/ai-gptel-buffer-p (window-buffer win))
                       (string-prefix-p "*claude" (buffer-name (window-buffer win)))))
          (delete-window win))))

  '';
}
