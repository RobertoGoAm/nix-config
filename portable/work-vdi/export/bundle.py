#!/usr/bin/env python3
"""Bundle the complete work profiles into one transferable shell installer."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
STACK=json.loads((ROOT/'export/language-stack.json').read_text())
header=r'''#!/bin/sh
# Standalone full work-editor installer: Linux, macOS, or WSL. No Nix required.
set -eu
plugins=1
tools=0
editors=0
layout=colemak
all_grammars=0
for arg in "$@"; do
  case "$arg" in
    --offline) plugins=0 ;;
    --tools) tools=1 ;;
    --editors) editors=1 ;;
    --qwerty) layout=qwerty ;;
    --all-grammars) all_grammars=1 ;;
    --help|-h)
      printf '%s\n' 'Usage: sh install.sh [--offline] [--tools] [--editors] [--qwerty] [--all-grammars]' \
        'Installs full work profiles as your default editor profiles, backing up existing configurations.' \
        'Default: download editor plugins and build coding syntax grammars.' \
        '--editors: install Linux Neovim 0.12.6 and Emacs 30.2 in your home; no sudo.' \
        '--offline: only install config files; no downloads.' \
        '--tools: also install Node language servers/formatters and Python linters in a private user directory.' \
        '--qwerty: standard hjkl keys instead of Colemak.' \
        '--all-grammars: build the entire Neovim parser catalog instead of the work stack.' \
        'Requires Git and a native build toolchain; preinstall editors or use --editors on Linux.'
      exit 0 ;;
    *) printf 'Unknown option: %s\n' "$arg" >&2; exit 2 ;;
  esac
done
if [ "$plugins" -eq 0 ] && { [ "$tools" -eq 1 ] || [ "$editors" -eq 1 ]; }; then
  printf '%s\n' '--offline cannot be combined with --tools or --editors.' >&2
  exit 2
fi
case "$(uname -s)" in
  Linux|Darwin) ;;
  *) printf '%s\n' 'Run this installer in Linux, macOS, or WSL.' >&2; exit 1 ;;
esac
config_root=${XDG_CONFIG_HOME:-"$HOME/.config"}
data_root=${XDG_DATA_HOME:-"$HOME/.local/share"}
bin_root="$HOME/.local/bin"
tools_root="$data_root/work-vdi/tools"
backup_root="$data_root/work-vdi/backups/$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$config_root/work-nvim" "$config_root/work-emacs/helpers" "$data_root/work-vdi" "$bin_root"
backup() {
  if [ -e "$1" ] || [ -L "$1" ]; then
    mkdir -p "$backup_root"
    cp -p "$1" "$backup_root/$2"
    unlink "$1"
  fi
}
'''
files=[('vimrc','$data_root/work-vdi/vimrc','vimrc'),
       ('init.lua','$config_root/work-nvim/init.lua','init.lua'),
       ('init.el','$config_root/work-emacs/init.el','init.el'),
       ('early-init.el','$config_root/work-emacs/early-init.el','early-init.el'),
       ('banner.txt','$config_root/work-emacs/banner.txt','banner.txt'),
       ('export/language-stack.json','$config_root/work-emacs/language-stack.json','language-stack.json')]
for p in sorted((ROOT/'helpers').iterdir()):files.append((str(p.relative_to(ROOT)),'$config_root/work-emacs/helpers/'+p.name,p.name))
parts=[header]
for source,dest,backupname in files:
    parts.append(f'backup "{dest}" "{backupname}"\n')
    parts.append(f'cat > "{dest}" <<\'WORK_VDI_FILE_END\'\n')
    text=(ROOT/source).read_text()
    assert 'WORK_VDI_FILE_END' not in text
    parts.append(text if text.endswith('\n') else text+'\n')
    parts.append('WORK_VDI_FILE_END\n')
parts.append(r'''
chmod 755 "$config_root/work-emacs/helpers/claude-session-index" \
  "$config_root/work-emacs/helpers/claude-transcript" \
  "$config_root/work-emacs/helpers/claude-usage-today"
if [ "$layout" = qwerty ]; then
  for spec in vim lua el; do
    case "$spec" in
      vim) target="$data_root/work-vdi/vimrc"; old="get(g:, 'work_colemak', 1)"; new="get(g:, 'work_colemak', 0)" ;;
      lua) target="$config_root/work-nvim/init.lua"; old='local colemak = true'; new='local colemak = false' ;;
      el) target="$config_root/work-emacs/init.el"; old='defvar work/colemak t '; new='defvar work/colemak nil ' ;;
    esac
    sed "s|$old|$new|" "$target" > "$target.tmp"
    mv "$target.tmp" "$target"
  done
fi
# Use the standard editor discovery paths, retaining whole prior profiles.
activate_default() {
  target="$1"; source="$2"; label="$3"
  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then return; fi
  if [ -e "$target" ] || [ -L "$target" ]; then
    mkdir -p "$backup_root/defaults"
    mv "$target" "$backup_root/defaults/$label"
  fi
  mkdir -p "$(dirname "$target")"
  ln -s "$source" "$target"
}
activate_default "$config_root/nvim" "$config_root/work-nvim" nvim
# Emacs checks legacy init files before its standard configuration directory.
for legacy in .emacs .emacs.el .emacs.elc; do
  if [ -e "$HOME/$legacy" ] || [ -L "$HOME/$legacy" ]; then
    mkdir -p "$backup_root/defaults"
    mv "$HOME/$legacy" "$backup_root/defaults/$legacy"
  fi
done
activate_default "$HOME/.emacs.d" "$config_root/work-emacs" emacs.d
for name in work-vim work-nvim work-emacs work-format; do backup "$bin_root/$name" "$name"; done
cat > "$bin_root/work-vim" <<'WORK_VDI_LAUNCHER_END'
#!/bin/sh
exec vim -u "${XDG_DATA_HOME:-$HOME/.local/share}/work-vdi/vimrc" "$@"
WORK_VDI_LAUNCHER_END
cat > "$bin_root/work-nvim" <<'WORK_VDI_LAUNCHER_END'
#!/bin/sh
export NVIM_APPNAME=work-nvim
work_tools="${XDG_DATA_HOME:-$HOME/.local/share}/work-vdi/tools"
export PATH="$work_tools/bin:$work_tools/python/bin:$HOME/.local/bin:$PATH"
if [ -d "$work_tools/lib/node_modules" ]; then export npm_config_prefix="$work_tools"; fi
exec nvim "$@"
WORK_VDI_LAUNCHER_END
cat > "$bin_root/work-emacs" <<'WORK_VDI_LAUNCHER_END'
#!/bin/sh
work_tools="${XDG_DATA_HOME:-$HOME/.local/share}/work-vdi/tools"
export PATH="$work_tools/bin:$work_tools/python/bin:$HOME/.local/bin:$PATH"
if [ -d "$work_tools/lib/node_modules" ]; then export npm_config_prefix="$work_tools"; fi
exec emacs --init-directory="${XDG_CONFIG_HOME:-$HOME/.config}/work-emacs" "$@"
WORK_VDI_LAUNCHER_END
cat > "$bin_root/work-format" <<'WORK_VDI_LAUNCHER_END'
#!/bin/sh
exec python3 "${XDG_CONFIG_HOME:-$HOME/.config}/work-emacs/helpers/work-format" "$@"
WORK_VDI_LAUNCHER_END
chmod 755 "$bin_root/work-format"
chmod 755 "$bin_root/work-vim" "$bin_root/work-nvim" "$bin_root/work-emacs"
printf '%s\n' 'Work configurations are now the default for Neovim and Emacs.'
if [ -d "$backup_root" ]; then printf 'Previous configurations backed up to: %s\n' "$backup_root"; fi
if [ "$editors" -eq 1 ]; then
  if ! command -v python3 >/dev/null 2>&1; then
    printf '%s\n' '--editors requires Python 3.9+.' >&2
    exit 1
  fi
  python3 "$config_root/work-emacs/helpers/install-editors.py"
  export PATH="$HOME/.local/bin:$PATH"
fi
if [ "$tools" -eq 1 ]; then
  if ! command -v npm >/dev/null 2>&1; then
    printf '%s\n' '--tools requires Node.js and npm. Install those, then rerun.' >&2
    exit 1
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    printf '%s\n' '--tools requires Python 3.9+ for the shared Java/XML installer.' >&2
    exit 1
  fi
  npm install --global --prefix "$tools_root" STACK_NPM
  python3 -m venv "$tools_root/python"
  "$tools_root/python/bin/python" -m pip install STACK_PIP
  python3 "$config_root/work-emacs/helpers/install-native-tools.py" "$tools_root" "$config_root/work-emacs/language-stack.json"
  if command -v php >/dev/null 2>&1 && command -v composer >/dev/null 2>&1; then
    mkdir -p "$tools_root/php-formatter" "$tools_root/bin"
    COMPOSER_HOME="$tools_root/composer-home" composer --working-dir="$tools_root/php-formatter" require friendsofphp/php-cs-fixer --no-interaction --no-progress
    cat > "$tools_root/bin/php-cs-fixer" <<'WORK_VDI_PHP_END'
#!/bin/sh
exec php "${XDG_DATA_HOME:-$HOME/.local/share}/work-vdi/tools/php-formatter/vendor/bin/php-cs-fixer" "$@"
WORK_VDI_PHP_END
    chmod 755 "$tools_root/bin/php-cs-fixer"
  else
    printf '%s\n' 'PHP-CS-Fixer installation needs PHP and Composer. PHP server formatting remains available; project Pint is used when installed.' >&2
  fi

fi
export PATH="$tools_root/bin:$tools_root/python/bin:$HOME/.local/bin:$PATH"
if [ -d "$tools_root/lib/node_modules" ]; then export npm_config_prefix="$tools_root"; fi
if [ "$plugins" -eq 1 ]; then
  if ! command -v git >/dev/null 2>&1; then
    printf '%s\n' 'Plugin installation requires Git. Configs are installed; install Git and rerun.' >&2
    exit 1
  fi
  if command -v nvim >/dev/null 2>&1; then
    if ! nvim --headless -u NONE -i NONE '+lua if vim.fn.has("nvim-0.12") == 0 then vim.cmd("cquit 1") end' +qa; then
      printf '%s\n' 'Full Neovim plugins require Neovim 0.12+. Upgrade Neovim and rerun.' >&2
      exit 1
    fi
    lazy_dir="$data_root/work-nvim/lazy/lazy.nvim"
    if [ ! -d "$lazy_dir" ]; then
      mkdir -p "$(dirname "$lazy_dir")"
      git clone --filter=blob:none --branch=stable https://github.com/folke/lazy.nvim.git "$lazy_dir"
    fi
    # Old textobjects uses a removed tree-sitter API even before Lazy can sync.
    legacy_textobjects="$data_root/work-nvim/lazy/nvim-treesitter-textobjects"
    if [ -f "$legacy_textobjects/plugin/nvim-treesitter-textobjects.vim" ]; then
      mkdir -p "$backup_root/plugins"
      mv "$legacy_textobjects" "$backup_root/plugins/nvim-treesitter-textobjects"
    fi
    WORK_VDI_BOOTSTRAP=1 NVIM_APPNAME=work-nvim nvim --headless -i NONE '+Lazy! sync' +qa
    if { command -v cc >/dev/null 2>&1 || command -v gcc >/dev/null 2>&1 || command -v clang >/dev/null 2>&1; } && command -v tree-sitter >/dev/null 2>&1; then
      WORK_VDI_BOOTSTRAP=1 WORK_VDI_ALL_GRAMMARS="$all_grammars" NVIM_APPNAME=work-nvim nvim --headless -i NONE \
        '+lua require("nvim-treesitter").install(vim.env.WORK_VDI_ALL_GRAMMARS=="1" and require("nvim-treesitter").get_available() or STACK_GRAMMARS):wait(600000)' +qa
    else
      printf '%s\n' 'Neovim grammar builds need a C compiler and tree-sitter CLI. Once installed, run :TSInstall all.' >&2
    fi
  else
    printf '%s\n' 'Neovim is not installed; its configuration is ready for later.'
  fi
  if command -v emacs >/dev/null 2>&1; then
    WORK_VDI_BOOTSTRAP=1 WORK_VDI_EMACS_DIR="$config_root/work-emacs/" emacs --batch -Q \
      --eval '(when (< emacs-major-version 29) (error "Emacs 29+ is required"))' \
      --eval '(setq user-emacs-directory (getenv "WORK_VDI_EMACS_DIR") package-user-dir (expand-file-name "elpa" user-emacs-directory))' \
      -l "$config_root/work-emacs/init.el" -f work/install-packages
    if command -v cc >/dev/null 2>&1 && command -v c++ >/dev/null 2>&1; then
      WORK_VDI_BOOTSTRAP=1 WORK_VDI_EMACS_DIR="$config_root/work-emacs/" emacs --batch -Q \
        --eval '(setq user-emacs-directory (getenv "WORK_VDI_EMACS_DIR") package-user-dir (expand-file-name "elpa" user-emacs-directory))' \
        -l "$config_root/work-emacs/init.el" \
        -l "$config_root/work-emacs/helpers/../portability-placeholder.el" \
        -f work/install-grammars
    else
      printf '%s\n' 'Emacs grammar builds need C/C++ compilers. Once installed, run M-x work/install-grammars.' >&2
    fi
  else
    printf '%s\n' 'Emacs is not installed; its configuration is ready for later.'
  fi
fi
printf '\n%s\n' 'Open normally with nvim or emacs. Optional work launchers:' \
  "$bin_root/work-nvim" "$bin_root/work-emacs -nw" "$bin_root/work-vim"
printf '\n%s\n' 'Use :checkhealth in Neovim or M-x work/doctor in Emacs to inspect setup.' \
  'Project tools, remaining language servers, debug adapters and fonts must be installed separately.'
''')
# Supply grammar setup during the bootstrap pass without loading normal modules.
parts[-1]=parts[-1].replace('        -l "$config_root/work-emacs/helpers/../portability-placeholder.el" \\\n', '        -l "$config_root/work-emacs/portability.el" \\\n')
# This small support file is also embedded in init.el; installed separately for bootstrap.
source=ROOT/'export/emacs-portability.el'
support='backup "$config_root/work-emacs/portability.el" portability.el\ncat > "$config_root/work-emacs/portability.el" <<\'WORK_VDI_FILE_END\'\n'+source.read_text()+'\nWORK_VDI_FILE_END\n'
parts.insert(-1,support)
payload=''.join(parts).replace('STACK_NPM',' '.join(STACK['npm'])).replace('STACK_PIP',' '.join(STACK['pip'])).replace('STACK_GRAMMARS',json.dumps(STACK['grammars']).replace('[','{').replace(']','}'))
for filename, layout in [('install.sh', 'colemak'), ('install-qwerty.sh', 'qwerty')]:
    variant = payload.replace('layout=colemak\n', f'layout={layout}\n', 1)
    variant = variant.replace('Usage: sh install.sh ', f'Usage: sh {filename} ', 1)
    (ROOT/filename).write_text(variant)
    (ROOT/filename).chmod(0o755)
print('Bundled standalone Colemak and QWERTY installers')
