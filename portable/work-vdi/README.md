# Full coding setup for a work VDI

These configurations keep the full work/coding features from this repository.
Only personal integrations and settings tied to the original machine are
removed. See [FEATURES.md](FEATURES.md) for the exact scope and validation limits.

## Automatically refreshed by rebuilds

Every successful Darwin or Home Manager activation builds a fresh export from
that generation's editor sources and locked nixpkgs. This includes `nix-build`,
`nix-update`, direct switches, and bootstrap installs. Generation errors stop the
build before activation, preserving the last working installer.

The current installer is always available at:

```text
~/.local/share/work-vdi/export/install.sh
```

This respects your configured XDG data directory. When `~/nix-config` exists,
activation also refreshes `~/nix-config/portable/work-vdi/`, so the file you copy
from this checkout stays current. These are generated copies; make changes in
the editor modules or exporter templates instead. The rebuild does not transfer
anything to Horizon or update the VDI: copy the refreshed installer and run it
there when needed.

`work-vdi-export` recopies the last built export into the checkout, or use
`work-vdi-export --output /some/folder`. To generate from current sources without
switching the system, run `nix build .#work-vdi` and copy `result/install.sh`.

## Easy installation

Copy **only `install.sh`** onto the VDI. It embeds all configuration files and
coding helper scripts; the other files are not needed to install.

In a Linux, macOS, or WSL terminal in the directory containing that file, run:

```sh
sh install.sh
```

This makes the work setup the default for normal Neovim and Emacs launches,
including their app icons, installs plugins and builds syntax grammars when the
required compilers are present. Existing Neovim/Emacs configurations are moved
to the timestamped backup folder before activation. Vim remains an optional
`work-vim` fallback. No sudo is required; close and reopen the editors afterward.

For the language servers and formatters for your work stack:

```sh
sh install.sh --tools
```

`--tools` requires Node.js/npm and Python 3.9+ with venv support. It installs
language tools in a private user-owned prefix, including JDTLS with Lombok,
LemMinX, Intelephense, Black and Ruff. Java requires a preinstalled JDK 21+.
PHP projects require PHP; with Composer available, the installer also installs
PHP-CS-Fixer. Project-local Pint/PHP-CS-Fixer takes priority. No sudo is needed.

The default build includes 35 Neovim grammars covering the stack below and
additional coding languages. To build the entire Neovim parser catalog, use
`sh install.sh --tools --all-grammars` (more downloads and build time).

| Languages / frameworks | Coding and formatting support |
| --- | --- |
| Java / Spring Boot | JDTLS completion, diagnostics, navigation, Maven/Gradle imports and Java formatting; Lombok support |
| PHP / Laravel | Intelephense; project Pint or PHP-CS-Fixer, with LSP formatting fallback; Blade syntax and blade-formatter |
| Python / FastAPI | Pyright, Ruff diagnostics/actions, Black formatting |
| JS / TS | TypeScript language server, project-aware types, Prettier/prettierd |
| Vue / Nuxt | Vue language server and TypeScript Vue plugin; Vue syntax and Prettier |
| HTML / CSS / SCSS | HTML/CSS servers, Emmet, syntax highlighting and Prettier |
| YAML / JSON | Language servers, schema support and Prettier fallback |
| XML | LemMinX completion/validation and Prettier XML plugin, with LSP formatting fallback |

Framework support uses each project's dependencies and configuration. Install
its Maven/Gradle, Composer, npm or Python dependencies as usual. Nuxt generated
types need the project's normal preparation step; Laravel dynamic types depend
on project-provided metadata. Framework runtimes and debug adapters are separate.

The default keyboard layout matches the repository: **Colemak** movement
(`h n e i`). For colleagues using ordinary QWERTY (`h j k l`), copy **only
`install-qwerty.sh`** and run:

```sh
sh install-qwerty.sh --tools
```

This standalone flavor defaults to QWERTY in Neovim, Emacs and the Vim fallback,
including reinstalls. It has the same coding features and is regenerated alongside
`install.sh` on every rebuild. Both installers use the same work-profile paths;
choose one layout per user. The original installer also accepts `--qwerty`.

For no downloads, use `sh install.sh --offline`. This copies the full configs,
but the full feature set needs its packages staged separately. Rerun without
`--offline` later. Repeat `--qwerty` on reinstall if you use it. `--offline`
and `--tools` cannot be combined.

## Install the editor applications without sudo

On Linux/WSL, including the Ubuntu Horizon VDI, use:

```sh
sh install.sh --editors --tools
# For colleagues:
sh install-qwerty.sh --editors --tools
```

`--editors` installs Neovim 0.12.6 and Emacs 30.2 into your XDG data directory
and exposes ordinary `~/.local/bin/nvim` and `~/.local/bin/emacs` commands.
It adds that command directory to Bash/Zsh startup files and creates user app-menu
entries for both editors. Open a new terminal after installation, then run
`nvim`, `emacs` or `emacs -nw` normally. Existing running Emacs daemons need a restart.
The installer itself immediately uses the new commands to install plugins.

