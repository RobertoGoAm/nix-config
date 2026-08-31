# development emacs plugins lsp lsp

{
  lib,
  pkgs,
  ...
}:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      consult-lsp
      lsp-mode
      lsp-pyright
      lsp-treemacs
      lsp-ui
    ];

  # The servers themselves. nixvim wires these into nvim for you; here...

  # The servers themselves. nixvim wires these into nvim for you; here they go on
  # PATH and lsp-mode finds them there (the daemon gets the login PATH via
  # exec-path-from-shell, set up in plugins/vim/default.nix).

  home.packages = with pkgs; [
    angular-language-server
    bash-language-server
    emmet-language-server
    gopls
    haskell-language-server
    htmx-lsp
    lua-language-server
    nixd
    prisma-language-server
    pyright
    sqls
    tailwindcss-language-server
    typescript
    typescript-language-server
    vscode-langservers-extracted
    vue-language-server
    yaml-language-server
  ];

  programs.emacs.extraConfig = ''
        ;;; LSP — lsp-mode in place of nvim-lspconfig, lsp-ui in place of lspsaga.

        (require 'lsp-mode)
        (require 'lsp-ui)
        ;; lsp-mode ships a semgrep client that activates purely because the
        ;; `semgrep' binary is on PATH -- and it is, as a DevOps CLI from
        ;; hosts/*/packages.nix, never as a language server. On every buffer it
        ;; tried to fetch a ruleset and failed:
        ;;
        ;;   LSP :: Fatal error: Failed to download config from https://semgrep.dev/...
        ;;
        ;; Scanning stays a deliberate CLI step; nothing here wants it per-keystroke
        ;; or wants an editor that needs the network to open a file.
        (setq lsp-disabled-clients '(semgrep-ls semgrep-ls-tramp))

        (require 'consult-lsp)
        ;; Provides the symbol tree and the error/reference lists the leader tree binds.
        (require 'lsp-treemacs)

        ;; Our own leader owns the keys, so lsp-mode's prefix is switched off.
        (setq lsp-keymap-prefix nil
              ;; updatetime = 300
              lsp-idle-delay 0.3
              ;; 10s (the default) is not enough for the first request against a
              ;; large Nuxt or Angular project: ts-ls and the Vue server are still
              ;; indexing, textDocument/completion times out, and what you see is
              ;; an editor with no completion rather than one still warming up.
              ;; Raising it trades a slower first response for one that arrives.
              lsp-response-timeout 30
              ;; tsserver's default heap is modest for a monorepo-sized project,
              ;; and it degrades to no completions rather than to an error.
              lsp-clients-typescript-max-ts-server-memory 4096
              lsp-log-io nil
              ;; corfu drives completion, not company.
              lsp-completion-provider :none
              lsp-diagnostics-provider :flycheck
              ;; lspsaga symbol_in_winbar
              lsp-headerline-breadcrumb-enable t
              lsp-headerline-breadcrumb-icons-enable t
              ;; lsp.inlayHints = true
              lsp-inlay-hint-enable t
              lsp-modeline-code-actions-enable t
              ;; doom-modeline already carries the diagnostic counts.
              lsp-modeline-diagnostics-enable nil
              lsp-eldoc-enable-hover t
              lsp-eldoc-render-all nil
              lsp-signature-auto-activate '(:on-trigger-char :after-completion)
              lsp-signature-render-documentation nil
              ;; illuminate's job: highlight the other uses of the symbol at point.
              lsp-enable-symbol-highlighting t
              lsp-enable-snippet t
              lsp-enable-file-watchers t
              lsp-file-watch-threshold 4000
              lsp-semantic-tokens-enable t
              lsp-lens-enable nil
              ;; Formatting is apheleia's job (see format.nix), so lsp-mode must not
              ;; also reformat on save or the two fight over the buffer.
              lsp-enable-on-type-formatting nil
              lsp-enable-indentation nil)

        ;; lsp-ui stands in for lspsaga: hover docs at point, diagnostics and the code
        ;; action lightbulb on the sideline, peek windows for definitions/references.
        (setq lsp-ui-doc-enable t
              lsp-ui-doc-position 'at-point
              ; The doc popup was enabled but unreachable: show-with-cursor and
              ; show-with-mouse were both nil and nothing bound lsp-ui-doc-glance,
              ; so it could never appear. It follows the cursor now.
              lsp-ui-doc-show-with-cursor t
              lsp-ui-doc-show-with-mouse nil
              ; Slower than the 0.2 default: at 0.2 the popup chases the cursor
              ; through ordinary movement, half a second lets it appear when you
              ; stop to look at something.
              lsp-ui-doc-delay 0.5
              lsp-ui-doc-max-height 20
              ; 100 was wider than the frame: at 77 columns the popup ran past the
              ; right edge and the type was cut mid-word rather than wrapped. Set
              ; from the frame on each show so it fits whatever width is in use,
              ; leaving room for the fringe and the popup's own border.
              lsp-ui-doc-max-width 80
              ; Sideline off: it renders at end of line, exactly where blamer
              ; draws, so the two fought over the same space. End of line is now
              ; blame's; types AND code actions go to the doc popup (see the
              ; advice below), diagnostics to the flycheck posframe.
              lsp-ui-sideline-enable nil
              lsp-ui-sideline-show-diagnostics nil
              lsp-ui-sideline-show-code-actions nil
              lsp-ui-sideline-show-hover nil
              ;; lspsaga ui.code_action = "💡"
              lsp-ui-sideline-code-actions-prefix "💡 "
              lsp-ui-peek-enable t
              lsp-ui-peek-show-directory t
              lsp-ui-imenu-auto-refresh t)

        ;; The popup is sized per show rather than pinned: a fixed width is
        ;; either too wide for a split or wastes a wide frame, and this file is
        ;; shared by both machines and every window layout.
        (defun my/lsp-ui-doc-fit-frame (&rest _)
          "Keep the doc popup inside the current window."
          (setq lsp-ui-doc-max-width (max 40 (- (window-body-width) 8))))

        ;; One character of slack on the frame, so the last glyph is not clipped.
        ;;
        ;; lsp-ui-doc--move-frame measures the rendered text with
        ;; window-text-pixel-size and adds exactly one character of margin:
        ;;
        ;;   (width (+ width (* char-w 1)))  ;; margins
        ;;
        ;; That one character has to cover the 1px internal border on both sides
        ;; and any glyph the measurement rounds down, so a line that reaches the
        ;; full width of the popup loses its last character behind the border --
        ;; which is why a type ending in `>' showed up ending in the border
        ;; instead. Widening after the fact is the least invasive fix: the
        ;; positioning logic has already run and is left alone.
        (defun my/lsp-ui-doc-slack (frame)
          "Widen FRAME by one character so its last glyph clears the border."
          (when (frame-live-p frame)
            (let ((frame-resize-pixelwise t))
              (set-frame-size frame
                              (+ (frame-pixel-width frame) (frame-char-width frame))
                              (frame-pixel-height frame)
                              t))))

        ;; Code actions in the hover popup.
        ;;
        ;; The sideline is off because it draws at end of line, where blame
        ;; lives, and the code action lightbulb went with it -- leaving a
        ;; modeline segment as the only sign that a refactor was available.
        ;;
        ;; lsp-modeline-code-actions-mode is already running and already keeps
        ;; the current buffer's actions in a string, so reading it here costs no
        ;; extra request to the server and puts the actions where the types are.
        ;; lsp-ui-doc--display is called with the source buffer current -- it is
        ;; guarded by (eq buffer (current-buffer)) one frame up -- so the
        ;; buffer-local cache is the right one.
        (defun my/lsp-ui-doc-code-actions ()
          "Code actions available at point as plain text, or nil if there are none."
          (let ((s (and (bound-and-true-p lsp-modeline--code-actions-string)
                        (string-trim
                         (substring-no-properties lsp-modeline--code-actions-string)))))
            (unless (or (null s) (string-empty-p s)) s)))

        (defun my/lsp-ui-doc-with-actions (args)
          "Append the code actions at point to the hover string in ARGS."
          (let ((symbol (nth 0 args))
                (string (nth 1 args))
                (actions (my/lsp-ui-doc-code-actions)))
            (if (and string (not (string-empty-p string)) actions)
                (list symbol (concat string "\n\n---\n\n" actions))
              args)))

        (with-eval-after-load 'lsp-ui
          (advice-add 'lsp-ui-doc--make-frame :before #'my/lsp-ui-doc-fit-frame)
          (advice-add 'lsp-ui-doc-glance :before #'my/lsp-ui-doc-fit-frame)
          (advice-add 'lsp-ui-doc--move-frame :after #'my/lsp-ui-doc-slack)
          (advice-add 'lsp-ui-doc--display :filter-args #'my/lsp-ui-doc-with-actions))

        ;; The inlay hints from the ts_ls extraOptions block, setting for setting. One
        ;; set of variables covers both languages: lsp-mode maps each
        ;; lsp-javascript-display-* onto *both* the "javascript.inlayHints.*" and
        ;; "typescript.inlayHints.*" server paths, which is exactly the pair the nvim
        ;; config writes out twice.
        (setq lsp-javascript-display-enum-member-value-hints t
              lsp-javascript-display-return-type-hints t
              lsp-javascript-display-parameter-type-hints t
              lsp-javascript-display-parameter-name-hints "all"
              lsp-javascript-display-parameter-name-hints-when-argument-matches-name t
              lsp-javascript-display-property-declaration-type-hints t
              lsp-javascript-display-variable-type-hints t)

        ;; nixd, with nixfmt as its formatter — same as the nixd settings block.
        (setq lsp-nix-nixd-server-path "${lib.getExe pkgs.nixd}"
              lsp-nix-nixd-formatting-command ["${lib.getExe pkgs.nixfmt}"])

        ;; Vue: ts-ls carries the Volar TypeScript plugin, so it belongs on .vue
        ;; buffers rather than being kept off them.
        ;;
        ;; Volar 3 is hybrid-only -- it hands TypeScript to tsserver through
        ;; @vue/typescript-plugin and does none itself. lsp-volar appends that
        ;; plugin to lsp-clients-typescript-plugins, but only if it can find it,
        ;; and its two guesses are npm layouts:
        ;;
        ;;   <pkg>/lib/node_modules/@vue/language-server/     absent here
        ;;   <resolved bin>/../..                             the store root, no node_modules
        ;;
        ;; nixpkgs builds it as a pnpm workspace instead, so both miss, no plugin
        ;; is registered, and Volar reports that ts-ls is not carrying it. The
        ;; language-server package directory is a real resolution root -- node
        ;; resolves @vue/typescript-plugin from there -- so name it explicitly.
        ;; No semantic tokens in web-mode, which here is .vue and .html.
        ;;
        ;; Hybrid Volar means two servers on one buffer, and both ts-ls and
        ;; vue-semantic-server advertise semanticTokensProvider. lsp-mode asks
        ;; every workspace and hands the handler the list of replies, which
        ;; expects a single one:
        ;;
        ;;   Error processing message (wrong-type-argument hash-table-p (#s(...) #s(...)))
        ;;
        ;; on every edit. Removing the capability from one workspace after
        ;; initialisation does not help -- the request is already keyed on the
        ;; buffer's own state -- so tokens are off for these buffers. web-mode
        ;; does its own font-lock, and .ts/.tsx keep semantic tokens because they
        ;; only ever have one server.
        (add-hook 'web-mode-hook (lambda () (setq-local lsp-semantic-tokens-enable nil)))

        (setq lsp-volar-location-for-typescript-plugin
              "${pkgs.vue-language-server}/lib/language-tools/packages/language-server")

        ;; pyright, and Angular pointed at the nix-built ngserver.
        (require 'lsp-pyright)
        (setq lsp-clients-angular-language-server-command
              '("${lib.getExe pkgs.angular-language-server}"
                "--stdio"
                "--tsProbeLocations" "${pkgs.typescript}/lib/node_modules"
                "--ngProbeLocations" "${pkgs.angular-language-server}/lib/node_modules"))

        ;; lsp-mode ships no Tailwind client and the community lsp-tailwindcss package
        ;; is not in nixpkgs, so register the server by hand. `:add-on? t' is the load
        ;; bearing part: Tailwind has to run *alongside* ts-ls or volar rather than
        ;; replacing them, which is how class completion shows up inside a .vue or .tsx
        ;; buffer instead of only in plain CSS. Vuetify and MUI need nothing extra —
        ;; their component types come through ts-ls/volar like any other dependency.
        (lsp-register-client
         (make-lsp-client
          :new-connection (lsp-stdio-connection
                           (lambda ()
                             (list "${lib.getExe pkgs.tailwindcss-language-server}" "--stdio")))
          :activation-fn (lambda (_file-name mode)
                           (memq mode '(html-mode html-ts-mode mhtml-mode web-mode
                                        css-mode css-ts-mode scss-mode less-css-mode
                                        js-mode js-ts-mode jsx-mode tsx-ts-mode
                                        typescript-mode typescript-ts-mode)))
          :server-id 'tailwindcss-ls
          :add-on? t
          :priority -1))

        (lsp-register-custom-settings
         '(("tailwindCSS.validate" "error")
           ("tailwindCSS.classAttributes" ["class" "className" "ngClass" "classList"])
           ("tailwindCSS.emmetCompletions" t t)))

        ;; Prisma's server, for schema.prisma alongside the Drizzle/TS work.
        (lsp-register-client
         (make-lsp-client
          :new-connection (lsp-stdio-connection
                           (lambda ()
                             (list "${lib.getExe pkgs.prisma-language-server}" "--stdio")))
          :activation-fn (lambda (_file-name mode) (eq mode 'prisma-mode))
          :server-id 'prisma-ls))

        ;; Which buffers get a server. lsp-deferred waits until the buffer is actually
        ;; visible, so opening twenty files from a grep does not start twenty servers.
        (dolist (hook '(bash-ts-mode-hook
                        css-ts-mode-hook
                        dockerfile-ts-mode-hook
                        go-ts-mode-hook
                        haskell-mode-hook
                        html-mode-hook
                        js-ts-mode-hook
                        json-ts-mode-hook
                        lua-ts-mode-hook
                        mhtml-mode-hook
                        nix-ts-mode-hook
                        prisma-mode-hook
                        python-ts-mode-hook
                        scss-mode-hook
                        sh-mode-hook
                        tsx-ts-mode-hook
                        typescript-ts-mode-hook
                        web-mode-hook
                        yaml-ts-mode-hook))
          (add-hook hook #'lsp-deferred))

        (add-hook 'lsp-mode-hook #'lsp-ui-mode)

        (defun my/lsp-signature-help ()
          "Signature help for the symbol at point, whichever backend is live.
    Bound to C-k in normal and insert state, as the LspAttach autocmd does."
          (interactive)
          (cond
           ((and (bound-and-true-p lsp-mode) (fboundp 'lsp-signature-activate))
            (lsp-signature-activate))
           ((fboundp 'eldoc-print-current-symbol-info)
            (eldoc-print-current-symbol-info))
           (t (message "No signature help here"))))

        (defun my/lsp-code-action-kind (kind)
          "Run the code action of KIND at point, e.g. \"refactor.extract\".
    This is how the localleader extract and inline keys work: refactoring.nvim's
    tree-sitter rewrites have no Emacs equivalent, but every language server in this
    config implements the standard refactor.* code action kinds, which covers the
    common cases for TypeScript, Vue and Python."
          (if (bound-and-true-p lsp-mode)
              (condition-case err
                  (lsp-execute-code-action-by-kind kind)
                (error (message "No %s action available here (%s)"
                                kind (error-message-string err))))
            (message "lsp-mode is not active in this buffer")))

        (defun my/lsp-extract () "Extract refactoring at point." (interactive)
               (my/lsp-code-action-kind "refactor.extract"))
        (defun my/lsp-inline () "Inline refactoring at point." (interactive)
               (my/lsp-code-action-kind "refactor.inline"))

        (defun my/lsp-restart ()
          "Restart the workspace for this buffer — the LspRestart reflex."
          (interactive)
          (if (bound-and-true-p lsp-mode) (lsp-workspace-restart (lsp--read-workspace))
            (message "lsp-mode is not active in this buffer")))
  '';
}
