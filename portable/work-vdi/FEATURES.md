# Full work export: scope and portability changes

This replaces the earlier reduced configurations. `init.lua` exports all 57
non-personal Neovim plugins; `init.el` exports 38 Emacs source modules. The
installer embeds both, Emacs frame setup/banner, and the coding/tool-installation helper scripts.
The independent `vimrc` remains a basic fallback: Vim cannot run Neovim plugins.

## Retained

- Editing: Colemak/QWERTY choice, source leader shortcuts, multicursors, surround,
  comments, pairs, Emmet, refactoring, TODO navigation, persistent undo/sessions.
- Completion: the full nvim-cmp source set, LuaSnip/friendly-snippets; Emacs
  Corfu/Cape/Yasnippet, Vertico/Orderless/Marginalia/Consult/Embark.
- Code: tree-sitter, syntax text objects, jump helpers, folding, outlines,
  symbol highlighting, tag renaming, file trees, project search/replacement.
- LSP: the source language-server configuration, diagnostics, code actions,
  hover/signatures, inlay hints, ESLint/Tailwind/Vue support where configured.
  Emacs keeps lsp-mode/lsp-ui/Flycheck, not the earlier Eglot replacement.
- Formatting: source formatter choices and format-on-save. Neovim uses Conform
  for the save hook so the other formatting integrations do not format twice.
  Emacs keeps Apheleia. Neovim's yaml formatter list excludes yamllint because
  it is a diagnostic tool; its lint integration remains.
- Tests: Neotest with Jest/Vitest/Playwright; Emacs Jest commands and source
  Emacs 31 compatibility patch. Debugging keeps DAP/UI/virtual text and Dape.
- Git: Fugitive/Gitsigns; Magit/Forge/GitLab workflows, blame, structural and
  side-by-side diffs, file history, links and time machine.
- Tools: terminal panes, Docker/devcontainers/TRAMP, Kubernetes/Terraform,
  direnv, SQL/Prisma, HTTP scratchpads, Markdown rendering/export.
- AI coding: Claude IDE fork at the source revision, session manager/resume,
  transcript helpers, GPTel, coding status. Credentials remain external.
- Browser editing/tab tools: Firenvim/Atomic Chrome/browser-gt. Extensions and
  native-host registration are external setup, as are browser and OS capabilities.
- UI: theme, custom modelines, dashboard, icons, indent/column guides, dimming,
  notifications, focus/zen features, reports, and navigation aids.

## Removed because personal or specific to the original machine

- Telega/Telegram, Matrix/social clients, mail and their startup services.
- Obsidian vault integration, personal Org agenda/capture setup, note templates,
  vault dashboard tasks and all their shortcuts.
- Spotify/Smudge/music, finance/Hledger, book library and reading-position sync.
- Management of the personal Nix checkout, its literate export hooks and daemon
  deployment/rebuild commands; private-init loading, fixed home paths, macOS
  app-bundle paths, launchd/systemd service definitions and shell remappers.
- Personal mail/chat/music badges and polling. The coding/Claude status remains.

## Necessary portability changes

- Nix store paths become executable names or runtime npm package discovery.
  No Nix is needed on the VDI. External tools still have to exist there.
- The Neovim setup uses the current plugin APIs; source revisions are retained
  where the Nix package metadata supplies them. The generated lazy lock file
  records the final resolved dependency set. Neovim 0.12+ is required.
- Tree-sitter grammars are built on the VDI instead of supplied by Nix. The
  installer builds the configured language set when compilers are available;
  additional Neovim languages remain available through `:TSInstall all`.
  Emacs uses classic modes until the corresponding grammars are installed.
- A missing Emacs package skips its module and appears in `M-x work/doctor`,
  rather than preventing all startup. Offline installs therefore need packages
  staged separately before the full feature set can activate.
- GUI fonts are used when installed. Terminal icon rendering depends on the
  Horizon terminal/font. Without WebKit, internal browsing falls back to EWW.
- Fixed pre-existing Nixvim shortcut typos (`Git giff`, empty project replace,
  malformed current-file path), and supplied Git/Telescope command providers.
- Debug adapters and project-specific launch configurations remain external.
  For Neovim's added Node launch preset, set `WORK_JS_DEBUG_SERVER` to your
  `vscode-js-debug` server script. Emacs retains the source Dape setup.

## Language stack additions

The portable profiles add Java/JDTLS with Lombok, PHP/Intelephense, Blade,
XML/LemMinX, Ruff, SCSS and explicit TypeScript fallback discovery. Shared
project-aware formatters keep manual formatting and format-on-save consistent.
The default Neovim grammar set covers 35 languages; `--all-grammars` requests
the full catalog. Emacs includes grammar recipes and classic-mode fallbacks.
These additions are generated again on rebuild, just like the exported modules.

## User-installed applications

`--editors` installs pinned Linux Neovim 0.12.6 and community Emacs 30.2 builds,
checks SHA-256 digests, extracts Emacs without FUSE, checks startup/features and
adds normal commands and desktop entries. Bash/Zsh startup files get a PATH entry;
prior user commands and shell files are backed up. No apt package is modified.
Application downloading/extraction and command registration have fixture tests;
Linux execution is not validated on the maintainer's Mac.

## Validation performed

- Real PHP, TypeScript, XML and Java language servers initialized and returned
  formatting edits; Pyright initialized successfully. Java was checked on JDK 21.
- Project formatter selection, unsaved-content isolation, failure cleanup and
  repeat native-tool installation pass isolated tests. PHP/Composer project
  formatters were tested with fixtures, not a full Laravel application.

- Full Emacs source modules load using the locally installed source packages.
- All exported Neovim plugin setup callbacks run against the locally installed
  source plugins, with the plugin-manager boundary replaced for this check.
- Syntax checks and isolated installer checks cover both layouts, repeated
  installation/backups, custom XDG locations, and default-profile activation with backups.
- The full package download/build flow has not been run on the VDI. Its OS,
  network policies, installed editor versions and build tools still determine
  which dependencies can be installed there.

## Regenerating from this repository

Normal rebuilds generate the bundle automatically in the Nix sandbox; activation
publishes it through the XDG data directory and refreshes the checkout copies.
`nix build .#work-vdi` builds only the bundle without switching the system.

For maintainer debugging, the equivalent manual export is:

```sh
python3 portable/work-vdi/export/generate.py
python3 portable/work-vdi/export/render.py
python3 portable/work-vdi/export/bundle.py
```

The evaluator reads the locked source modules without building the personal
system. `export/evaluated.json` and `export/modules/`
are intermediate inspection artifacts, excluded from version control. The
renderer applies the personal-feature exclusions and portability changes.
