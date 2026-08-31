# development emacs plugins code languages

{
  ...
}:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      add-node-modules-path
      editorconfig
      emmet-mode
      graphql-mode
      haskell-mode
      nix-ts-mode
      typescript-mode
      web-mode
    ];

  programs.emacs.extraConfig = ''
    ;;; Languages — the modes behind the JS/TS/Vue/React/Angular/Node stack, plus
    ;;; nix, haskell and go.

    ;; Emacs 30 ships tree-sitter major modes for most of this stack, so the
    ;; remapping below routes the classic modes to their -ts- counterparts and only
    ;; the ones with no built-in (vue, nix, graphql, haskell) come from packages.
    (dolist (pair '((js-mode          . js-ts-mode)
                    (javascript-mode  . js-ts-mode)
                    (js-json-mode     . json-ts-mode)
                    (json-mode        . json-ts-mode)
                    (typescript-mode  . typescript-ts-mode)
                    (css-mode         . css-ts-mode)
                    (yaml-mode        . yaml-ts-mode)
                    (sh-mode          . bash-ts-mode)
                    (python-mode      . python-ts-mode)
                    (go-mode          . go-ts-mode)
                    (lua-mode         . lua-ts-mode)
                    (conf-toml-mode   . toml-ts-mode)))
      (add-to-list 'major-mode-remap-alist pair))

    ;; .vue goes to web-mode, which is what volar's lsp-mode client expects to find;
    ;; Vuetify components then complete through volar like any other dependency.
    ;; Angular templates are plain .html, so they are already covered — the Angular
    ;; server attaches from the html side and ts-ls from the component side.
    (dolist (entry '(("\\.tsx\\'"        . tsx-ts-mode)
                     ("\\.jsx\\'"        . tsx-ts-mode)
                     ("\\.mts\\'"        . typescript-ts-mode)
                     ("\\.cts\\'"        . typescript-ts-mode)
                     ("\\.mjs\\'"        . js-ts-mode)
                     ("\\.cjs\\'"        . js-ts-mode)
                     ("\\.vue\\'"        . web-mode)
                     ("\\.svelte\\'"     . web-mode)
                     ("\\.astro\\'"      . web-mode)
                     ("\\.html?\\'"      . web-mode)
                     ("\\.s[ac]ss\\'"    . scss-mode)
                     ("\\.nix\\'"        . nix-ts-mode)
                     ("\\.graphqls?\\'"  . graphql-mode)
                     ("\\.gql\\'"        . graphql-mode)))
      (add-to-list 'auto-mode-alist entry))

    ;; web-mode drives .vue and .html: two-space offsets come from options.nix, and
    ;; these switch on the parts that matter for single-file components and JSX.
    (setq web-mode-enable-auto-closing t
          web-mode-enable-auto-pairing t
          web-mode-enable-auto-quoting nil
          web-mode-enable-css-colorization t
          web-mode-enable-current-element-highlight t
          ;; ts-autotag's job: editing an opening tag renames its closing tag.
          web-mode-enable-auto-indentation nil
          web-mode-script-padding 0
          web-mode-style-padding 0
          web-mode-block-padding 0)

    ;; HTML5 and CSS3 authoring: emmet expansion on the localleader, matching the
    ;; nvim emmet leader_key of ",". So ", ," expands the abbreviation at point.
    (require 'emmet-mode)
    (setq emmet-move-cursor-between-quotes t
          emmet-self-closing-tag-style ""
          emmet-expand-jsx-className? t)
    (dolist (hook '(web-mode-hook html-mode-hook mhtml-mode-hook css-ts-mode-hook
                    scss-mode-hook tsx-ts-mode-hook js-ts-mode-hook))
      (add-hook hook #'emmet-mode))

    ;; Node projects: put ./node_modules/.bin on exec-path for the buffer, so
    ;; prettier, eslint and the test runners resolve to the versions the project
    ;; pins rather than anything global.
    ;; npm removed `npm bin' in v9 and this package still defaults to it. The
    ;; command fails, and over tramp npm's error text ("Unknown command: bin /
    ;; To see a list of supported npm commands...") was taken for a directory and
    ;; spliced onto a /docker: path -- the source of the "Not a Tramp file name"
    ;; errors. `npm root' is the supported replacement.
    (require 'add-node-modules-path)
    (setq add-node-modules-path-command '("echo \"$(npm root)/.bin\""))
    (dolist (hook '(js-ts-mode-hook typescript-ts-mode-hook tsx-ts-mode-hook
                    web-mode-hook json-ts-mode-hook))
      (add-hook hook #'add-node-modules-path))

    ;; .editorconfig wins over the defaults in options.nix, per project.
    (require 'editorconfig)
    (editorconfig-mode 1)
    ;; Not over tramp. A container with no .editorconfig produced a warning for
    ;; every buffer opened under /docker:, and reading one would be a network
    ;; round trip per file for settings the host checkout already supplies.
    (with-eval-after-load 'editorconfig
      (add-to-list 'editorconfig-exclude-regexps "\\`/[^/|:]+[|:]"))

    ;; schemastore.nvim's replacement: lsp-mode pulls the same catalogue for JSON and
    ;; YAML, which is what makes package.json, tsconfig, GitHub Actions and
    ;; docker-compose validate and complete.
    (setq lsp-yaml-schema-store-enable t
          lsp-yaml-schema-store-uri "https://www.schemastore.org/api/json/catalog.json"
          lsp-json-schemas nil)

    (require 'haskell-mode)
  '';
}