The Neovim archive is from [the official release](https://github.com/neovim/neovim/releases/tag/v0.12.6).
Emacs uses the **community-built, archived**
[Emacs 30.2 AppImage release](https://github.com/blahgeek/emacs-appimage/releases/tag/github-action-build-17008212441),
not an official GNU binary. Both downloads are pinned and SHA-256 checked. Emacs
is extracted once, so no FUSE setup or privileged mount is needed. Linux x86_64
and aarch64 are supported; macOS uses its normal editor installation method.

The installed executables are checked before exposing their commands: Neovim
must be 0.12+; Emacs must be 29+ with tree-sitter and dynamic modules. A VDI with
incompatible system libraries or home-directory execution restrictions will
report the startup error. This flow was checked with archive fixtures on the
maintainer's Mac; the actual Linux binaries still need their first run on the VDI.
Existing user command files and shell startup files are backed up before changes;
apt packages are left installed. Repeating the option reuses downloaded editors.
This does not register the applications with apt or require administrator rights.

## Requirements

- **Neovim 0.12+** and **Emacs 29+** with tree-sitter and dynamic-module
  support, or Vim 8+ for the limited fallback. Use `--editors` on Linux to install
  compatible applications without sudo. Emacs configuration was validated on 31.
- Git, network access to GitHub/GNU ELPA/NonGNU ELPA/MELPA, and space for packages.
- C/C++ compiler, make and CMake for native plugins/grammars. Emacs vterm may
  require libtool/libvterm development packages depending on the platform.
  Neovim grammar builds also need the tree-sitter CLI.
- `rg` for project searches; `fd` improves file discovery; SQLite libraries for
  Telescope history; a Nerd Font for the source icons.
- Node/npm and the project's own dependencies for the JavaScript tools and tests.

The installer does not install system libraries or OS packages. The optional
`--editors` download is for Linux/WSL. Native
Windows without WSL needs a different installer. Nothing is deployed as a
background login service.

## Open your editors

```sh
nvim
emacs
emacs -nw
~/.local/bin/work-vim
```

Normal app icons also use the setup. `-nw` opens Emacs inside a terminal.
Private coding tools are added by the configurations themselves, including GUI
launches. The `work-nvim` and `work-emacs` launchers remain optional aliases.
Existing running Emacs sessions/daemons must be restarted to load the new config.

Neovim: `:checkhealth` and `:Lazy` show dependency/plugin problems.
Emacs: `M-x work/doctor` shows module startup errors or missing packages.

## External language and project tools

The configs retain tool integrations; Nix no longer supplies the executables.
`--tools` installs the tools in the table above, plus Angular, Tailwind,
Prisma, Emmet and Bash servers, the tree-sitter CLI and yamllint. A compatible
TypeScript 5.9.3 is supplied as the shared tsserver fallback.

Install other tools relevant to your projects through the VDI's software tools:

| Feature | External dependencies |
| --- | --- |
| Go / SQL language servers | `gopls`, `sqls` |
| Haskell | GHC and `haskell-language-server-wrapper` |
| Lua / Nix / HTMX servers | `lua-language-server`, `nixd`, `htmx-lsp` |
| Other formatters/linters | `stylua`, `nixfmt`, `statix`, `yamlfmt`, `hclfmt`, `pg_format` |
| Sonar | `sonarlint-ls`, `sonar-scanner`, Java as required by those tools |
| Tests | Project-local Jest/Vitest/Playwright and their dependencies |
| Debugging | Relevant debug adapter, Node/Python/etc. runtime, project launch settings |
| Containers/infrastructure | Docker, `devcontainer`, `kubectl`, Terraform, direnv as needed |
| SQL / Markdown / Git diffs | `psql`, `pandoc`, `difft`, `delta` |
| AI coding | `claude` CLI and separately configured work credentials/API keys |

Emacs grammar installation can be rerun with `M-x work/install-grammars` after
installing compilers. Neovim uses `:TSInstall all` for the complete grammar catalog
or `:TSInstall <language>` for individual languages. Native library support in the
editor itself cannot be added just by copying an init file.

No account credentials, existing transcripts, vault data, or personal state are
copied. Forge/GitLab, GPTel and Claude retain their integrations and use whatever
work credentials you configure on the VDI. Browser editing/tab control requires
its matching browser extension; Firenvim additionally needs native-host setup.

## Locations and backups

| Item | Location |
| --- | --- |
| Neovim work config | `${XDG_CONFIG_HOME:-~/.config}/work-nvim/init.lua` |
| Emacs work config/helpers | `${XDG_CONFIG_HOME:-~/.config}/work-emacs/` |
| Vim fallback | `${XDG_DATA_HOME:-~/.local/share}/work-vdi/vimrc` |
| Private optional tools | `${XDG_DATA_HOME:-~/.local/share}/work-vdi/tools/` |
| Prior work-file backups | `${XDG_DATA_HOME:-~/.local/share}/work-vdi/backups/<timestamp>/` |

The standalone `init.el` also contains the module setup; the installer includes
its companion fonts/banner/helpers. For copy/paste installation, always use the
single `install.sh` so those companion files are included.
