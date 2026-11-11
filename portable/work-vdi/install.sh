#!/bin/sh
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
backup "$data_root/work-vdi/vimrc" "vimrc"
cat > "$data_root/work-vdi/vimrc" <<'WORK_VDI_FILE_END'
" Work VDI: Vim 8+ or Neovim. No plugins or network access required.
" Set to 0 for a QWERTY keyboard; this changes editor keys, not OS layout.
let g:work_colemak = get(g:, 'work_colemak', 1)
let mapleader = ' '
let maplocalleader = ','
set nocompatible
filetype plugin indent on
syntax enable
set encoding=utf-8 hidden number relativenumber showcmd cursorline
set backspace=indent,eol,start
set incsearch hlsearch ignorecase smartcase wildmenu
set splitbelow splitright expandtab tabstop=2 softtabstop=2 shiftwidth=2
set nowrap confirm updatetime=300 timeoutlen=500 background=dark
if exists('+signcolumn') | set signcolumn=yes | endif
if exists('+termguicolors') | set termguicolors | endif
let s:state = expand('~/.vim/work-state')
for s:dir in ['undo', 'backup', 'swap']
  call mkdir(s:state . '/' . s:dir, 'p', 0700)
endfor
let &directory = s:state . '/swap//'
let &backupdir = s:state . '/backup//'
if has('persistent_undo')
  set undofile
  let &undodir = s:state . '/undo//'
endif
if has('clipboard') | set clipboard^=unnamedplus | endif
nnoremap x "_x
nnoremap X "_X
nnoremap <Del> "_x
nnoremap + <C-x>
nnoremap - <C-a>
if g:work_colemak
  for [s:from, s:to] in [['n','j'],['N','J'],['e','k'],['E','K'],['i','l'],['I','L'],['j','n'],['J','N'],['k','e'],['K','E'],['l','i'],['L','I']]
    execute 'noremap ' . s:from . ' ' . s:to
  endfor
endif
nnoremap <leader>ff :find<Space>
nnoremap <leader>fe :Explore<CR>
nnoremap <leader>bb :ls<CR>:buffer<Space>
nnoremap <leader>fs :write<CR>
nnoremap <leader>ss /
nnoremap <leader>sp :vimgrep /
nnoremap <leader>lq :copen<CR>
nnoremap <leader>ln :cnext<CR>
nnoremap <leader>le :cprevious<CR>
nnoremap <leader>ws :split<CR>
nnoremap <leader>wv :vsplit<CR>
nnoremap <leader>wo <C-w>o
nnoremap <leader>wd <C-w>c
nnoremap <leader>w= <C-w>=
nnoremap <leader>Ts :nohlsearch<CR>
nnoremap <leader>Tw :set wrap!<CR>
nnoremap <leader>xd :%s/\s\+$//e<CR>
nnoremap <leader>xf gg=G``
set path+=**
set wildignore+=*/.git/*,*/node_modules/*,*/.venv/*,*/dist/*,*/build/*
" Completion: C-x C-o (language omnifunc), C-x C-f (paths), C-n/C-p (words).
" Project search: :vimgrep /pattern/gj **/* then :copen.
WORK_VDI_FILE_END
backup "$config_root/work-nvim/init.lua" "init.lua"
cat > "$config_root/work-nvim/init.lua" <<'WORK_VDI_FILE_END'
-- Full work export of the Nixvim coding modules. No Nix required on the VDI.
local colemak = true
vim.env.NVIM_APPNAME = 'work-nvim'
local work_tools = (vim.env.XDG_DATA_HOME or (vim.env.HOME..'/.local/share'))..'/work-vdi/tools'
vim.env.PATH = work_tools..'/bin:'..work_tools..'/python/bin:'..vim.env.HOME..'/.local/bin:'..(vim.env.PATH or '')
if vim.fn.isdirectory(work_tools..'/lib/node_modules')==1 then vim.env.npm_config_prefix=work_tools end
vim.g.mapleader, vim.g.maplocalleader = ' ', ','
local function work_npm_package(name)
  if vim.fn.executable('npm')~=1 then return nil end
  local result=vim.fn.systemlist({'npm','root','-g'})
  if vim.v.shell_error~=0 or not result[1] then return nil end
  local path=result[1]..'/'..name
  return (vim.uv or vim.loop).fs_stat(path) and path or nil
end
vim.filetype.add({pattern={['.*%.blade%.php']='blade'},extension={vue='vue',xml='xml',xsd='xml',xsl='xml',xslt='xml',wsdl='xml',fxml='xml'}})
for k,v in pairs({["background"]="dark",["backspace"]="indent,eol,start",["cmdheight"]=1,["confirm"]=true,["cursorline"]=true,["encoding"]="utf-8",["expandtab"]=true,["fileencoding"]="utf-8",["foldcolumn"]="1",["foldenable"]=true,["foldlevel"]=99,["foldlevelstart"]=99,["hidden"]=true,["hlsearch"]=true,["ignorecase"]=true,["incsearch"]=true,["number"]=true,["pumheight"]=10,["relativenumber"]=true,["shiftwidth"]=2,["showcmd"]=true,["signcolumn"]="yes",["smartcase"]=true,["softtabstop"]=2,["splitbelow"]=true,["splitright"]=true,["tabstop"]=2,["timeoutlen"]=500,["updatetime"]=300,["wildmenu"]=true,["wrap"]=false}) do vim.opt[k]=v end
for _,dir in ipairs({".undo",".backup",".swp"}) do vim.fn.mkdir(vim.fn.stdpath("state").."/nvim/"..dir,"p",448) end
local api = vim.api
local cmd = vim.cmd
local env = vim.env
local fn = vim.fn
local o = vim.opt

-- Trim trailing whitespace on save
api.nvim_create_autocmd({ "BufWritePre" }, {
  pattern = { "*" },
  command = [[%s/\s\+$//e]],
})

-- Change cursor based on mode
cmd([[let &t_SI = '\<Esc>]50;CursorShape=1\x7']])
cmd([[let &t_SR = '\<Esc>]50;CursorShape=2\x7']])
cmd([[let &t_EI = '\<Esc>]50;CursorShape=0\x7']])


-- Undo, backup and swap
local prefix = vim.fn.stdpath("state")
o.undofile = true
o.undodir = { prefix .. "/nvim/.undo//" }
o.backupdir = { prefix .. "/nvim/.backup//" }
o.directory = { prefix .. "/nvim/.swp//" }

-- True colors
if fn.has("nvim") == 1 then
  cmd([[let $NVIM_TUI_ENABLE_TRUE_COLOR=1]])
end

if fn.has("termguicolors") == 1 then
  o.termguicolors = true
end

cmd([[let &t_ZH='\e[3m']])
cmd([[let &t_ZR='\e[23m']])


-- Clipboard configuration
if vim.fn.has("macunix") == 1 then
  o.clipboard:append { 'unnamedplus' }
end

if vim.fn.has("win32") == 1 then
  o.clipboard:prepend { 'unnamed', 'unnamedplus' }
end

local _border = "rounded"

vim.diagnostic.config{
  float = { border = _border },
}

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("lsp_border", { clear = true }),
  callback = function(args)
    local bufopts = { buffer = args.buf, silent = true }
    vim.keymap.set({ "n", "i" }, "<C-k>", function()
      vim.lsp.buf.signature_help({ border = _border })
    end, bufopts)
  end,
})

pcall(function()
  require("lspconfig.ui.windows").default_options.border = _border
end)

vim.api.nvim_create_autocmd("FileType",{["command"]="setlocal nonumber norelativenumber foldcolumn=0 wrap linebreak breakindent",["pattern"]={"markdown","text","gitcommit"}})
local lazypath=vim.fn.stdpath('data')..'/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  if colemak then for from,to in pairs({n='j',N='J',e='k',E='K',i='l',I='L',j='n',J='N',k='e',K='E',l='i',L='I'}) do vim.keymap.set('n',from,to) end end
  vim.keymap.set('n','<leader>fs','<cmd>write<cr>')
  vim.notify('Run the work installer to install coding plugins; core settings are active.',vim.log.levels.WARN)
  return
end
vim.opt.rtp:prepend(lazypath)
require('lazy').setup({
'nvim-lua/plenary.nvim',
{'folke/tokyonight.nvim',priority=1000,config=function() require('tokyonight').setup({["dim_inactive"]=true,["hide_inactive_statusline"]=true,["lualine_bold"]=false,["style"]="storm",["styles"]={["comments"]={["italic"]=true},["floats"]="dark",["keywords"]={["bold"]=true,["italic"]=true},["sidebars"]="dark"},["transparent"]=true,["on_highlights"]=function(hl, c)
    local prompt = "#2d3149"
    hl.TelescopeNormal = {
      bg = c.bg_dark,
      fg = c.fg_dark,
    }
    hl.TelescopeBorder = {
      bg = c.bg_dark,
      fg = c.bg_dark,
    }
    hl.TelescopePromptNormal = {
      bg = prompt,
    }
    hl.TelescopePromptBorder = {
      bg = prompt,
      fg = prompt,
    }
    hl.TelescopePromptTitle = {
      bg = prompt,
      fg = prompt,
    }
    hl.TelescopePreviewTitle = {
      bg = c.bg_dark,
      fg = c.bg_dark,
    }
    hl.TelescopeResultsTitle = {
      bg = c.bg_dark,
      fg = c.bg_dark,
    }
  end
}); vim.cmd.colorscheme('tokyonight') end},
{"stevearc/aerial.nvim",lazy=false,dependencies={"nvim-tree/nvim-web-devicons"},tag="v4.0.0",config=function()
require("aerial").setup({["close_on_select"]=true})
end},
{"rmagatti/auto-session",lazy=false,commit="02a5588f677970a9bc784115c62bef9e5855499b",config=function()
require("auto-session").setup({})
end},
{"hrsh7th/nvim-cmp",lazy=false,dependencies={"hrsh7th/cmp-nvim-lsp","hrsh7th/cmp-buffer","hrsh7th/cmp-path","hrsh7th/cmp-cmdline","hrsh7th/cmp-nvim-lsp-signature-help","hrsh7th/cmp-nvim-lsp-document-symbol","ray-x/cmp-treesitter","saadparwaiz1/cmp_luasnip","L3MON4D3/LuaSnip","rafamadriz/friendly-snippets","lukas-reineke/cmp-rg","tamago324/cmp-zsh","hrsh7th/cmp-calc"},dependencies={"hrsh7th/cmp-nvim-lsp","hrsh7th/cmp-buffer","hrsh7th/cmp-path","hrsh7th/cmp-cmdline","hrsh7th/cmp-nvim-lsp-signature-help","hrsh7th/cmp-nvim-lsp-document-symbol","ray-x/cmp-treesitter","saadparwaiz1/cmp_luasnip","L3MON4D3/LuaSnip","rafamadriz/friendly-snippets","lukas-reineke/cmp-rg","tamago324/cmp-zsh","hrsh7th/cmp-calc","onsails/lspkind.nvim"},config=function()
local cmp = require('cmp')
local ls = require('luasnip')
require('luasnip.loaders.from_vscode').lazy_load()
local opts = {["friendly-snippets"]={["enable"]=true},["luasnip"]={["enable"]=true},["mapping"]={["<C-Space>"]=cmp.mapping.complete(),["<C-f>"]=cmp.mapping.scroll_docs(-4),["<C-s>"]=cmp.mapping.scroll_docs(4),["<C-t>"]=cmp.mapping.close(),["<CR>"]=cmp.mapping.confirm({ select = false, behavior = cmp.ConfirmBehavior.Replace }),["<S-Tab>"]=cmp.mapping(cmp.mapping.select_prev_item({behavior = cmp.SelectBehavior.Select}), {'i', 's'}),["<Tab>"]=cmp.mapping(cmp.mapping.select_next_item({behavior = cmp.SelectBehavior.Select}), {'i', 's'})},["preselect"]=cmp.PreselectMode.None,["snippet"]={["expand"]=function(args) require('luasnip').lsp_expand(args.body) end},["sources"]={{["name"]="nvim_lsp",["option"]={["get_bufnrs"]=function()
  local buf_size_limit = 1024 * 1024 -- 1MB size limit
  local bufs = vim.api.nvim_list_bufs()
  local valid_bufs = {}
  for _, buf in ipairs(bufs) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_offset(buf, vim.api.nvim_buf_line_count(buf)) < buf_size_limit then
      table.insert(valid_bufs, buf)
    end
  end
  return valid_bufs
end
},["priority"]=1000},{["name"]="nvim_lsp_signature_help",["option"]={["get_bufnrs"]=function()
  local buf_size_limit = 1024 * 1024 -- 1MB size limit
  local bufs = vim.api.nvim_list_bufs()
  local valid_bufs = {}
  for _, buf in ipairs(bufs) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_offset(buf, vim.api.nvim_buf_line_count(buf)) < buf_size_limit then
      table.insert(valid_bufs, buf)
    end
  end
  return valid_bufs
end
},["priority"]=1000},{["name"]="nvim_lsp_document_symbol",["option"]={["get_bufnrs"]=function()
  local buf_size_limit = 1024 * 1024 -- 1MB size limit
  local bufs = vim.api.nvim_list_bufs()
  local valid_bufs = {}
  for _, buf in ipairs(bufs) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_offset(buf, vim.api.nvim_buf_line_count(buf)) < buf_size_limit then
      table.insert(valid_bufs, buf)
    end
  end
  return valid_bufs
end
},["priority"]=1000},{["name"]="treesitter",["option"]={["get_bufnrs"]=function()
  local buf_size_limit = 1024 * 1024 -- 1MB size limit
  local bufs = vim.api.nvim_list_bufs()
  local valid_bufs = {}
  for _, buf in ipairs(bufs) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_offset(buf, vim.api.nvim_buf_line_count(buf)) < buf_size_limit then
      table.insert(valid_bufs, buf)
    end
  end
  return valid_bufs
end
},["priority"]=850},{["name"]="luasnip",["priority"]=750},{["name"]="buffer",["option"]={["get_bufnrs"]=function()
  local buf_size_limit = 1024 * 1024 -- 1MB size limit
  local bufs = vim.api.nvim_list_bufs()
  local valid_bufs = {}
  for _, buf in ipairs(bufs) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_offset(buf, vim.api.nvim_buf_line_count(buf)) < buf_size_limit then
      table.insert(valid_bufs, buf)
    end
  end
  return valid_bufs
end
},["priority"]=500},{["name"]="rg",["priority"]=300},{["name"]="path",["priority"]=300},{["name"]="cmdline",["priority"]=300},{["name"]="spell",["priority"]=300},{["name"]="git",["priority"]=250},{["name"]="zsh",["priority"]=250},{["name"]="calc",["priority"]=150},{["name"]="emoji",["priority"]=100}}}
opts['friendly-snippets'], opts.luasnip = nil, nil
opts.formatting = {format=require('lspkind').cmp_format({maxwidth=50,ellipsis_char='...'})}
cmp.setup(opts)
cmp.setup.cmdline({'/','?'}, {mapping=cmp.mapping.preset.cmdline(), sources={{name='buffer'}}})
cmp.setup.cmdline(':', {mapping=cmp.mapping.preset.cmdline(), sources=cmp.config.sources({{name='path'}},{{name='cmdline'}})})
end},
{"hrsh7th/cmp-emoji",lazy=false,commit="e8398e2adf512a03bb4e1728ca017ffeac670a9f"},
{"petertriho/cmp-git",lazy=false,commit="fe2c6e5c2df760c7ba1b3e2332c090c7f6ba8ee7",config=function()
require("cmp_git").setup({})
end},
{"f3fora/cmp-spell",lazy=false,commit="694a4e50809d6d645c1ea29015dad0c293f019d6"},
{"NvChad/nvim-colorizer.lua",lazy=false,config=function()
require("colorizer").setup({})
end},
{"numToStr/Comment.nvim",lazy=false,config=function()
require("Comment").setup({})
end},
{"stevearc/conform.nvim",lazy=false,commit="016802de402556da54c36bd7359b441266b01cdd",config=function()
local formatters={}
for _,kind in ipairs({'php','xml','blade'}) do
  local format_kind=kind
  formatters['work_'..kind]={command='work-format',args={kind,'$FILENAME'},stdin=true,
    condition=function(_,ctx)
      if vim.fn.executable('work-format')~=1 then return false end
      vim.fn.system({'work-format','--available',format_kind,ctx.filename})
      return vim.v.shell_error==0
    end}
end
require('conform').setup({formatters_by_ft={["css"]={"prettierd","prettier",["stop_after_first"]=true},["html"]={"prettierd","prettier",["stop_after_first"]=true},["javascript"]={"prettierd","prettier",["stop_after_first"]=true},["javascriptreact"]={"prettierd","prettier",["stop_after_first"]=true},["lua"]={"stylua"},["markdown"]={"prettierd","prettier",["stop_after_first"]=true},["nix"]={"nixfmt"},["python"]={"black"},["typescript"]={"prettierd","prettier",["stop_after_first"]=true},["typescriptreact"]={"prettierd","prettier",["stop_after_first"]=true},["vue"]={"prettierd","prettier",["stop_after_first"]=true},["yaml"]={"yamlfmt","prettierd","prettier",["stop_after_first"]=true},["scss"]={"prettierd","prettier",["stop_after_first"]=true},["json"]={"prettierd","prettier",["stop_after_first"]=true},["jsonc"]={"prettierd","prettier",["stop_after_first"]=true},["php"]={"work_php"},["blade"]={"work_blade"},["xml"]={"work_xml"}},formatters=formatters,
format_on_save={timeout_ms=3000,lsp_format='fallback'},notify_on_error=true})
end},
{"mfussenegger/nvim-dap",lazy=false,config=function()
local dap=require('dap')
if vim.fn.executable('node')==1 and vim.env.WORK_JS_DEBUG_SERVER then
  dap.adapters['pwa-node']={type='server',host='127.0.0.1',port='${port}',executable={command='node',args={vim.env.WORK_JS_DEBUG_SERVER,'${port}'}}}
  for _,ft in ipairs({'javascript','typescript','javascriptreact','typescriptreact'}) do
    dap.configurations[ft]={{type='pwa-node',request='launch',name='Launch file',program='${file}',cwd='${workspaceFolder}',sourceMaps=true}}
  end
end
local ui=require('dapui')
dap.listeners.after.event_initialized['work_ui']=function() ui.open() end
dap.listeners.before.event_terminated['work_ui']=function() ui.close() end
dap.listeners.before.event_exited['work_ui']=function() ui.close() end
end},
{"rcarriga/nvim-dap-ui",lazy=false,dependencies={"mfussenegger/nvim-dap","nvim-neotest/nvim-nio"},commit="cc9dd33aade7f20bae414d0cba163bc60d4d4b43",config=function()
require("dapui").setup({})
end},
{"theHamsta/nvim-dap-virtual-text",lazy=false,dependencies={"mfussenegger/nvim-dap"},commit="fbdb48c2ed45f4a8293d0d483f7730d24467ccb6",config=function()
require("nvim-dap-virtual-text").setup({})
end},
{"nvimdev/dashboard-nvim",lazy=false,dependencies={"nvim-tree/nvim-web-devicons"},commit="f787e3462c2ee2b6117b17c1aa4ddf66cb6f57fe",config=function()
require("dashboard").setup({["change_to_vcs_root"]=true,["config"]={["footer"]={"Made with ❤️"},["header"]={"███╗   ██╗██╗██╗  ██╗██╗   ██╗██╗███╗   ███╗","████╗  ██║██║╚██╗██╔╝██║   ██║██║████╗ ████║","██╔██╗ ██║██║ ╚███╔╝ ██║   ██║██║██╔████╔██║","██║╚██╗██║██║ ██╔██╗ ╚██╗ ██╔╝██║██║╚██╔╝██║","██║ ╚████║██║██╔╝ ██╗ ╚████╔╝ ██║██║ ╚═╝ ██║","╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝  ╚═══╝  ╚═╝╚═╝     ╚═╝"},["mru"]={["limit"]=20},["project"]={["enable"]=true}},["theme"]="hyper"})
end},
{"mattn/emmet-vim",lazy=false,commit="92ef2f74f4093edc99db5e9e4cf7e40116a85bd6"},
{"glacambre/firenvim",lazy=false,tag="0.2.17"},
{"tpope/vim-fugitive",lazy=false,dependencies={"tpope/vim-rhubarb","junegunn/gv.vim","idanarye/vim-merginal"},commit="3b753cf8c6a4dcde6edee8827d464ba9b8c4a6f0"},
{"lewis6991/gitsigns.nvim",lazy=false,dependencies={"nvim-lua/plenary.nvim"},config=function()
require("gitsigns").setup({["current_line_blame"]=true,["current_line_blame_formatter"]="   <author>, <committer_time:%R> • <summary>",["current_line_blame_opts"]={["delay"]=100,["virt_text"]=true,["virt_text_pos"]="eol"},["signcolumn"]=true,["signs"]={["add"]={["text"]="│"},["change"]={["text"]="│"},["changedelete"]={["text"]="~"},["delete"]={["text"]="_"},["topdelete"]={["text"]="‾"},["untracked"]={["text"]="┆"}},["trouble"]=true,["update_debounce"]=100})
end},
{"MagicDuck/grug-far.nvim",lazy=false,config=function()
require("grug-far").setup({["transient"]=true})
end},
{"m4xshen/hardtime.nvim",lazy=false,dependencies={"MunifTanjim/nui.nvim"},tag="v1.3.0",config=function()
require("hardtime").setup({["disable_mouse"]=false,["enable"]=true,["restriction_mode"]="hint"})
end},
{"smoka7/hop.nvim",lazy=false,commit="6e83486f351066e38c3ae9daad2a4f01dfb262ad",config=function()
require("hop").setup({})
end},
{"RRethy/vim-illuminate",lazy=false,commit="1cc33d347c574c3bd21a4852fc9ffed677c1c58c",config=function()
require('illuminate').configure({})
end},
{"lukas-reineke/indent-blankline.nvim",lazy=false,tag="v3.10.1",config=function()
require("ibl").setup({["exclude"]={["buftypes"]={"terminal","quickfix"},["filetypes"]={"","checkhealth","dashboard","help","lspinfo","packer","TelescopePrompt","TelescopeResults","yaml","markdown","text","gitcommit"}}})
end},
{"pta2002/intellitab.nvim",lazy=false,commit="955af8d74b07109d36729c623cb1bb232e25e16e"},
{"neovim/nvim-lspconfig",lazy=false,dependencies={"hrsh7th/cmp-nvim-lsp","b0o/SchemaStore.nvim"},tag="v2.12.0",config=function()
local capabilities = require('cmp_nvim_lsp').default_capabilities()
local servers = {["bashls"]={["enable"]=true},["cssls"]={["enable"]=true},["eslint"]={["enable"]=true},["gopls"]={["enable"]=true},["hls"]={["enable"]=true,["installGhc"]=true},["html"]={["enable"]=true},["htmx"]={["enable"]=true},["jsonls"]={["enable"]=true},["lua_ls"]={["enable"]=true},["nixd"]={["enable"]=true,["settings"]={["formatting"]={["command"]={"nixfmt"}}}},["pyright"]={["enable"]=true},["tailwindcss"]={["enable"]=true},["ts_ls"]={["autostart"]=true,["enable"]=true,["extraOptions"]={["settings"]={["javascript"]={["inlayHints"]={["includeInlayEnumMemberValueHints"]=true,["includeInlayFunctionLikeReturnTypeHints"]=true,["includeInlayFunctionParameterTypeHints"]=true,["includeInlayParameterNameHints"]="all",["includeInlayParameterNameHintsWhenArgumentMatchesName"]=true,["includeInlayPropertyDeclarationTypeHints"]=true,["includeInlayVariableTypeHints"]=true,["includeInlayVariableTypeHintsWhenTypeMatchesName"]=true}},["typescript"]={["inlayHints"]={["includeInlayEnumMemberValueHints"]=true,["includeInlayFunctionLikeReturnTypeHints"]=true,["includeInlayFunctionParameterTypeHints"]=true,["includeInlayParameterNameHints"]="all",["includeInlayParameterNameHintsWhenArgumentMatchesName"]=true,["includeInlayPropertyDeclarationTypeHints"]=true,["includeInlayVariableTypeHints"]=true,["includeInlayVariableTypeHintsWhenTypeMatchesName"]=true}}}},["filetypes"]={"javascript","javascriptreact","javascript.jsx","typescript","typescriptreact","typescript.tsx"}},["volar"]={["enable"]=true},["yamlls"]={["enable"]=true},["jdtls"]={["enable"]=true},["intelephense"]={["enable"]=true},["lemminx"]={["enable"]=true},["ruff"]={["enable"]=true}}
local vue_plugin = work_npm_package('@vue/typescript-plugin')
for name, settings in pairs(servers) do
  local opts = vim.deepcopy(settings)
  opts.enable, opts.installGhc, opts.package, opts.extraOptions = nil, nil, nil, nil
  opts.capabilities = capabilities
  if settings.extraOptions then opts = vim.tbl_deep_extend('force',opts,settings.extraOptions) end
  if name == 'nixd' and opts.settings then opts.settings={nixd=opts.settings} end
  if name == 'jsonls' then opts.settings={json={schemas=require('schemastore').json.schemas()}} end
  if name == 'yamlls' then opts.settings={yaml={schemaStore={enable=false,url=''},schemas=require('schemastore').yaml.schemas()}} end
  if name == 'volar' then name = 'vue_ls' end
  if name == 'ts_ls' then
    local ts=work_npm_package('typescript')
    if ts then opts.init_options=vim.tbl_deep_extend('force',opts.init_options or {},{tsserver={path=ts..'/lib/tsserver.js'}}) end
  end
  if name == 'ts_ls' and vue_plugin then
    opts.init_options=vim.tbl_deep_extend('force',opts.init_options or {},{plugins={{name='@vue/typescript-plugin',location=vue_plugin,languages={'vue'}}}})
    opts.filetypes={'javascript','javascriptreact','typescript','typescriptreact','vue'}
  end
  vim.lsp.config(name, opts)
  -- Only enable servers whose executable exists; Nix previously installed these.
  local cmd = vim.lsp.config[name] and vim.lsp.config[name].cmd
  local executable = type(cmd)=='table' and cmd[1] or ({jdtls='jdtls'})[name]
  if executable and vim.fn.executable(executable)==1 then vim.lsp.enable(name) end
end
vim.api.nvim_create_autocmd('LspAttach',{callback=function(args)
  for key, data in pairs({["<localleader>cr"]={["action"]="rename",["desc"]="rename"},["<localleader>gD"]={["action"]="declaration",["desc"]="declaration"},["<localleader>gI"]={["action"]="implementation",["desc"]="implementation"},["<localleader>gT"]={["action"]="type_definition",["desc"]="type definition"},["<localleader>gd"]={["action"]="definition",["desc"]="definition"},["<localleader>gr"]={["action"]="references",["desc"]="references"}}) do
    vim.keymap.set('n',key,vim.lsp.buf[data.action],{buffer=args.buf,desc=data.desc})
  end
  vim.keymap.set({'n','i'},'<C-k>',vim.lsp.buf.signature_help,{buffer=args.buf})
  local client=vim.lsp.get_client_by_id(args.data.client_id)
  if client and client.server_capabilities.inlayHintProvider then
    vim.lsp.inlay_hint.enable(true,{bufnr=args.buf})
  end
end})
end},
{"lukas-reineke/lsp-format.nvim",lazy=false,tag="v2.7.3",config=function()
require("lsp-format").setup({})
end},
{"onsails/lspkind.nvim",lazy=false,commit="c7274c48137396526b59d86232eabcdc7fed8a32"},
{"nvimdev/lspsaga.nvim",lazy=false,dependencies={"nvim-tree/nvim-web-devicons"},commit="cf6fc9473bba1d332eda9887855ea29ed9b37701",config=function()
require("lspsaga").setup({["beacon"]={["enable"]=true},["code_action"]={["extend_git_signs"]=false,["keys"]={["exec"]="<CR>",["quit"]={"<Esc>","q"}},["num_shortcut"]=true,["only_in_cursor"]=true,["show_server_name"]=true},["diagnostic"]={["border_follow"]=true,["diagnostic_only_current"]=false,["show_code_action"]=true},["hover"]={["open_link"]="<localleader>gx"},["implement"]={["enable"]=false},["lightbulb"]={["enable"]=false,["sign"]=false,["virtual_text"]=true},["outline"]={["auto_close"]=true,["auto_preview"]=true,["close_after_jump"]=true,["keys"]={["jump"]="e",["quit"]="q",["toggle_or_jump"]="o"},["layout"]="normal",["win_position"]="right"},["rename"]={["auto_save"]=false,["keys"]={["exec"]="<CR>",["quit"]={"<C-k>","<Esc>"},["select"]="x"}},["scroll_preview"]={["scroll_down"]="<C-t>",["scroll_up"]="<C-b>"},["symbol_in_winbar"]={["enable"]=true},["ui"]={["border"]="rounded",["code_action"]="💡"}})
end},
{"nvim-lualine/lualine.nvim",lazy=false,dependencies={"nvim-tree/nvim-web-devicons"},config=function()
-- Eviline config for lualine
-- Author: shadmansaleh
-- Credit: glepnir
local lualine = require('lualine')

--- @param str string string to truncate
--- @param trunc_width number trunctates component when screen width is less then trunc_width
--- @param trunc_len number truncates component to trunc_len number of chars
--- @param hide_width number hides component when window width is smaller then hide_width
--- @param no_ellipsis boolean whether to disable adding '...' at end after truncation
--- return string the truncated string
local function trunc(str, trunc_width, trunc_len, hide_width, no_ellipsis)
  local win_width = vim.fn.winwidth(0)
  if hide_width and win_width < hide_width then
    return ""
  elseif trunc_width and trunc_len and win_width < trunc_width and #str > trunc_len then
    return str:sub(1, trunc_len) .. (no_ellipsis and "" or "...")
  end
  return str
end

-- Color table for highlights
-- stylua: ignore
local colors = {
  bg       = '#1a1b26',
  fg       = '#c0caf5',
  yellow   = '#e0af68',
  cyan     = '#7dcfff',
  darkblue = '#1a1b26',
  green    = '#9ece6a',
  orange   = '#ff9e64',
  violet   = '#9d7cd8',
  magenta  = '#bb9af7',
  blue     = '#7aa2f7',
  red      = '#f7768e',
}

local conditions = {
  buffer_not_empty = function()
    return vim.fn.empty(vim.fn.expand('%:t')) ~= 1
  end,
  hide_in_width = function()
    return vim.fn.winwidth(0) > 80
  end,
  check_git_workspace = function()
    local filepath = vim.fn.expand('%:p:h')
    local gitdir = vim.fn.finddir('.git', filepath .. ';')
    return gitdir and #gitdir > 0 and #gitdir < #filepath
  end,
  is_not_terminal = function()
    return vim.bo.filetype ~= "toggleterm"
  end,
}

-- Config
local config = {
  options = {
    -- Disable sections and component separators
    component_separators = "",
    section_separators = "",
    theme = {
      -- We are going to use lualine_c an lualine_x as left and
      -- right section. Both are highlighted by c theme .  So we
      -- are just setting default looks o statusline
      normal = { c = { fg = colors.fg, bg = colors.bg } },
      inactive = { c = { fg = colors.fg, bg = colors.bg } },
    },
  },
  sections = {
    -- these are to remove the defaults
    lualine_a = {},
    lualine_b = {},
    lualine_y = {},
    lualine_z = {},
    -- These will be filled later
    lualine_c = {},
    lualine_x = {},
  },
  inactive_sections = {
    -- these are to remove the defaults
    lualine_a = {},
    lualine_b = {},
    lualine_y = {},
    lualine_z = {},
    lualine_c = {},
    lualine_x = {},
  },
}

-- Inserts a component in lualine_c at left section
local function ins_left(component)
  table.insert(config.sections.lualine_c, component)
end

local function ins_left_inactive(component)
  table.insert(config.inactive_sections.lualine_c, component)
end

-- Inserts a component in lualine_x at right section
local function ins_right(component)
  table.insert(config.sections.lualine_x, component)
end

local function ins_right_inactive(component)
  table.insert(config.inactive_sections.lualine_x, component)
end

ins_left {
  function()
    return '▊'
  end,
  color = { fg = colors.blue }, -- Sets highlighting of component
  padding = { left = 0, right = 1 }, -- We don't need space before this
}

ins_left {
  -- mode component
  function()
    return ""
  end,
  color = function()
    -- auto change color according to neovims mode
    local mode_color = {
      n = colors.red,
      i = colors.green,
      v = colors.blue,
      [''] = colors.blue,
      V = colors.blue,
      c = colors.magenta,
      no = colors.red,
      s = colors.orange,
      S = colors.orange,
      [''] = colors.orange,
      ic = colors.yellow,
      R = colors.violet,
      Rv = colors.violet,
      cv = colors.red,
      ce = colors.red,
      r = colors.cyan,
      rm = colors.cyan,
      ['r?'] = colors.cyan,
      ['!'] = colors.red,
      t = colors.red,
    }
    return { fg = mode_color[vim.fn.mode()] }
  end,
  padding = { right = 1 },
}

ins_left {
  -- filesize component
  'filesize',
  cond = conditions.buffer_not_empty and conditions.hide_in_width,
}

ins_left {
  'filename',
  cond = conditions.buffer_not_empty and conditions.is_not_terminal,
  file_status = true,
  path = 1,
  color = { fg = colors.magenta, gui = 'bold' },
}

ins_left_inactive({
  "filename",
  cond = conditions.buffer_not_empty and conditions.is_not_terminal,
  file_status = true, -- displays file status (readonly status, modified status)
  path = 1,
  color = { fg = colors.magenta, gui = "bold" },
})

ins_left { 'location' }

ins_left { 'progress', color = { fg = colors.fg, gui = 'bold' } }

ins_left {
  'diagnostics',
  sources = { 'nvim_diagnostic' },
  symbols = { error = ' ', warn = ' ', info = ' ' },
  diagnostics_color = {
    error = { fg = colors.red },
    warn = { fg = colors.yellow },
    info = { fg = colors.cyan },
  },
}

-- Insert mid section. You can make any number of sections in neovim :)
-- for lualine it's any number greater then 2
ins_left {
  function()
    return '%='
  end,
}

-- Add components to right sections
ins_right {
  'o:encoding', -- option component same as &encoding in viml
  fmt = string.upper, -- I'm not sure why it's upper case either ;)
  cond = conditions.hide_in_width,
  color = { fg = colors.green, gui = 'bold' },
}

ins_right {
  'fileformat',
  fmt = string.upper,
  cond = conditions.hide_in_width,
  icons_enabled = false, -- I think icons are cool but Eviline doesn't have them. sigh
  color = { fg = colors.green, gui = 'bold' },
}

ins_right {
  'branch',
  fmt = function(str)
    return trunc(str, 140, 45, nil, true)
  end,
  icon = '',
  color = { fg = colors.violet, gui = 'bold' },
}

ins_right {
  'diff',
  -- Is it me or the symbol for modified us really weird
  symbols = { added = ' ', modified = '󰝤 ', removed = ' ' },
  diff_color = {
    added = { fg = colors.green },
    modified = { fg = colors.orange },
    removed = { fg = colors.red },
  },
  cond = conditions.hide_in_width,
}

ins_right_inactive({
  "diff",
  -- Is it me or the symbol for modified us really weird
  symbols = { added = " ", modified = "󰝤 ", removed = " " },
  diff_color = {
    added = { fg = colors.green },
    modified = { fg = colors.orange },
    removed = { fg = colors.red },
  },
  cond = conditions.hide_in_width,
})

ins_right {
  function()
    return '▊'
  end,
  color = { fg = colors.blue },
  padding = { left = 1 },
}

-- Now don't forget to initialize lualine
lualine.setup(config)

end},
{"OXY2DEV/markview.nvim",lazy=false,tag="v29.0.0",config=function()
require("markview").setup({})
end},
{"smoka7/multicursors.nvim",lazy=false,dependencies={"nvimtools/hydra.nvim"},commit="72225ea9e4443c3f4b9df91d0193e07c4ee8d382",config=function()
require("multicursors").setup({})
end},
{"SmiteshP/nvim-navbuddy",lazy=false,dependencies={"SmiteshP/nvim-navic","MunifTanjim/nui.nvim"},commit="a34786c77a528519f6b8a142db7609f6e387842d",config=function()
require("nvim-navbuddy").setup({["lsp"]={["auto_attach"]=true},["mappings"]={["0"]="root",["<C-s>"]="hsplit",["<C-v>"]="vsplit",["<enter>"]="select",["<esc>"]="close",["A"]="append_scope",["E"]="move_up",["F"]="fold_delete",["L"]="insert_scope",["N"]="move_down",["V"]="visual_scope",["Y"]="yank_scope",["a"]="append_name",["c"]="comment",["d"]="delete",["e"]="previous_sibling",["f"]="fold_create",["h"]="parent",["i"]="children",["l"]="insert_name",["n"]="next_sibling",["o"]="select",["q"]="close",["r"]="rename",["s"]="toggle_preview",["v"]="visual_name",["y"]="yank_name"}})
end},
{"nvim-neotest/neotest",lazy=false,dependencies={"nvim-lua/plenary.nvim","nvim-neotest/nvim-nio","antoinemadec/FixCursorHold.nvim","nvim-treesitter/nvim-treesitter","nvim-neotest/neotest-jest","marilari88/neotest-vitest","thenbe/neotest-playwright"},dependencies={"nvim-lua/plenary.nvim","nvim-neotest/nvim-nio","antoinemadec/FixCursorHold.nvim","nvim-treesitter/nvim-treesitter","nvim-neotest/neotest-jest","marilari88/neotest-vitest","thenbe/neotest-playwright","mfussenegger/nvim-dap"},config=function()
require('neotest').setup({adapters={require('neotest-jest')({}),require('neotest-vitest')({}),require('neotest-playwright').adapter({})}})
end},
{"nvimtools/none-ls.nvim",lazy=false,dependencies={"nvim-lua/plenary.nvim","nvimtools/none-ls-extras.nvim"},commit="c4b82bb63b13856ba4d6b971b7aad3bb38fc6fe2",config=function()
local null_ls=require('null-ls')
local sources={}
for _, kind in ipairs({'diagnostics','code_actions','formatting'}) do
  for name, opts in pairs(({["code_actions"]={["statix"]={["enable"]=true}},["diagnostics"]={["statix"]={["enable"]=true},["yamllint"]={["enable"]=true}},["formatting"]={["black"]={["enable"]=true},["hclfmt"]={["enable"]=true},["nixfmt"]={["enable"]=true,["package"]="nixfmt"},["prettier"]={["disableTsServerFormatter"]=true,["enable"]=true},["stylua"]={["enable"]=true},["yamlfmt"]={["enable"]=true}}})[kind] or {}) do
    if opts.enable and null_ls.builtins[kind] and null_ls.builtins[kind][name] then
      table.insert(sources,null_ls.builtins[kind][name])
    elseif opts.enable then
      local ok, source=pcall(require,'none-ls.'..kind..'.'..name)
      if ok then table.insert(sources,source) end
    end
  end
end
null_ls.setup({sources=sources,update_in_insert=false})
end},
{"rcarriga/nvim-notify",lazy=false,commit="8701bece920b38ea289b457f902e2ad184131a5d",config=function()
require("notify").setup({})
end},
{"jeffkreeftmeijer/vim-numbertoggle",lazy=false,commit="075b7478777e694fbac330ee34a74590dad0fee1"},
{"windwp/nvim-autopairs",lazy=false,commit="3172f40c16563db871a58f20d205c710ad782311",config=function()
require("nvim-autopairs").setup({})
end},
{"nvim-tree/nvim-tree.lua",lazy=false,tag="v1.19.0",config=function()
require("nvim-tree").setup({["actions"]={["open_file"]={["quit_on_open"]=true}},["git"]={["enable"]=true,["ignore"]=false,["show_on_dirs"]=true,["show_on_open_dirs"]=true},["modified"]={["enable"]=true,["show_on_dirs"]=true,["show_on_open_dirs"]=true},["on_attach"]=function(bufnr)
  local api = require('nvim-tree.api')
  local function opts(desc)
    return { desc = 'nvim-tree: ' .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
  end

  vim.keymap.set('n', '<C-]>',   api.tree.change_root_to_node,        opts('CD'))
  vim.keymap.set('n', '<C-e>',   api.node.open.replace_tree_buffer,   opts('Open: In Place'))
  vim.keymap.set('n', '<C-k>',   api.node.show_info_popup,            opts('Info'))
  vim.keymap.set('n', '<C-r>',   api.fs.rename_sub,                   opts('Rename: Omit Filename'))
  vim.keymap.set('n', '<C-t>',   api.node.open.tab,                   opts('Open: New Tab'))
  vim.keymap.set('n', '<C-v>',   api.node.open.vertical,              opts('Open: Vertical Split'))
  vim.keymap.set('n', '<C-x>',   api.node.open.horizontal,            opts('Open: Horizontal Split'))
  vim.keymap.set('n', '<BS>',    api.node.navigate.parent_close,      opts('Close Directory'))
  vim.keymap.set('n', '<CR>',    api.node.open.edit,                  opts('Open'))
  vim.keymap.set('n', '<Tab>',   api.node.open.preview,               opts('Open Preview'))
  vim.keymap.set('n', '>',       api.node.navigate.sibling.next,      opts('Next Sibling'))
  vim.keymap.set('n', '<',       api.node.navigate.sibling.prev,      opts('Previous Sibling'))
  vim.keymap.set('n', '.',       api.node.run.cmd,                    opts('Run Command'))
  vim.keymap.set('n', '-',       api.tree.change_root_to_parent,      opts('Up'))
  vim.keymap.set('n', 'a',       api.fs.create,                       opts('Create File Or Directory'))
  vim.keymap.set('n', 'bd',      api.marks.bulk.delete,               opts('Delete Bookmarked'))
  vim.keymap.set('n', 'bt',      api.marks.bulk.trash,                opts('Trash Bookmarked'))
  vim.keymap.set('n', 'bmv',     api.marks.bulk.move,                 opts('Move Bookmarked'))
  vim.keymap.set('n', 'B',       api.tree.toggle_no_buffer_filter,    opts('Toggle Filter: No Buffer'))
  vim.keymap.set('n', 'c',       api.fs.copy.node,                    opts('Copy'))
  vim.keymap.set('n', 'C',       api.tree.toggle_git_clean_filter,    opts('Toggle Filter: Git Clean'))
  vim.keymap.set('n', '[c',      api.node.navigate.git.prev,          opts('Prev Git'))
  vim.keymap.set('n', ']c',      api.node.navigate.git.next,          opts('Next Git'))
  vim.keymap.set('n', 'd',       api.fs.remove,                       opts('Delete'))
  vim.keymap.set('n', 'D',       api.fs.trash,                        opts('Trash'))
  vim.keymap.set('n', 'E',       api.tree.expand_all,                 opts('Expand All'))
  vim.keymap.set("n", "k",       api.fs.rename_basename,              opts("Rename: Basename"))
  vim.keymap.set('n', ']e',      api.node.navigate.diagnostics.next,  opts('Next Diagnostic'))
  vim.keymap.set('n', '[e',      api.node.navigate.diagnostics.prev,  opts('Prev Diagnostic'))
  vim.keymap.set('n', 'F',       api.live_filter.clear,               opts('Live Filter: Clear'))
  vim.keymap.set('n', 'f',       api.live_filter.start,               opts('Live Filter: Start'))
  vim.keymap.set('n', 'g?',      api.tree.toggle_help,                opts('Help'))
  vim.keymap.set('n', 'gy',      api.fs.copy.absolute_path,           opts('Copy Absolute Path'))
  vim.keymap.set('n', 'H',       api.tree.toggle_hidden_filter,       opts('Toggle Filter: Dotfiles'))
  vim.keymap.set('n', 'I',       api.tree.toggle_gitignore_filter,    opts('Toggle Filter: Git Ignore'))
  vim.keymap.set('n', 'J',       api.node.navigate.sibling.last,      opts('Last Sibling'))
  vim.keymap.set('n', 'K',       api.node.navigate.sibling.first,     opts('First Sibling'))
  vim.keymap.set('n', 'L',       api.node.open.toggle_group_empty,    opts('Toggle Group Empty'))
  vim.keymap.set('n', 'M',       api.tree.toggle_no_bookmark_filter,  opts('Toggle Filter: No Bookmark'))
  vim.keymap.set('n', 'm',       api.marks.toggle,                    opts('Toggle Bookmark'))
  vim.keymap.set('n', 'o',       api.node.open.edit,                  opts('Open'))
  vim.keymap.set('n', 'O',       api.node.open.no_window_picker,      opts('Open: No Window Picker'))
  vim.keymap.set('n', 'p',       api.fs.paste,                        opts('Paste'))
  vim.keymap.set('n', 'P',       api.node.navigate.parent,            opts('Parent Directory'))
  vim.keymap.set('n', 'q',       api.tree.close,                      opts('Close'))
  vim.keymap.set('n', 'r',       api.fs.rename,                       opts('Rename'))
  vim.keymap.set('n', 'R',       api.tree.reload,                     opts('Refresh'))
  vim.keymap.set('n', 's',       api.node.run.system,                 opts('Run System'))
  vim.keymap.set('n', 'S',       api.tree.search_node,                opts('Search'))
  vim.keymap.set('n', 'u',       api.fs.rename_full,                  opts('Rename: Full Path'))
  vim.keymap.set('n', 'U',       api.tree.toggle_custom_filter,       opts('Toggle Filter: Hidden'))
  vim.keymap.set('n', 'W',       api.tree.collapse_all,               opts('Collapse'))
  vim.keymap.set('n', 'x',       api.fs.cut,                          opts('Cut'))
  vim.keymap.set('n', 'y',       api.fs.copy.filename,                opts('Copy Name'))
  vim.keymap.set('n', 'Y',       api.fs.copy.relative_path,           opts('Copy Relative Path'))
  vim.keymap.set('n', '<2-LeftMouse>',  api.node.open.edit,           opts('Open'))
  vim.keymap.set('n', '<2-RightMouse>', api.tree.change_root_to_node, opts('CD'))
end
,["respect_buf_cwd"]=true,["sync_root_with_cwd"]=true,["update_focused_file"]={["enable"]=true,["update_root"]=true}})
end},
{"kevinhwang91/nvim-ufo",lazy=false,dependencies={"kevinhwang91/promise-async"},commit="ab3eb124062422d276fae49e0dd63b3ad1062cfc",config=function()
for _, rtp in ipairs(vim.api.nvim_list_runtime_paths()) do
  if rtp:match("promise%-async$") then
    package.loaded.async = nil
    package.loaded.promise = nil
    package.loaded.async = assert(loadfile(rtp .. "/lua/async.lua"))()
    package.loaded.promise = assert(loadfile(rtp .. "/lua/promise.lua"))()
    break
  end
end

require("ufo").setup({})
end},
{"tris203/precognition.nvim",lazy=false,tag="v1.3.0",config=function()
require("precognition").setup({["hints"]={["B"]={["prio"]=6,["text"]="B"},["Caret"]={["prio"]=2,["text"]="^"},["Dollar"]={["prio"]=1,["text"]="$"},["E"]={["prio"]=5,["text"]="K"},["MatchingPair"]={["prio"]=5,["text"]="%"},["W"]={["prio"]=7,["text"]="W"},["Zero"]={["prio"]=1,["text"]="0"},["b"]={["prio"]=9,["text"]="b"},["e"]={["prio"]=8,["text"]="k"},["w"]={["prio"]=10,["text"]="w"}},["startVisible"]=false})
end},
{"DrKJeff16/project.nvim",lazy=false,enabled=vim.env.WORK_VDI_BOOTSTRAP~='1',tag="v6.4.1-1",config=function()
require("project").setup({})
end},
{"HiPhish/rainbow-delimiters.nvim",lazy=false},
{"ThePrimeagen/refactoring.nvim",lazy=false,dependencies={"nvim-lua/plenary.nvim","nvim-treesitter/nvim-treesitter"},config=function()
require("refactoring").setup({})
end},
{"tpope/vim-repeat",lazy=false,commit="65846025c15494983dafe5e3b46c8f88ab2e9635"},
{"b0o/SchemaStore.nvim",lazy=false,commit="98c0d97389a1d46d7ee442161e05e4175d3763ec"},
{"dstein64/nvim-scrollview",lazy=false,dependencies={},commit="b9e6ee00e9e20330b426fbec47812c2213d371ca",config=function()
require("scrollview").setup({})
end},
{"nvim-telescope/telescope.nvim",lazy=false,dependencies={"nvim-lua/plenary.nvim","nvim-telescope/telescope-file-browser.nvim","nvim-telescope/telescope-frecency.nvim","kkharji/sqlite.lua","nvim-telescope/telescope-project.nvim"},tag='v0.2.1',config=function()
-- Keep the environment picker local: no extra repository or authentication.
package.preload['telescope._extensions.env']=function()
  local actions=require('telescope.actions')
  local state=require('telescope.actions.state')
  return require('telescope').register_extension({exports={env=function(opts)
    local entries={}
    for name,value in pairs(vim.fn.environ()) do entries[#entries+1]={name=name,value=value} end
    table.sort(entries,function(a,b) return a.name<b.name end)
    require('telescope.pickers').new(opts or {},{
      prompt_title='Environment variables',
      finder=require('telescope.finders').new_table({results=entries,entry_maker=function(item)
        return {value=item,display=item.name,ordinal=item.name}
      end}),
      sorter=require('telescope.config').values.generic_sorter(opts or {}),
      attach_mappings=function(buf,map)
        local function insert(value)
          actions.close(buf)
          vim.api.nvim_put({value},'c',true,true)
        end
        actions.select_default:replace(function() local e=state.get_selected_entry(); if e then insert(e.value.name) end end)
        for _,mode in ipairs({'i','n'}) do
          map(mode,'<C-a>',function() local e=state.get_selected_entry(); if e then insert(e.value.value) end end)
          map(mode,'<C-e>',function()
            local e=state.get_selected_entry(); if not e then return end
            actions.close(buf)
            vim.ui.input({prompt=e.value.name..' = ',default=e.value.value},function(value)
              if value then vim.fn.setenv(e.value.name,value) end
            end)
          end)
        end
        return true
      end,
    }):find()
  end}})
end
require('telescope').setup({})
for _, ext in ipairs({'file_browser','frecency','projects','project','env'}) do
  pcall(require('telescope').load_extension,ext)
end
end},
{"folke/todo-comments.nvim",lazy=false,dependencies={"nvim-lua/plenary.nvim"},tag="v1.5.0",config=function()
require("todo-comments").setup({})
end},
{"akinsho/toggleterm.nvim",lazy=false,commit="9a88eae817ef395952e08650b3283726786fb5fb",config=function()
require("toggleterm").setup({["winbar"]={["enable"]=false}})
end},
{"nvim-treesitter/nvim-treesitter",lazy=false,commit="29212d826054bb2948fa9d3a99eca9bf6a050eb2",branch='main',build=function() if (vim.fn.executable('cc')==1 or vim.fn.executable('gcc')==1 or vim.fn.executable('clang')==1) and vim.fn.executable('tree-sitter')==1 then vim.cmd('TSUpdate') else vim.notify('Grammar builds skipped: install a C compiler and tree-sitter CLI, then rerun the installer.',vim.log.levels.WARN) end end,config=function()
require('nvim-treesitter').setup({})
vim.api.nvim_create_autocmd('FileType',{callback=function(args)
  local ok=pcall(vim.treesitter.start,args.buf)
  if ok then
    vim.bo[args.buf].indentexpr="v:lua.require'nvim-treesitter'.indentexpr()"
    vim.wo.foldmethod='expr'
    vim.wo.foldexpr='v:lua.vim.treesitter.foldexpr()'
  end
end})
end},
{"nvim-treesitter/nvim-treesitter-textobjects",lazy=false,dependencies={"nvim-treesitter/nvim-treesitter"},commit="5ca4aaa6efdcc59be46b95a3e876300cfead05ef",branch='main',config=function()
require('nvim-treesitter-textobjects').setup({select={lookahead=true}})
vim.keymap.set({"x","o"},"aa",function() require("nvim-treesitter-textobjects.select").select_textobject("@parameter.outer","textobjects") end)
vim.keymap.set({"x","o"},"ac",function() require("nvim-treesitter-textobjects.select").select_textobject("@class.outer","textobjects") end)
vim.keymap.set({"x","o"},"af",function() require("nvim-treesitter-textobjects.select").select_textobject("@function.outer","textobjects") end)
vim.keymap.set({"x","o"},"ai",function() require("nvim-treesitter-textobjects.select").select_textobject("@conditional.outer","textobjects") end)
vim.keymap.set({"x","o"},"al",function() require("nvim-treesitter-textobjects.select").select_textobject("@loop.outer","textobjects") end)
vim.keymap.set({"x","o"},"at",function() require("nvim-treesitter-textobjects.select").select_textobject("@comment.outer","textobjects") end)
vim.keymap.set({"x","o"},"ia",function() require("nvim-treesitter-textobjects.select").select_textobject("@parameter.inner","textobjects") end)
vim.keymap.set({"x","o"},"ic",function() require("nvim-treesitter-textobjects.select").select_textobject("@class.inner","textobjects") end)
vim.keymap.set({"x","o"},"if",function() require("nvim-treesitter-textobjects.select").select_textobject("@function.inner","textobjects") end)
vim.keymap.set({"x","o"},"ii",function() require("nvim-treesitter-textobjects.select").select_textobject("@conditional.inner","textobjects") end)
vim.keymap.set({"x","o"},"il",function() require("nvim-treesitter-textobjects.select").select_textobject("@loop.inner","textobjects") end)
vim.keymap.set({"n","x","o"},"]M",function() require("nvim-treesitter-textobjects.move").goto_next_end("@function.outer","textobjects") end)
vim.keymap.set({"n","x","o"},"][",function() require("nvim-treesitter-textobjects.move").goto_next_end("@class.outer","textobjects") end)
vim.keymap.set({"n","x","o"},"]]",function() require("nvim-treesitter-textobjects.move").goto_next_start("@class.outer","textobjects") end)
vim.keymap.set({"n","x","o"},"]m",function() require("nvim-treesitter-textobjects.move").goto_next_start("@function.outer","textobjects") end)
vim.keymap.set({"n","x","o"},"[M",function() require("nvim-treesitter-textobjects.move").goto_previous_end("@function.outer","textobjects") end)
vim.keymap.set({"n","x","o"},"[]",function() require("nvim-treesitter-textobjects.move").goto_previous_end("@class.outer","textobjects") end)
vim.keymap.set({"n","x","o"},"[[",function() require("nvim-treesitter-textobjects.move").goto_previous_start("@class.outer","textobjects") end)
vim.keymap.set({"n","x","o"},"[m",function() require("nvim-treesitter-textobjects.move").goto_previous_start("@function.outer","textobjects") end)

end},
{"folke/trouble.nvim",lazy=false,commit="bd67efe408d4816e25e8491cc5ad4088e708a69a",config=function()
require("trouble").setup({})
end},
{"windwp/nvim-ts-autotag",lazy=false,commit="d7220b55e16ed3c04e88086256def5d282429493",config=function()
require("nvim-ts-autotag").setup({})
end},
{"folke/twilight.nvim",lazy=false,commit="664e752f4a219801265cc3fc18782b457b58c1e1",config=function()
require("twilight").setup({})
end},
{"tpope/vim-surround",lazy=false,commit="3d188ed2113431cf8dac77be61b842acb64433d9"},
{"lukas-reineke/virt-column.nvim",lazy=false,tag="v2.0.3",config=function()
require("virt-column").setup({["exclude"]={["buftypes"]={"nofile","quickfix","terminal","prompt"},["filetypes"]={"dashboard","lspinfo","packer","checkhealth","help","man","TelescopePrompt","TelescopeResults","markdown","text","gitcommit"}},["virtcolumn"]="80,120,140"})
end},
{"nvim-tree/nvim-web-devicons",lazy=false,config=function()
require("nvim-web-devicons").setup({})
end},
{"folke/which-key.nvim",lazy=false,commit="3aab2147e74890957785941f0c1ad87d0a44c15a",config=function()
require("which-key").setup({["icons"]={["breadcrumb"]="»",["group"]="+",["mappings"]=false,["separator"]="➜"},["layout"]={["spacing"]=3,["width"]={["max"]=50,["min"]=20}},["plugins"]={["marks"]=true,["presets"]={["g"]=true,["motions"]=true,["nav"]=true,["operatos"]=true,["text_objects"]=true,["windows"]=true,["z"]=true},["registers"]=true},["replace"]={["desc"]={{"<space>","SPC"},{"<[cC][rR]>","RETURN"},{"<[tT][aA][bB]>","TAB"}}},["show_help"]=true,["show_keys"]=true,["spec"]={{"<leader>b",["group"]="buffers",["icon"]=""},{"<leader>d",["group"]="diagnostics",["icon"]=""},{"<leader>e",["group"]="errors",["icon"]=""},{"<leader>f",["group"]="files",["icon"]=""},{"<leader>g",["group"]="git",["icon"]=""},{"<leader>j",["group"]="jump",["icon"]=""},{"<leader>l",["group"]="lsp",["icon"]=""},{"<leader>p",["group"]="projects",["icon"]=""},{"<leader>q",["group"]="quit",["icon"]=""},{"<leader>r",["group"]="replace",["icon"]=""},{"<leader>s",["group"]="search",["icon"]=""},{"<leader>t",["group"]="test",["icon"]=""},{"<leader>T",["group"]="toggles",["icon"]=""},{"<leader>w",["group"]="windows",["icon"]=""},{"<leader>x",["group"]="text",["icon"]=""},{"<localleader>g",["group"]="go to",["icon"]=""},{"<localleader>c",["group"]="code",["icon"]=""},{"<localleader>ce",["group"]="extract",["icon"]=""},{"<localleader>ci",["group"]="inline",["icon"]=""}},["win"]={["border"]="none",["padding"]={2,2},["wo"]={["winblend"]=0}}})
end},
{"antoinemadec/FixCursorHold.nvim",commit="1900f89dc17c603eec29960f57c00bd9ae696495"},
{"hrsh7th/cmp-buffer",commit="b74fab3656eea9de20a9b8116afa3cfc4ec09657"},
{"hrsh7th/cmp-calc",commit="5947b412da67306c5b68698a02a846760059be2e"},
{"hrsh7th/cmp-cmdline",commit="d126061b624e0af6c3a556428712dd4d4194ec6d"},
{"hrsh7th/cmp-nvim-lsp",commit="cbc7b02bb99fae35cb42f514762b89b5126651ef"},
{"hrsh7th/cmp-nvim-lsp-document-symbol",commit="f94f7ba948e32cd302caba1c2ca3f7c697fb4fcf"},
{"hrsh7th/cmp-nvim-lsp-signature-help",commit="fd3e882e56956675c620898bf1ffcf4fcbe7ec84"},
{"hrsh7th/cmp-path",commit="c642487086dbd9a93160e1679a1327be111cbc25"},
{"idanarye/vim-merginal",commit="3dca10fd8bce10edbc2024651db4ffb6dd2d89de"},
{"junegunn/gv.vim",commit="ed7e9c6a118d92462c7d709c34a92682b60fa9f7"},
{"kevinhwang91/promise-async",commit="119e8961014c9bfaf1487bf3c2a393d254f337e2"},
{"kkharji/sqlite.lua",commit="50092d60feb242602d7578398c6eb53b4a8ffe7b"},
{"lukas-reineke/cmp-rg",tag="v1.3.11"},
{"marilari88/neotest-vitest",commit="b0c265743c877058068dbc40d104ea5d40e6b257"},
{"nvim-neotest/neotest-jest",commit="0e7979d51301dfae5ef839d771bd28cf593fde3f"},
{"nvim-telescope/telescope-file-browser.nvim",commit="3610dc7dc91f06aa98b11dca5cc30dfa98626b7e"},
{"nvim-telescope/telescope-frecency.nvim",commit="5479d8a269e30479280c59e44f805396127653e6"},
{"nvim-telescope/telescope-project.nvim",commit="8e11df94419e444601c09828dadf70890484e443"},
{"nvimtools/hydra.nvim",tag="v1.0.3"},
{"nvimtools/none-ls-extras.nvim",commit="9a8b8a9aeb43382e5aaf49b00b7cfb5d42d32118"},
{"rafamadriz/friendly-snippets",commit="b4d01b0fdf3c9a549961c2f9ffe8dc09be166219"},
{"ray-x/cmp-treesitter",commit="958fcfa0d8ce46d215e19cc3992c542f576c4123"},
{"saadparwaiz1/cmp_luasnip",commit="98d9cb5c2c38532bd9bdb481067b20fea8f32e90"},
{"tamago324/cmp-zsh",commit="c24db8e58fac9006ec23d93f236749288d00dec9"},
{"thenbe/neotest-playwright",commit="6266945039dac27a354de33d2f2a66e75485d5e9"},
{"tpope/vim-rhubarb",commit="5496d7c94581c4c9ad7430357449bb57fc59f501"}
},{checker={enabled=false},change_detection={notify=false}})
if colemak then vim.keymap.set("n","n","j",{["silent"]=true}) end
if colemak then vim.keymap.set("n","N","J",{["silent"]=true}) end
if colemak then vim.keymap.set("n","e","k",{["silent"]=true}) end
if colemak then vim.keymap.set("n","E","K",{["silent"]=true}) end
if colemak then vim.keymap.set("n","i","l",{["silent"]=true}) end
if colemak then vim.keymap.set("n","I","L",{["silent"]=true}) end
if colemak then vim.keymap.set("n","j","n",{["silent"]=true}) end
if colemak then vim.keymap.set("n","J","N",{["silent"]=true}) end
if colemak then vim.keymap.set("n","k","e",{["silent"]=true}) end
if colemak then vim.keymap.set("n","K","E",{["silent"]=true}) end
if colemak then vim.keymap.set("n","l","i",{["silent"]=true}) end
if colemak then vim.keymap.set("n","L","I",{["silent"]=true}) end
if colemak then vim.keymap.set("n","<C-p>","<C-e>",{["silent"]=true}) end
if colemak then vim.keymap.set("n","<C-e>","<C-p>",{["silent"]=true}) end
if colemak then vim.keymap.set("n","<C-P>","<C-E>",{["silent"]=true}) end
if colemak then vim.keymap.set("n","<C-E>","<C-P>",{["silent"]=true}) end
vim.keymap.set("n","x","\"_x",{["silent"]=true})
vim.keymap.set("n","X","\"_X",{["silent"]=true})
vim.keymap.set("n","<Del>","\"_x",{["silent"]=true})
vim.keymap.set("t","<Esc>","<C-\\><C-n>",{["silent"]=true})
vim.keymap.set("n","+","<C-x>",{["silent"]=true})
vim.keymap.set("n","-","<C-a>",{["silent"]=true})
vim.keymap.set("n","<Tab>",function() require('intellitab').indent() end,{["silent"]=true})
vim.keymap.set({"i","s"},"<C-e>",function()
 local ls = require "luasnip"
 if ls.expand_or_jumpable() then
   ls.expand_or_jump()
 end
end
,{["silent"]=true})
vim.keymap.set({"i","s"},"<C-n>",function()
 local ls = require "luasnip"
 if ls.jumpable(-1) then
   ls.jump(-1)
 end
end
,{["silent"]=true})
vim.keymap.set("n","<leader><leader>",":",{["silent"]=true,["desc"]="run command"})
vim.keymap.set("n","<leader><Tab>",":e#<CR>",{["silent"]=true,["desc"]="last buffer"})
vim.keymap.set("n","<leader>'","<cmd>ToggleTerm size=10 direction=horizontal<CR>",{["silent"]=true,["desc"]="toggle terminal"})
vim.keymap.set("n","<leader>/","<cmd>ToggleTerm2 size=10 direction=horizontal<CR>",{["silent"]=true,["desc"]="toggle extra terminal"})
vim.keymap.set("n","<leader>c","<cmd>MCstart<CR>",{["silent"]=true,["desc"]="add cursor"})
vim.keymap.set("n","<leader>bb","<cmd>Telescope buffers<CR>",{["silent"]=true,["desc"]="find buffer"})
vim.keymap.set("n","<leader>bd","<cmd>bd<CR>",{["silent"]=true,["desc"]="destroy buffer"})
vim.keymap.set("n","<leader>bk","<cmd>q!<CR>",{["silent"]=true,["desc"]="kill buffer"})
vim.keymap.set("n","<leader>db","<cmd>Lspsaga show_buf_diagnostics<CR>",{["silent"]=true,["desc"]="buffer diagnostics"})
vim.keymap.set("n","<leader>dl","<cmd>Trouble loclist<CR>",{["silent"]=true,["desc"]="loclist"})
vim.keymap.set("n","<leader>dq","<cmd>Trouble quickfix<CR>",{["silent"]=true,["desc"]="quickfixes"})
vim.keymap.set("n","<leader>dr","<cmd>Trouble lsp_references toggle<CR>",{["silent"]=true,["desc"]="references"})
vim.keymap.set("n","<leader>dt","<cmd>Trouble diagnostics toggle<CR>",{["silent"]=true,["desc"]="toggle trouble"})
vim.keymap.set("n","<leader>ed","<cmd>Lspsaga show_cursor_diagnostics<CR>",{["silent"]=true,["desc"]="show diagnostics for cursor"})
vim.keymap.set("n","<leader>eD","<cmd>Lspsaga show_line_diagnostics<CR>",{["silent"]=true,["desc"]="show diagnostics for line"})
vim.keymap.set("n","<leader>ee","<cmd>Lspsaga diagnostic_jump_prev<CR>",{["silent"]=true,["desc"]="prev"})
vim.keymap.set("n","<leader>en","<cmd>Lspsaga diagnostic_jump_next<CR>",{["silent"]=true,["desc"]="next"})
vim.keymap.set("n","<leader>fd","<cmd>Telescope file_browser path=%:p:h<CR>",{["silent"]=true,["desc"]="find files in dir"})
vim.keymap.set("n","<leader>ff","<cmd>Telescope find_files hidden=true<CR>",{["silent"]=true,["desc"]="find files"})
vim.keymap.set("n","<leader>fr","<cmd>Telescope frecency<CR>",{["silent"]=true,["desc"]="recent files"})
vim.keymap.set("n","<leader>fR","<cmd>so $MYVIMRC<CR>",{["silent"]=true,["desc"]="reload configuration"})
vim.keymap.set("n","<leader>fs","<cmd>w!<CR>",{["silent"]=true,["desc"]="save files"})
vim.keymap.set("n","<leader>ft","<cmd>NvimTreeFindFileToggle<CR>",{["silent"]=true,["desc"]="toggle filetree"})
vim.keymap.set("n","<leader>ga","<cmd>Git add .<CR>",{["silent"]=true,["desc"]="add ."})
vim.keymap.set("n","<leader>gb","<cmd>Telescope git_branches<CR>",{["silent"]=true,["desc"]="branches"})
vim.keymap.set("n","<leader>gB","<cmd>GBrowse<CR>",{["silent"]=true,["desc"]="git browse"})
vim.keymap.set("n","<leader>gc","<cmd>Git commit<CR>",{["silent"]=true,["desc"]="commit"})
vim.keymap.set("n","<leader>gd","<cmd>Git diff<CR>",{["silent"]=true,["desc"]="diff"})
vim.keymap.set("n","<leader>gD","<cmd>Gdiffsplit<CR>",{["silent"]=true,["desc"]="diff split"})
vim.keymap.set("n","<leader>ge","<cmd>Gitsigns prev_hunk<CR>",{["silent"]=true,["desc"]="prev hunk"})
vim.keymap.set("n","<leader>gg","<cmd>Git<CR>",{["silent"]=true,["desc"]="status"})
vim.keymap.set("n","<leader>gh","<cmd>Gitsigns toggle_linehl<CR>",{["silent"]=true,["desc"]="highlight hunks"})
vim.keymap.set("n","<leader>gH","<cmd>Gitsigns preview_hunk<CR>",{["silent"]=true,["desc"]="preview hunk"})
vim.keymap.set("n","<leader>gl","<cmd>Git log<CR>",{["silent"]=true,["desc"]="log"})
vim.keymap.set("n","<leader>gm","<cmd>MerginalToggle<CR>",{["silent"]=true,["desc"]="toggle merginal"})
vim.keymap.set("n","<leader>gn","<cmd>Gitsigns next_hunk<CR>",{["silent"]=true,["desc"]="next hunk"})
vim.keymap.set("n","<leader>go","<cmd>GBrowse<CR>",{["silent"]=true,["desc"]="open repo"})
vim.keymap.set("n","<leader>gp","<cmd>Git push<CR>",{["silent"]=true,["desc"]="push"})
vim.keymap.set("n","<leader>gP","<cmd>Git pull<CR>",{["silent"]=true,["desc"]="pull"})
vim.keymap.set("n","<leader>gr","<cmd>GRemove<CR>",{["silent"]=true,["desc"]="rm"})
vim.keymap.set("n","<leader>gs","<cmd>Gitsigns stage_hunk<CR>",{["silent"]=true,["desc"]="stage hunk"})
vim.keymap.set("n","<leader>gt","<cmd>Gitsigns toggle_signs<CR>",{["silent"]=true,["desc"]="toggle gutter signs"})
vim.keymap.set("n","<leader>gu","<cmd>Gitsigns reset_hunk<CR>",{["silent"]=true,["desc"]="undo hunk"})
vim.keymap.set("n","<leader>gv","<cmd>GV<CR>",{["silent"]=true,["desc"]="view commits"})
vim.keymap.set("n","<leader>gV","<cmd>GV!<CR>",{["silent"]=true,["desc"]="view buffer commits"})
vim.keymap.set("n","<leader>jb","<cmd>HopWordBC<CR>",{["silent"]=true,["desc"]="word backwards"})
vim.keymap.set("n","<leader>jf","<cmd>HopWordAC<CR>",{["silent"]=true,["desc"]="word forward"})
vim.keymap.set("n","<leader>jj","<cmd>HopChar1<CR>",{["silent"]=true,["desc"]="char"})
vim.keymap.set("n","<leader>jJ","<cmd>HopChar2<CR>",{["silent"]=true,["desc"]="2 chars"})
vim.keymap.set("n","<leader>jl","<cmd>HopLine<CR>",{["silent"]=true,["desc"]="line bidirectional"})
vim.keymap.set("n","<leader>jw","<cmd>HopWord<CR>",{["silent"]=true,["desc"]="word bidirectional"})
vim.keymap.set("n","<leader>lb","<cmd>Telescope diagnostics bufnr=0 theme=get_ivy<CR>",{["silent"]=true,["desc"]="buffer diagnostics"})
vim.keymap.set("n","<leader>lc","<cmd>lua vim.lsp.buf.code_action()<CR>",{["silent"]=true,["desc"]="code action"})
vim.keymap.set("n","<leader>ld","<cmd>Telescope diagnostics<CR>",{["silent"]=true,["desc"]="diagnostics"})
vim.keymap.set("n","<leader>le","<cmd>lua vim.diagnostic.goto_prev()<CR>",{["silent"]=true,["desc"]="prev diagnostic"})
vim.keymap.set("n","<leader>li","<cmd>LspInfo<CR>",{["silent"]=true,["desc"]="info"})
vim.keymap.set("n","<leader>ln","<cmd>lua vim.diagnostic.goto_next()<CR>",{["silent"]=true,["desc"]="next diagnostic"})
vim.keymap.set("n","<leader>lq","<cmd>lua vim.diagnostic.setloclist()<CR>",{["silent"]=true,["desc"]="quickfix"})
vim.keymap.set("n","<leader>ls","<cmd>Telescope lsp_document_symbols<CR>",{["silent"]=true,["desc"]="document symbols"})
vim.keymap.set("n","<leader>lS","<cmd>Telescope lsp_dynamic_workspace_symbols<CR>",{["silent"]=true,["desc"]="workspace symbols"})
vim.keymap.set("n","<leader>pe","<cmd>Telescope env<CR>",{["silent"]=true,["desc"]="environment variables"})
vim.keymap.set("n","<leader>pf","<cmd>Telescope git_files<CR>",{["silent"]=true,["desc"]="find files"})
vim.keymap.set("n","<leader>pp","<cmd>Telescope projects<CR>",{["silent"]=true,["desc"]="switch"})
vim.keymap.set("n","<leader>ps","<cmd>lua require('telescope.builtin').live_grep({ additional_args = { '--fixed-strings' }})<CR>",{["silent"]=true,["desc"]="search"})
vim.keymap.set("n","<leader>pS","<cmd>Telescope live_grep<CR>",{["silent"]=true,["desc"]="search regex"})
vim.keymap.set("n","<leader>pt","<cmd>TodoTelescope<CR>",{["silent"]=true,["desc"]="TODOs"})
vim.keymap.set("n","<leader>qq","<cmd>qa<CR>",{["silent"]=true,["desc"]="quit"})
vim.keymap.set("n","<leader>qQ","<cmd>qa!<CR>",{["silent"]=true,["desc"]="quit without saving"})
vim.keymap.set("n","<leader>rb","<cmd>lua require('grug-far').open({ prefills = { paths = vim.fn.expand(\"%:p\") } })<CR>",{["silent"]=true,["desc"]="buffer"})
vim.keymap.set("n","<leader>rp","<cmd>lua require('grug-far').open()<CR>",{["silent"]=true,["desc"]="project"})
vim.keymap.set("n","<leader>rw","<cmd> lua require('grug-far').open({ prefills = { paths = vim.fn.expand(\"%:p\"), search = vim.fn.expand(\"<cword>\") } })<CR>",{["silent"]=true,["desc"]="word in buffer"})
vim.keymap.set("n","<leader>rW","<cmd> lua require('grug-far').open({ prefills = { search = vim.fn.expand(\"<cword>\") } })<CR>",{["silent"]=true,["desc"]="word in project"})
vim.keymap.set("n","<leader>sp","<cmd>lua require('telescope.builtin').live_grep({ additional_args = { '--fixed-strings' }})<CR>",{["silent"]=true,["desc"]="project"})
vim.keymap.set("n","<leader>sP","<cmd>Telescope live_grep<CR>",{["silent"]=true,["desc"]="project regex"})
vim.keymap.set("n","<leader>ss","<cmd>Telescope current_buffer_fuzzy_find<CR>",{["silent"]=true,["desc"]="buffer"})
vim.keymap.set("n","<leader>sS","<cmd>lua require(\"telescope.builtin\").live_grep({search_dirs={vim.fn.expand(\"%:p\")}})<CR>",{["silent"]=true,["desc"]="buffer regex"})
vim.keymap.set("n","<leader>st","<cmd>Telescope current_buffer_tags<CR>",{["silent"]=true,["desc"]="buffer tags"})
vim.keymap.set("n","<leader>sT","<cmd>Telescope tags<CR>",{["silent"]=true,["desc"]="project tags"})
vim.keymap.set("n","<leader>tf","<cmd>lua require(\"neotest\").run.run(vim.fn.expand(\"%\"))<CR>",{["silent"]=true,["desc"]="file"})
vim.keymap.set("n","<leader>tl","<cmd>lua require(\"neotest\").run.run_last()<CR>",{["silent"]=true,["desc"]="last"})
vim.keymap.set("n","<leader>tn","<cmd>lua require(\"neotest\").run.run()<CR>",{["silent"]=true,["desc"]="nearest"})
vim.keymap.set("n","<leader>to","<cmd>lua require(\"neotest\").output.open()<CR>",{["silent"]=true,["desc"]="output"})
vim.keymap.set("n","<leader>ts","<cmd>lua require(\"neotest\").summary.toggle()<CR>",{["silent"]=true,["desc"]="toggle summary"})
vim.keymap.set("n","<leader>Ts","<cmd>noh<CR>",{["silent"]=true,["desc"]="search highlight"})
vim.keymap.set("n","<leader>Tt","<cmd>Twilight<CR>",{["silent"]=true,["desc"]="twilight"})
vim.keymap.set("n","<leader>Tp","<cmd>Precognition toggle<CR>",{["silent"]=true,["desc"]="precognition"})
vim.keymap.set("n","<leader>wd","<C-W>c",{["silent"]=true,["desc"]="close"})
vim.keymap.set("n","<leader>we","<C-W>k",{["silent"]=true,["desc"]="up"})
vim.keymap.set("n","<leader>wE","<cmd>resize -5<CR>",{["silent"]=true,["desc"]="expand up"})
vim.keymap.set("n","<leader>wh","<C-W>h",{["silent"]=true,["desc"]="left"})
vim.keymap.set("n","<leader>wH","<C-W>5<",{["silent"]=true,["desc"]="expand left"})
vim.keymap.set("n","<leader>wi","<C-W>l",{["silent"]=true,["desc"]="right"})
vim.keymap.set("n","<leader>wI","<C-W>5>",{["silent"]=true,["desc"]="expand right"})
vim.keymap.set("n","<leader>wn","<C-W>j",{["silent"]=true,["desc"]="down"})
vim.keymap.set("n","<leader>wN","<cmd>resize +5<CR>",{["silent"]=true,["desc"]="expand down"})
vim.keymap.set("n","<leader>wo","<cmd>only<CR>",{["silent"]=true,["desc"]="close others"})
vim.keymap.set("n","<leader>wr","<C-W>r",{["silent"]=true,["desc"]="rotate"})
vim.keymap.set("n","<leader>ws","<C-W>s<C-W>j",{["silent"]=true,["desc"]="split down"})
vim.keymap.set("n","<leader>wv","<C-W>v<C-W>l",{["silent"]=true,["desc"]="split right"})
vim.keymap.set("n","<leader>w=","<C-W>=",{["silent"]=true,["desc"]="balance"})
vim.keymap.set("n","<leader>xd","<cmd>%s/\\s\\+$//e<CR>",{["silent"]=true,["desc"]="delete trailing whitespace"})
vim.keymap.set("n","<localleader>ca","<cmd>lua vim.lsp.buf.code_action()<CR>",{["silent"]=true,["desc"]="code action"})
vim.keymap.set("n","<localleader>cd","<cmd>lua vim.diagnostic.open_float()<CR>",{["silent"]=true,["desc"]="diagnostics"})
vim.keymap.set("n","<localleader>cn","<cmd>Navbuddy<CR>",{["silent"]=true,["desc"]="navigate"})
vim.keymap.set("n","<localleader>ceb","<cmd>Refactor extract_block<CR>",{["silent"]=true,["desc"]="block"})
vim.keymap.set("n","<localleader>ceB","<cmd>Refactor extract_block_to_file<CR>",{["silent"]=true,["desc"]="block to file"})
vim.keymap.set("n","<localleader>cef",":Refactor extract ",{["silent"]=true,["desc"]="function"})
vim.keymap.set("n","<localleader>ceF",":Refactor extract_to_file ",{["silent"]=true,["desc"]="function to file"})
vim.keymap.set("n","<localleader>cev",":Refactor extract_var ",{["silent"]=true,["desc"]="variable"})
vim.keymap.set("n","<localleader>civ","<cmd>Refactor inline_var<CR>",{["silent"]=true,["desc"]="variable"})
vim.keymap.set("n","<localleader>cif","<cmd>Refactor inline_func<CR>",{["silent"]=true,["desc"]="function"})

-- Debugging commands complement the source's DAP plugins.
vim.keymap.set('n','<leader>td',function() require('dap').continue() end,{desc='Debug / continue'})
vim.keymap.set('n','<leader>tb',function() require('dap').toggle_breakpoint() end,{desc='Breakpoint'})
vim.keymap.set('n','<leader>tu',function() require('dapui').toggle() end,{desc='Debug UI'})
vim.keymap.set('n','<leader>xf',function() require('conform').format({lsp_format='fallback'}) end,{desc='Format'})
if not colemak then
  for key,dir in pairs({h='h',j='j',k='k',l='l'}) do vim.keymap.set('n','<leader>w'..key,'<C-w>'..dir) end
end
WORK_VDI_FILE_END
backup "$config_root/work-emacs/init.el" "init.el"
cat > "$config_root/work-emacs/init.el" <<'WORK_VDI_FILE_END'
;;; init.el --- Full work editor export -*- lexical-binding: t; -*-
;; Generated from the repository's coding modules. See FEATURES.md.
(require 'cl-lib)
(defun work/setup-tool-path ()
(let* ((tools (expand-file-name "work-vdi/tools/" (or (getenv "XDG_DATA_HOME") "~/.local/share/")))
       (paths (list (expand-file-name "bin" tools) (expand-file-name "python/bin" tools)
                    (expand-file-name "~/.local/bin"))))
  (setq exec-path (append paths exec-path))
  (setenv "PATH" (mapconcat #'identity (append paths (list (or (getenv "PATH") ""))) path-separator))
  (when (file-directory-p (expand-file-name "lib/node_modules" tools))
    (setenv "npm_config_prefix" tools))))
(work/setup-tool-path)
(require 'seq)
(require 'package)
(setq package-archives '(("gnu" . "https://elpa.gnu.org/packages/")
                         ("nongnu" . "https://elpa.nongnu.org/nongnu/")
                         ("melpa" . "https://melpa.org/packages/")))
(package-initialize)
(setq vterm-always-compile-module t)
(defvar work/colemak t "Use the source configuration's Colemak keys; nil for QWERTY.")
(defvar work/module-errors nil)
(defvar work/npm-root
  (when (executable-find "npm")
    (with-temp-buffer
      (when (eq 0 (call-process "npm" nil t nil "root" "-g"))
        (string-trim (buffer-string))))))
(defvar work/vue-package
  (when work/npm-root (expand-file-name "@vue/language-server" work/npm-root)))
(defvar work/packages '(adaptive-wrap add-node-modules-path alert apheleia atomic-chrome avy blamer browse-at-remote browser-gt cape consult consult-dir consult-flycheck consult-lsp consult-projectile consult-todo corfu corfu-terminal dape dashboard deadgrep diff-hl difftastic dimmer diredfl docker dockerfile-mode doom-modeline doom-themes editorconfig embark embark-consult emmet-mode emr envrc evil evil-collection evil-mc evil-nerd-commenter evil-numbers evil-surround evil-terminal-cursor-changer evil-textobj-tree-sitter exec-path-from-shell flycheck flycheck-posframe flycheck-projectile focus forge general git-link git-timemachine go-mode gptel graphql-mode haskell-mode helpful hide-mode-line highlight-indent-guides hl-todo jest json-mode just-mode k8s-mode lsp-java lsp-mode lsp-pyright lsp-sonarlint lsp-treemacs lsp-ui lua-mode magit magit-delta magit-todos marginalia markdown-mode nerd-icons nerd-icons-completion nerd-icons-corfu nerd-icons-dired nix-mode nix-ts-mode olivetti orderless persist php-mode popper prisma-mode projectile pulsar rainbow-delimiters rainbow-mode restclient smartparens sql-indent sqlformat sudo-edit symbol-overlay terraform-mode tramp-container transient treemacs treemacs-evil treemacs-magit treemacs-nerd-icons treesit-fold typescript-mode undo-fu-session verb vertico vertico-posframe vterm vterm-toggle vundo web-mode web-server websocket wgrep which-key with-editor yaml-mode yascroll yasnippet yasnippet-snippets))
(defvar work/claude-revision "994549008acdf179041e5482c8085c30cf68de72")
(let ((vendor (expand-file-name "vendor/claude-code-ide.el" user-emacs-directory)))
  (when (file-directory-p vendor) (add-to-list 'load-path vendor)))
(defun work/install-packages ()
  "Install the full work packages, the source Claude fork, and grammar support."
  (interactive)
  (package-refresh-contents)
  (dolist (pkg work/packages)
    (unless (package-installed-p pkg) (package-install pkg)))
  (let ((dir (expand-file-name "vendor/claude-code-ide.el" user-emacs-directory)))
    (unless (file-directory-p dir)
      (make-directory (file-name-directory dir) t)
      (unless (eq 0 (call-process "git" nil "*work-install*" t "clone"
                                  "https://github.com/Axiweave/claude-code-ide.el.git" dir))
        (error "Could not clone Claude coding package; see *work-install*")))
    (let ((default-directory dir))
      (unless (eq 0 (call-process "git" nil "*work-install*" t "checkout" work/claude-revision))
        (error "Could not select the source Claude revision"))))
  ;; Preserve the Emacs 31 compatibility patch from the Nix source.
  (let ((file (locate-library "jest-traversal")))
    (when file
      (setq file (concat (file-name-sans-extension file) ".el"))
      (when (file-exists-p file)
        (with-temp-buffer
          (insert-file-contents file)
          (goto-char (point-min))
          (while (search-forward "(c-int-to-char (aref text i))" nil t)
            (replace-match "(aref text i)" t t))
          (write-region (point-min) (point-max) file nil 'silent))
        (byte-compile-file file))))
  (message "Work packages installed. Restart Emacs. Run M-x work/install-grammars for syntax grammars."))
(defun work/load-module (name packages text)
  "Load source module NAME if its (adaptive-wrap add-node-modules-path alert apheleia atomic-chrome avy blamer browse-at-remote browser-gt cape consult consult-dir consult-flycheck consult-lsp consult-projectile consult-todo corfu corfu-terminal dape dashboard deadgrep diff-hl difftastic dimmer diredfl docker dockerfile-mode doom-modeline doom-themes editorconfig embark embark-consult emmet-mode emr envrc evil evil-collection evil-mc evil-nerd-commenter evil-numbers evil-surround evil-terminal-cursor-changer evil-textobj-tree-sitter exec-path-from-shell flycheck flycheck-posframe flycheck-projectile focus forge general git-link git-timemachine go-mode gptel graphql-mode haskell-mode helpful hide-mode-line highlight-indent-guides hl-todo jest json-mode just-mode k8s-mode lsp-java lsp-mode lsp-pyright lsp-sonarlint lsp-treemacs lsp-ui lua-mode magit magit-delta magit-todos marginalia markdown-mode nerd-icons nerd-icons-completion nerd-icons-corfu nerd-icons-dired nix-mode nix-ts-mode olivetti orderless persist php-mode popper prisma-mode projectile pulsar rainbow-delimiters rainbow-mode restclient smartparens sql-indent sqlformat sudo-edit symbol-overlay terraform-mode tramp-container transient treemacs treemacs-evil treemacs-magit treemacs-nerd-icons treesit-fold typescript-mode undo-fu-session verb vertico vertico-posframe vterm vterm-toggle vundo web-mode web-server websocket wgrep which-key with-editor yaml-mode yascroll yasnippet yasnippet-snippets) are installed; report failures."
  (if (or (getenv "WORK_VDI_BOOTSTRAP") (seq-some (lambda (p) (not (package-installed-p p))) packages))
      (push (cons name "Packages missing; run M-x work/install-packages") work/module-errors)
    (condition-case err
        (with-temp-buffer
          (insert ";;; -*- lexical-binding: t; -*-\n" text)
          (eval-buffer))
      (error (push (cons name (error-message-string err)) work/module-errors)))))
(defun work/doctor ()
  "Show work module startup failures and missing packages."
  (interactive)
  (with-output-to-temp-buffer "*Work setup*"
    (princ (format "Emacs %s\n" emacs-version))
    (dolist (tool '("java" "jdtls" "php" "composer" "intelephense" "lemminx" "pyright-langserver" "ruff" "black" "prettier" "blade-formatter" "work-format"))
      (princ (format "%s: %s\n" tool (or (executable-find tool) "MISSING"))))
    (dolist (entry (reverse work/module-errors))
      (princ (format "%s: %s\n" (car entry) (cdr entry))))))
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when work/colemak
(work/load-module "keybinds.nix" '()
  "(defconst my/colemak-swaps\n      '((\"n\" . \"j\") (\"e\" . \"k\") (\"i\" . \"l\"))\n      \"Key pairs the rotation exchanges everywhere.\nRead as a permutation, the nvim keymaps are three transpositions: n<->j, e<->k,\ni<->l. So hnei moves the cursor, j takes over search-next, k word-end, and l\ninsert.\")\n\n(defconst my/colemak-swaps-shifted\n      '((\"N\" . \"J\") (\"E\" . \"K\") (\"I\" . \"L\"))\n      \"Key pairs the rotation exchanges in the evil state maps only.\nThe shifted half of the permutation is a motion only in vim's own vocabulary:\nJ joins, K opens the manual, L jumps to the bottom of the screen, and moving\nthose onto the Colemak positions is the point. A plugin's capitals are not\nmotions at all -- they are mnemonics. mu4e is the clear case: `J' is\njump-to-maildir in every mu4e document and screencast there is, and rotating it\nonto `N' left `J' bound to nothing and the docs wrong. Same for `E' (compose an\nedit) landing on `K'. Lowercase still rotates in those maps, because there the\nkeys really are movement: `n' and `e' walk the header list.\")\n\n(defvar my/colemak-rotated-maps nil\n      \"Keymaps the rotation has already been applied to.\nExchanging a pair is its own inverse, so applying it twice would silently undo\nit. This registry is what makes the hooks below safe to fire repeatedly.\")\n\n(defun my/keymap-own-binding (map key)\n      \"Binding of KEY in MAP itself, ignoring MAP's parent.\n`lookup-key' follows parents, which for a derived mode would drag prog-mode's\nbindings down into the child map and rotate keys the mode never bound. Detaching\nthe parent for the length of one lookup keeps the rotation to bindings the map\nactually owns.\"\n      (let ((parent (keymap-parent map)))\n        (unwind-protect\n            (progn\n              (when parent (set-keymap-parent map nil))\n              (let ((def (lookup-key map (kbd key) t)))\n                (if (numberp def) nil def)))\n          (when parent (set-keymap-parent map parent)))))\n\n(defun my/colemak-rotate (map &optional pairs)\n      \"Exchange PAIRS in MAP, at most once, defaulting to `my/colemak-swaps'.\"\n      (when (and (keymapp map) (not (memq map my/colemak-rotated-maps)))\n        (push map my/colemak-rotated-maps)\n        (dolist (pair (or pairs my/colemak-swaps))\n          (let* ((a (car pair))\n                 (b (cdr pair))\n                 (ca (my/keymap-own-binding map a))\n                 (cb (my/keymap-own-binding map b)))\n            (unless (or (keymapp ca) (keymapp cb) (and (null ca) (null cb)))\n              (define-key map (kbd a) cb)\n              (define-key map (kbd b) ca))))))\n\n(defun my/colemak-rotate-all (map)\n      \"Rotate MAP and the evil auxiliary keymaps hanging off it.\nPlugins that bind through `evil-define-key' — which is every mode\n`evil-collection' touches — do not put their bindings in the mode map itself but\nin a per-state auxiliary keymap attached to it. Rotating only the mode map would\nleave magit, treemacs, dired and friends on qwerty. Insert and emacs state are\ndeliberately left alone: there, the letters are letters.\"\n      (when (keymapp map)\n        (my/colemak-rotate map)\n        (dolist (state '(normal visual motion operator))\n          (let ((aux (ignore-errors (evil-get-auxiliary-keymap map state))))\n            (when (keymapp aux)\n              (my/colemak-rotate aux))))))\n\n(defun my/colemak-rotate-thing (thing)\n      \"Rotate THING, either a keymap or a symbol naming one.\"\n      (cond\n       ((keymapp thing) (my/colemak-rotate-all thing))\n       ((and thing (symbolp thing) (boundp thing) (keymapp (symbol-value thing)))\n        (my/colemak-rotate-all (symbol-value thing)))))\n\n(defun my/colemak-rotate-collection (&rest args)\n      \"Rotate whatever `evil-collection' just finished setting up.\nRun from `evil-collection-setup-hook', which passes the mode and a list of keymap\nsymbols. Written to accept keymaps, symbols or any argument count so that an\nupstream signature change degrades to the major-mode backstop below instead of\nerroring on every single mode load. Note the keymapp test comes first: a keymap\nsatisfies `listp', so testing for a list first would iterate its entries.\"\n      (dolist (arg args)\n        (if (and (listp arg) (not (keymapp arg)))\n            (mapc #'my/colemak-rotate-thing arg)\n          (my/colemak-rotate-thing arg))))\n\n(add-hook 'evil-collection-setup-hook #'my/colemak-rotate-collection)\n\n(defun my/colemak-rotate-current-mode-maps ()\n      \"Rotate the current major mode's keymap.\nBackstop for modes `evil-collection' does not report — a plugin with its own\nevil bindings, or a mode that binds n/e/i directly.\"\n      (let ((sym (and (fboundp 'derived-mode-map-name)\n                      (derived-mode-map-name major-mode))))\n        (when (and sym (boundp sym))\n          (my/colemak-rotate-all (symbol-value sym))))\n      (my/colemak-rotate-all (current-local-map)))\n\n(add-hook 'after-change-major-mode-hook #'my/colemak-rotate-current-mode-maps)")
)

(work/load-module "plugins/vim/default.nix" '(atomic-chrome evil evil-collection evil-numbers evil-surround exec-path-from-shell general helpful undo-fu-session vundo which-key)
  "(setq gc-cons-threshold (* 512 1024 1024)\n          read-process-output-max (* 4 1024 1024))\n\n(add-hook 'emacs-startup-hook\n              (lambda ()\n                (setq gc-cons-threshold (* 64 1024 1024)\n                      gc-cons-percentage 0.2)))\n\n(eval-and-compile\n      (unless (ignore-errors\n                (make-directory user-emacs-directory t)\n                (file-writable-p user-emacs-directory))\n        (setq user-emacs-directory\n              (file-name-as-directory (make-temp-file \"emacs-build-\" t)))))\n\n(setq custom-file (expand-file-name \"custom.el\" user-emacs-directory))\n\n(when (file-exists-p custom-file)\n      (load custom-file :noerror :nomessage))\n\n(require 'exec-path-from-shell)\n\n(setq exec-path-from-shell-arguments '(\"-l\")\n          exec-path-from-shell-variables\n          '(\"PATH\" \"MANPATH\" \"LANG\" \"LC_ALL\" \"SSH_AUTH_SOCK\"))\n\n(when (memq window-system '(mac ns x pgtk)) (exec-path-from-shell-initialize) (work/setup-tool-path))\n\n(setq evil-want-keybinding nil\n          evil-want-integration t\n          evil-want-C-u-scroll t\n          evil-want-Y-yank-to-eol t\n          evil-want-fine-undo t\n          evil-undo-system 'undo-redo\n          evil-search-module 'evil-search\n          evil-ex-search-vim-style-regexp t\n          evil-symbol-word-search t\n          evil-respect-visual-line-mode t\n          evil-split-window-below t\n          evil-vsplit-window-right t)\n\n(require 'evil)\n\n(evil-mode 1)\n\n(require 'evil-collection)\n\n(evil-collection-init)\n\n(require 'evil-surround)\n\n(global-evil-surround-mode 1)\n\n(require 'evil-numbers)\n\n(require 'general)\n\n(general-evil-setup)\n\n(general-override-mode 1)\n\n(general-create-definer my/leader\n      :states '(normal visual motion)\n      :keymaps 'override\n      :prefix \"SPC\"\n      :global-prefix \"M-SPC\")\n\n(general-create-definer my/localleader\n      :states '(normal visual motion)\n      :keymaps 'override\n      :prefix \",\"\n      :global-prefix \"M-,\")\n\n(require 'which-key)\n\n(setq which-key-idle-delay 0.5\n          which-key-idle-secondary-delay 0.05\n          which-key-prefix-prefix \"+\"\n          which-key-separator \" ➜ \"\n          which-key-side-window-max-height 0.45\n          which-key-add-column-padding 3\n          which-key-min-column-description-width 20\n          which-key-max-description-length 50\n          which-key-show-remaining-keys t\n          which-key-sort-order 'which-key-key-order-alpha\n          which-key-allow-evil-operators t)\n\n(which-key-mode 1)\n\n(setq desktop-path (list user-emacs-directory)\n          desktop-load-locked-desktop t\n          desktop-restore-eager 10\n          desktop-save t\n          desktop-restore-frames nil\n          desktop-restore-eager 10\n          recentf-max-saved-items 200\n          history-length 500)\n\n(require 'midnight)\n\n(setq clean-buffer-list-delay-general 1\n          clean-buffer-list-delay-special 3600\n          midnight-period 3600)\n\n(setq clean-buffer-list-kill-never-regexps\n          (append clean-buffer-list-kill-never-regexps\n                  '(\"\\\\`\\\\*dashboard\\\\*\\\\'\"\n                    \"\\\\`\\\\*scratch\\\\*\\\\'\"\n                    \"\\\\`\\\\*Messages\\\\*\\\\'\"\n                    \"\\\\`\\\\*telega\"\n                    \"\\\\`\\\\*mu4e\"\n                    \"\\\\`magit\")))\n\n(midnight-mode 1)\n\n(defun my/clean-buffers ()\n      \"Kill buffers untouched for a day, now rather than on the hour.\"\n      (interactive)\n      (let ((before (length (buffer-list))))\n        (clean-buffer-list)\n        (message \"Buffers: %d -> %d\" before (length (buffer-list)))))\n\n(desktop-save-mode 1)\n\n(savehist-mode 1)\n\n(save-place-mode 1)\n\n(recentf-mode 1)\n\n(defvar my/window-state-file\n      (expand-file-name \"window-state.el\" user-emacs-directory)\n      \"Where the last frame's pane layout is written.\")\n\n(defvar my/window-state-restored nil\n      \"Non-nil once a layout has been replayed in this daemon's lifetime.\")\n\n(defun my/window-state-worth-saving-p (frame)\n      \"Non-nil when FRAME's panes are worth replaying into the next frame.\n\nA layout earns that by having a file open in it. Without this rule the\nlast frame closed each day was usually a home screen -- *scratch*, or the\ndashboard, and the Claude sidebar beside it -- and that got written out\nas the layout to restore. The next frame then replayed it: an empty\nsidebar, *scratch* behind it, and the dashboard standing down because it\nhad been told a real layout was restored. Every frame after that\ninherited the same nothing, which is what \\\"nothing renders, just panes\\\"\nwas.\"\n      (seq-some (lambda (w)\n                  (and (not (window-parameter w 'window-side))\n                       (buffer-file-name (window-buffer w))))\n                (window-list frame)))\n\n(defun my/save-window-state (&optional frame)\n      \"Write FRAME's pane layout for the next session.\nHung on frame deletion rather than only on `kill-emacs-hook': the daemon\nusually outlives every frame, so by the time Emacs is actually exiting\nthere is no layout left to record.\n\nThe main window tree, not the root window: side windows -- the Claude\nsidebar, the which-key panel, the bottom terminal -- are drawn by the\nhooks that own them on every frame, and a layout that carried its own\ncopy restored a stale one for those hooks to duplicate.\n\nA layout with no work in it deletes the saved one rather than replacing\nit. Keeping the older file would mean replaying a layout from a session\nwhose buffers may be long gone; the honest default with nothing to\nrestore is the home screen.\"\n      (let ((frame (or frame (selected-frame))))\n        (when (and (frame-live-p frame) (display-graphic-p frame))\n          (condition-case nil\n              (if (not (my/window-state-worth-saving-p frame))\n                  (when (file-exists-p my/window-state-file)\n                    (delete-file my/window-state-file))\n                (let ((state (window-state-get (window-main-window frame) t)))\n                  (with-temp-file my/window-state-file\n                    (prin1 state (current-buffer)))))\n            (error nil)))))\n\n(defun my/restore-window-state (&optional frame)\n      \"Replay the saved layout into FRAME.\n\nOnce per daemon lifetime, and only into a frame that has nothing of its\nown to show: `emacsclient -c somefile' must land on that file, and the\nsecond frame of the day should not have the first frame's panes forced\nonto it.\n\nRuns at depth -90 so it precedes the dashboard's own new-frame hook,\nwhich calls `delete-other-windows' and would flatten the layout. After a\nsuccessful replay the selected buffer is one of the restored ones, so\nthat hook's *scratch*/*dashboard* guard declines on its own.\"\n      (let ((frame (or frame (selected-frame))))\n        (when (and (not my/window-state-restored)\n                   (frame-live-p frame)\n                   (display-graphic-p frame)\n                   (= 1 (length (window-list frame)))\n                   (not (buffer-file-name\n                         (window-buffer (frame-selected-window frame))))\n                   (file-readable-p my/window-state-file))\n          (setq my/window-state-restored t)\n          (when (bound-and-true-p desktop-buffer-args-list)\n            (ignore-errors (desktop-lazy-complete)))\n          (condition-case err\n              (let ((state (with-temp-buffer\n                             (insert-file-contents my/window-state-file)\n                             (read (current-buffer)))))\n                (window-state-put state (window-main-window frame) 'safe)\n                (let ((w (frame-selected-window frame)))\n                  (when (window-live-p w) (select-window w t)))\n                (set-frame-parameter frame 'my/window-state-replayed t))\n            (error (message \"Saved layout not restored: %S\" err))))))\n\n(defun my/forget-window-state ()\n      \"Discard the saved layout, so the next frame opens on the dashboard.\"\n      (interactive)\n      (when (file-exists-p my/window-state-file)\n        (delete-file my/window-state-file))\n      (setq my/window-state-restored t)\n      (message \"Saved layout discarded.\"))\n\n(add-hook 'delete-frame-functions #'my/save-window-state)\n\n(add-hook 'kill-emacs-hook #'my/save-window-state)\n\n(add-hook 'server-after-make-frame-hook #'my/restore-window-state -90)\n\n(setq undo-fu-session-directory (expand-file-name \"undo/\" user-emacs-directory))\n\n(require 'undo-fu-session)\n\n(undo-fu-session-global-mode 1)\n\n(require 'atomic-chrome)\n\n(setq atomic-chrome-buffer-open-style 'frame\n          atomic-chrome-default-major-mode 'gfm-mode\n          atomic-chrome-url-major-mode-alist\n          '((\"github\\\\.com\" . gfm-mode)\n            (\"gitlab\\\\.com\" . gfm-mode)))\n\n(atomic-chrome-start-server)")

(work/load-module "options.nix" '(adaptive-wrap evil-terminal-cursor-changer)
  "(set-language-environment \"UTF-8\")\n\n(prefer-coding-system 'utf-8)\n\n(setq default-buffer-file-coding-system 'utf-8-unix)\n\n(setq display-line-numbers-type 'relative\n      display-line-numbers-current-absolute t\n      display-line-numbers-width 3)\n\n(global-display-line-numbers-mode 1)\n\n(defun my/line-numbers-wanted-p ()\n  \"Non-nil when this buffer is one the line-number gutter is for.\nTerminals are named rather than derived: a vterm is neither read-only nor a\n`special-mode' buffer -- it is a live editable field that happens to be\nfull of someone else's output.\"\n  (and (not (minibufferp))\n       (not buffer-read-only)\n       (not (derived-mode-p 'special-mode))\n       (not (derived-mode-p 'comint-mode))\n       (not (memq major-mode '(vterm-mode term-mode eat-mode eshell-mode)))))\n\n(define-advice global-display-line-numbers-mode-enable-in-buffer\n    (:before-while (&rest _) my/only-where-editable)\n  \"Leave the gutter off in buffers there is nothing to edit in.\"\n  (my/line-numbers-wanted-p))\n\n(defun my/line-numbers-reconcile ()\n  \"Turn the gutter off if this buffer turned out not to want one.\"\n  (unless (my/line-numbers-wanted-p)\n    (display-line-numbers-mode -1)))\n\n(add-hook 'find-file-hook #'my/line-numbers-reconcile)\n\n(setq echo-keystrokes 0)\n\n(setq resize-mini-windows t)\n\n(setq-default left-fringe-width 12\n              right-fringe-width 4\n              indicate-empty-lines nil)\n\n(global-hl-line-mode 1)\n\n(setq idle-update-delay 0.3)\n\n(setq confirm-kill-processes t\n      confirm-nonexistent-file-or-buffer t)\n\n(setq-default truncate-lines t)\n\n(setq evil-ex-search-highlight-all t\n      evil-ex-substitute-highlight-all t\n      search-highlight t\n      isearch-lazy-highlight t)\n\n(setq case-fold-search t\n      evil-ex-search-case 'smart\n      evil-ex-substitute-case 'smart\n      completion-ignore-case t\n      read-file-name-completion-ignore-case t\n      read-buffer-completion-ignore-case t)\n\n(setq-default indent-tabs-mode nil\n              tab-width 2\n              standard-indent 2\n              evil-shift-width 2)\n\n(setq js-indent-level 2\n      typescript-ts-mode-indent-offset 2\n      json-ts-mode-indent-offset 2\n      css-indent-offset 2\n      sgml-basic-offset 2\n      sh-basic-offset 2\n      lua-indent-level 2\n      yaml-indent-offset 2\n      web-mode-markup-indent-offset 2\n      web-mode-css-indent-offset 2\n      web-mode-code-indent-offset 2\n      web-mode-attr-indent-offset 2)\n\n(setq frame-background-mode 'dark)\n\n(setq ring-bell-function #'ignore\n      visible-bell nil\n      use-short-answers t)\n\n(unless (display-graphic-p)\n  (xterm-mouse-mode 1))\n\n(add-hook 'before-save-hook #'delete-trailing-whitespace)\n\n(let ((backups (expand-file-name \"backup/\" user-emacs-directory))\n      (saves   (expand-file-name \"swap/\" user-emacs-directory)))\n  (make-directory backups t)\n  (make-directory saves t)\n  (setq backup-directory-alist `((\".*\" . ,backups))\n        auto-save-file-name-transforms `((\".*\" ,saves t))\n        auto-save-list-file-prefix (expand-file-name \"swap/.saves-\" user-emacs-directory)\n        backup-by-copying t\n        delete-old-versions t\n        kept-new-versions 6\n        kept-old-versions 2\n        version-control t\n        create-lockfiles nil))\n\n(setq evil-normal-state-cursor  '(box)\n      evil-insert-state-cursor  '(bar . 2)\n      evil-replace-state-cursor '(hbar . 2)\n      evil-visual-state-cursor  '(hollow)\n      evil-emacs-state-cursor   '(bar . 4))\n\n(unless (display-graphic-p)\n  (require 'evil-terminal-cursor-changer)\n  (evil-terminal-cursor-changer-activate))\n\n(setq select-enable-clipboard t\n      select-enable-primary nil\n      save-interprogram-paste-before-kill t)")

(work/load-module "colorscheme.nix" '(dimmer doom-themes)
  "(defconst my/tokyonight\n      '((bg       . \"#24283b\")\n        (bg-dark  . \"#1f2335\")\n        (bg-hl    . \"#292e42\")\n        (prompt   . \"#2d3149\")\n        (fg       . \"#c0caf5\")\n        (fg-dark  . \"#a9b1d6\")\n        (comment  . \"#565f89\")\n        (blue     . \"#7aa2f7\")\n        (cyan     . \"#7dcfff\")\n        (green    . \"#9ece6a\")\n        (magenta  . \"#bb9af7\")\n        (orange   . \"#ff9e64\")\n        (violet   . \"#9d7cd8\")\n        (red      . \"#f7768e\")\n        (yellow   . \"#e0af68\")\n        (diff-add    . \"#20303b\")\n        (diff-del    . \"#37222c\")\n        (diff-add-hl . \"#326673\")\n        (diff-del-hl . \"#643740\"))\n      \"tokyonight storm, as used by the nvim config and the modeline.\")\n\n(defun my/tn (key)\n      \"Hex string for KEY in `my/tokyonight'.\"\n      (alist-get key my/tokyonight))\n\n(require 'doom-themes)\n\n(setq doom-themes-enable-bold t\n          doom-themes-enable-italic t\n          doom-themes-treemacs-theme \"doom-colors\")\n\n(load-theme 'doom-tokyo-night :no-confirm)\n\n(dolist (f '(gnus-group-news-low gnus-group-news-low-empty))\n      (custom-theme-reset-faces 'doom-tokyo-night (list f nil))\n      (when (facep f)\n        (set-face-attribute f nil :inherit 'unspecified)))\n\n(custom-set-faces\n     `(default        ((t (:background ,(my/tn 'bg) :foreground ,(my/tn 'fg)))))\n     `(hl-line        ((t (:background ,(my/tn 'bg-hl)))))\n     `(region         ((t (:background ,(my/tn 'bg-hl)))))\n     `(vertical-border ((t (:foreground ,(my/tn 'bg-dark) :background ,(my/tn 'bg-dark)))))\n     `(font-lock-comment-face ((t (:foreground ,(my/tn 'comment) :slant italic))))\n     `(font-lock-keyword-face ((t (:slant italic :weight bold)))))\n\n(custom-set-faces\n     `(child-frame-border ((t (:background ,(my/tn 'bg-dark)))))\n     `(tooltip            ((t (:background ,(my/tn 'bg-dark) :foreground ,(my/tn 'fg-dark)))))\n     `(vertico-posframe        ((t (:background ,(my/tn 'bg-dark) :foreground ,(my/tn 'fg-dark)))))\n     `(vertico-posframe-border ((t (:background ,(my/tn 'bg-dark)))))\n     `(corfu-default      ((t (:background ,(my/tn 'bg-dark) :foreground ,(my/tn 'fg-dark)))))\n     `(corfu-border       ((t (:background ,(my/tn 'bg-dark)))))\n     `(corfu-current      ((t (:background ,(my/tn 'prompt) :foreground ,(my/tn 'fg)))))\n     `(treemacs-window-background-face ((t (:background ,(my/tn 'bg-dark)))))\n     `(lsp-ui-doc-background ((t (:background ,(my/tn 'bg-dark))))))\n\n(defun my/apply-transparency (&optional frame)\n      \"Mirror the nvim `transparent = true' background for FRAME.\nTerminal frames drop their background entirely, so the translucent iTerm2 or\nAlacritty window shows through exactly as it does under nvim. GUI frames only get\nreal background transparency on pgtk/X, where `alpha-background' exists — the\nmacOS NS port ignores it, and plain `alpha' would fade the text too, so a GUI\nframe there keeps the solid storm background instead.\n\nEach `set-face-background' passes FRAME explicitly. Without it the change is\nglobal, not frame-local -- `with-selected-frame' does not scope face changes,\nand setting the default face with no frame also rewrites background-color in\n`default-frame-alist'. Under `emacs --fg-daemon' the initial frame F1 is a\nterminal frame, so this ran at startup and left every face, and the alist\nevery future frame is built from, holding \\\"unspecified-bg\\\" -- a value that\nonly means anything on a terminal. Creating a GUI frame then died with\n(error \\\"Unknown color\\\"), so `emacsclient -c' could never open a window and\nthe daemon was unusable for GUI work.\"\n      (let ((frame (or frame (selected-frame))))\n        (if (memq (framep frame) '(pgtk x))\n            (set-frame-parameter frame 'alpha-background 90)\n          (unless (display-graphic-p frame)\n            (set-face-background 'default \"unspecified-bg\" frame)\n            (set-face-background 'line-number \"unspecified-bg\" frame)\n            (set-face-background 'fringe \"unspecified-bg\" frame)))))\n\n(add-to-list 'default-frame-alist '(alpha-background . 90))\n\n(add-hook 'after-make-frame-functions #'my/apply-transparency)\n\n(add-hook 'server-after-make-frame-hook #'my/apply-transparency)\n\n(my/apply-transparency)\n\n(require 'dimmer)\n\n(setq dimmer-fraction 0.25\n          dimmer-adjustment-mode :foreground\n          dimmer-use-colorspace :rgb\n          dimmer-watch-frame-focus-events nil)\n\n(dimmer-configure-which-key)\n\n(dimmer-configure-magit)\n\n(dimmer-mode 1)")

(work/load-module "plugins/code/comments.nix" '(consult-todo evil-nerd-commenter hl-todo magit-todos)
  "(require 'evil-nerd-commenter)\n\n(evil-define-key '(normal visual) 'global\n  \"gc\" #'evilnc-comment-operator\n  \"gy\" #'evilnc-copy-and-comment-operator)\n\n(require 'hl-todo)\n\n(setq hl-todo-keyword-faces\n      '((\"TODO\"  . \"#e0af68\")\n        (\"FIXME\" . \"#f7768e\")\n        (\"BUG\"   . \"#f7768e\")\n        (\"HACK\"  . \"#ff9e64\")\n        (\"WARN\"  . \"#ff9e64\")\n        (\"WARNING\" . \"#ff9e64\")\n        (\"PERF\"  . \"#9d7cd8\")\n        (\"NOTE\"  . \"#7dcfff\")\n        (\"TEST\"  . \"#9ece6a\")\n        (\"XXX\"   . \"#f7768e\")))\n\n(global-hl-todo-mode 1)\n\n(require 'consult-todo)\n\n(with-eval-after-load 'magit\n  (require 'magit-todos)\n  (setq magit-todos-exclude-globs '(\"*.map\" \"node_modules/*\" \".git/*\"))\n  (magit-todos-mode 1))\n\n(defun my/todos-project ()\n  \"Every TODO in the project — TodoTelescope.\"\n  (interactive)\n  (if (fboundp 'consult-todo-project)\n      (consult-todo-project)\n    (consult-todo)))")

(work/load-module "plugins/code/languages.nix" '(add-node-modules-path editorconfig emmet-mode graphql-mode haskell-mode nix-ts-mode typescript-mode web-mode)
  "(dolist (pair '((js-mode          . js-ts-mode)\n                (javascript-mode  . js-ts-mode)\n                (js-json-mode     . json-ts-mode)\n                (json-mode        . json-ts-mode)\n                (typescript-mode  . typescript-ts-mode)\n                (css-mode         . css-ts-mode)\n                (yaml-mode        . yaml-ts-mode)\n                (sh-mode          . bash-ts-mode)\n                (python-mode      . python-ts-mode)\n                (go-mode          . go-ts-mode)\n                (lua-mode         . lua-ts-mode)\n                (conf-toml-mode   . toml-ts-mode)))\n  (add-to-list 'major-mode-remap-alist pair))\n\n(dolist (entry '((\"\\\\.tsx\\\\'\"        . tsx-ts-mode)\n                 (\"\\\\.jsx\\\\'\"        . tsx-ts-mode)\n                 (\"\\\\.mts\\\\'\"        . typescript-ts-mode)\n                 (\"\\\\.cts\\\\'\"        . typescript-ts-mode)\n                 (\"\\\\.mjs\\\\'\"        . js-ts-mode)\n                 (\"\\\\.cjs\\\\'\"        . js-ts-mode)\n                 (\"\\\\.vue\\\\'\"        . web-mode)\n                 (\"\\\\.svelte\\\\'\"     . web-mode)\n                 (\"\\\\.astro\\\\'\"      . web-mode)\n                 (\"\\\\.html?\\\\'\"      . web-mode)\n                 (\"\\\\.s[ac]ss\\\\'\"    . scss-mode)\n                 (\"\\\\.nix\\\\'\"        . nix-ts-mode)\n                 (\"\\\\.graphqls?\\\\'\"  . graphql-mode)\n                 (\"\\\\.gql\\\\'\"        . graphql-mode)))\n  (add-to-list 'auto-mode-alist entry))\n\n(setq web-mode-enable-auto-closing t\n      web-mode-enable-auto-pairing t\n      web-mode-enable-auto-quoting nil\n      web-mode-enable-css-colorization t\n      web-mode-enable-current-element-highlight t\n      web-mode-enable-auto-indentation nil\n      web-mode-script-padding 0\n      web-mode-style-padding 0\n      web-mode-block-padding 0)\n\n(require 'emmet-mode)\n\n(setq emmet-move-cursor-between-quotes t\n      emmet-self-closing-tag-style \"\"\n      emmet-expand-jsx-className? t)\n\n(dolist (hook '(web-mode-hook html-mode-hook mhtml-mode-hook css-ts-mode-hook\n                scss-mode-hook tsx-ts-mode-hook js-ts-mode-hook))\n  (add-hook hook #'emmet-mode))\n\n(require 'add-node-modules-path)\n\n(setq add-node-modules-path-command '(\"echo \\\"$(npm root)/.bin\\\"\"))\n\n(dolist (hook '(js-ts-mode-hook typescript-ts-mode-hook tsx-ts-mode-hook\n                web-mode-hook json-ts-mode-hook))\n  (add-hook hook #'add-node-modules-path))\n\n(require 'editorconfig)\n\n(editorconfig-mode 1)\n\n(with-eval-after-load 'editorconfig\n  (add-to-list 'editorconfig-exclude-regexps \"\\\\`/[^/|:]+[|:]\"))\n\n(setq lsp-yaml-schema-store-enable t\n      lsp-yaml-schema-store-uri \"https://www.schemastore.org/api/json/catalog.json\"\n      lsp-json-schemas nil)\n\n(require 'haskell-mode)")

(work/load-module "plugins/code/navigation.nix" '(avy pulsar symbol-overlay treesit-fold yascroll)
  "(require 'avy)\n\n(setq avy-keys '(?a ?r ?s ?t ?d ?h ?n ?e ?i ?o)\n      avy-all-windows nil\n      avy-all-windows-alt t\n      avy-timeout-seconds 0.4\n      avy-style 'at-full)\n\n(defalias 'my/jump-char        #'avy-goto-char)\n\n(defalias 'my/jump-char-2      #'avy-goto-char-2)\n\n(defalias 'my/jump-word        #'avy-goto-word-0)\n\n(defalias 'my/jump-word-above  #'avy-goto-word-0-above)\n\n(defalias 'my/jump-word-below  #'avy-goto-word-0-below)\n\n(defalias 'my/jump-line        #'avy-goto-line)\n\n(require 'symbol-overlay)\n\n(setq symbol-overlay-idle-time 0.2)\n\n(add-hook 'prog-mode-hook #'symbol-overlay-mode)\n\n(add-hook 'lsp-mode-hook (lambda () (symbol-overlay-mode -1)))\n\n(require 'treesit-fold)\n\n(require 'treesit-fold-indicators)\n\n(setq treesit-fold-line-count-show t\n      treesit-fold-line-count-format \" ⋯ %d lines \")\n\n(global-treesit-fold-mode 1)\n\n(global-treesit-fold-indicators-mode 1)\n\n(defun my/treesit-fold-indicators-unhook (&rest _)\n  \"Take the eager window hooks back off; the idle timer covers them.\"\n  (remove-hook 'window-scroll-functions #'treesit-fold-indicators--scroll)\n  (remove-hook 'window-size-change-functions\n               #'treesit-fold-indicators--size-change))\n\n(advice-add 'treesit-fold-indicators--enable :after\n            #'my/treesit-fold-indicators-unhook)\n\n(my/treesit-fold-indicators-unhook)\n\n(defun my/treesit-fold-indicators-idle ()\n  \"Refresh the fold markers in the selected window, once things are still.\"\n  (when (bound-and-true-p treesit-fold-indicators-mode)\n    (ignore-errors\n      (treesit-fold-indicators--render-window (selected-window)))))\n\n(run-with-idle-timer 0.25 t #'my/treesit-fold-indicators-idle)\n\n(evil-define-key 'normal 'global\n  (kbd \"za\") #'treesit-fold-toggle\n  (kbd \"zc\") #'treesit-fold-close\n  (kbd \"zo\") #'treesit-fold-open\n  (kbd \"zM\") #'treesit-fold-close-all\n  (kbd \"zR\") #'treesit-fold-open-all)\n\n(require 'yascroll)\n\n(setq yascroll:delay-to-hide 1.0)\n\n(require 'pulsar)\n\n(setq pulsar-face 'pulsar-cyan\n      pulsar-delay 0.05\n      pulsar-iterations 8)\n\n(dolist (fn '(evil-scroll-line-down evil-scroll-line-up\n              evil-scroll-down evil-scroll-up\n              evil-window-up evil-window-down\n              evil-window-left evil-window-right\n              avy-goto-char avy-goto-char-2 avy-goto-line avy-goto-word-0\n              lsp-find-definition lsp-find-references xref-find-definitions\n              treesit-fold-open recenter-top-bottom))\n  (add-to-list 'pulsar-pulse-functions fn))\n\n(pulsar-global-mode 1)\n\n(defun my/symbol-outline ()\n  \"Outline of the symbols in this buffer — the Navbuddy reflex.\"\n  (interactive)\n  (if (bound-and-true-p lsp-mode)\n      (lsp-treemacs-symbols)\n    (consult-imenu)))")

(work/load-module "plugins/code/syntax.nix" '(evil-textobj-tree-sitter)
  "(require 'treesit)\n\n(setq treesit-font-lock-level 4)\n\n(require 'evil-textobj-tree-sitter)\n\n(define-key evil-outer-text-objects-map \"a\"\n            (evil-textobj-tree-sitter-get-textobj \"parameter.outer\"))\n\n(define-key evil-inner-text-objects-map \"a\"\n            (evil-textobj-tree-sitter-get-textobj \"parameter.inner\"))\n\n(define-key evil-outer-text-objects-map \"f\"\n            (evil-textobj-tree-sitter-get-textobj \"function.outer\"))\n\n(define-key evil-inner-text-objects-map \"f\"\n            (evil-textobj-tree-sitter-get-textobj \"function.inner\"))\n\n(define-key evil-outer-text-objects-map \"c\"\n            (evil-textobj-tree-sitter-get-textobj \"class.outer\"))\n\n(define-key evil-inner-text-objects-map \"c\"\n            (evil-textobj-tree-sitter-get-textobj \"class.inner\"))\n\n(define-key evil-outer-text-objects-map \"i\"\n            (evil-textobj-tree-sitter-get-textobj \"conditional.outer\"))\n\n(define-key evil-inner-text-objects-map \"i\"\n            (evil-textobj-tree-sitter-get-textobj \"conditional.inner\"))\n\n(define-key evil-outer-text-objects-map \"l\"\n            (evil-textobj-tree-sitter-get-textobj \"loop.outer\"))\n\n(define-key evil-inner-text-objects-map \"l\"\n            (evil-textobj-tree-sitter-get-textobj \"loop.inner\"))\n\n(define-key evil-outer-text-objects-map \"t\"\n            (evil-textobj-tree-sitter-get-textobj \"comment.outer\"))\n\n(evil-define-key '(normal visual) 'global\n  (kbd \"]m\") (lambda () (interactive)\n               (evil-textobj-tree-sitter-goto-textobj \"function.outer\"))\n  (kbd \"[m\") (lambda () (interactive)\n               (evil-textobj-tree-sitter-goto-textobj \"function.outer\" t))\n  (kbd \"]M\") (lambda () (interactive)\n               (evil-textobj-tree-sitter-goto-textobj \"function.outer\" nil t))\n  (kbd \"[M\") (lambda () (interactive)\n               (evil-textobj-tree-sitter-goto-textobj \"function.outer\" t t))\n  (kbd \"]]\") (lambda () (interactive)\n               (evil-textobj-tree-sitter-goto-textobj \"class.outer\"))\n  (kbd \"[[\") (lambda () (interactive)\n               (evil-textobj-tree-sitter-goto-textobj \"class.outer\" t))\n  (kbd \"][\") (lambda () (interactive)\n               (evil-textobj-tree-sitter-goto-textobj \"class.outer\" nil t))\n  (kbd \"[]\") (lambda () (interactive)\n               (evil-textobj-tree-sitter-goto-textobj \"class.outer\" t t)))")

(work/load-module "plugins/code/test.nix" '(dape jest)
  "(require 'jest)\n\n(setq jest-pdb-track nil)\n\n(setq jest-unsaved-buffers-behavior 'save-all)\n\n(defun my/jest-vitest-project-p ()\n      \"Non-nil when the project in front of us runs vitest rather than jest.\"\n      (let ((pkg (expand-file-name \"package.json\"\n                                   (or (my/project-root) default-directory))))\n        (and (file-readable-p pkg)\n             (with-temp-buffer\n               (insert-file-contents pkg)\n               (goto-char (point-min))\n               (search-forward \"\\\"vitest\\\"\" nil t)\n               t))))\n\n(defconst my/jest-watch-switches '(\"--watch\" \"--watchAll\")\n      \"Popup switches that mean \\\"do not stop after one run\\\".\")\n\n(defun my/jest-executable (&optional args)\n      \"The command prefix this project's tests run under, given popup ARGS.\n\nThree cases rather than two, because vitest decides between running once\nand watching from its SUBCOMMAND and not from a flag:\n\n  npx vitest run     one pass, and the default here\n  npx vitest watch   the popup's `w' switch, held open\n  npx jest           everything the popup emits is jest's own\n\nPlain `npx vitest' is not one of them. jest.el runs its command through a\ncomint buffer, a comint buffer has a pty, and vitest watches whenever it\nfinds a tty — so `SPC t f' would have opened a run that never finishes.\n\nAnd `vitest run --watch' is not the watch: `run' wins, the flag is\nignored, and the popup's own switch silently did nothing at all. That is\nwhat the subcommand here is for.\"\n      (cond\n       ((not (my/jest-vitest-project-p)) \"npx jest\")\n       ((seq-intersection args my/jest-watch-switches #'string=) \"npx vitest watch\")\n       (t \"npx vitest run\")))\n\n(defvar jest-executable)\n\n(defun my/jest--with-project-runner (fn &rest args)\n      \"Call FN with `jest-executable' set to this project's runner.\"\n      (let ((jest-executable (my/jest-executable (plist-get args :args))))\n        (apply fn args)))\n\n(advice-add 'jest--run :around #'my/jest--with-project-runner)\n\n(defun my/jest--vitest-arguments (args)\n      \"Drop the switches vitest would refuse from ARGS.\"\n      (if (my/jest-vitest-project-p)\n          (remove \"--watchAll\" args)\n        args))\n\n(advice-add 'jest--transform-arguments\n                :filter-return #'my/jest--vitest-arguments)\n\n(require 'compile)\n\n(dolist (rule\n             '((jest-vitest\n                \"^[ \\t]*❯[ \\t]+\\\\(?:[^ \\t\\n]+[ \\t]+\\\\)*\\\\([^ \\t\\n:]+\\\\):\\\\([0-9]+\\\\):\\\\([0-9]+\\\\)$\"\n                1 2 3)\n               (jest-node-stack\n                \"^[ \\t]*at [^\\n]*(\\\\([^()\\n]+\\\\):\\\\([0-9]+\\\\):\\\\([0-9]+\\\\))$\"\n                1 2 3)))\n      (setf (alist-get (car rule) compilation-error-regexp-alist-alist) (cdr rule)))\n\n(defun my/jest-mode-error-patterns ()\n      \"Teach this run buffer where a JS test failure points.\"\n      (setq-local compilation-error-regexp-alist\n                  (append '(jest-vitest jest-node-stack)\n                          compilation-error-regexp-alist)))\n\n(add-hook 'jest-mode-hook #'my/jest-mode-error-patterns)\n\n(require 'dape)\n\n(setq dape-buffer-window-arrangement 'right\n          dape-inlay-hints t)\n\n(add-hook 'dape-compile-hook #'kill-buffer)")

(work/load-module "plugins/code/utils.nix" '(emr evil-mc rainbow-delimiters rainbow-mode restclient smartparens sudo-edit verb)
  "(require 'smartparens-config)\n\n(setq sp-highlight-pair-overlay nil\n      sp-highlight-wrap-overlay nil\n      sp-max-pair-length 4)\n\n(smartparens-global-mode 1)\n\n(show-paren-mode 1)\n\n(setq show-paren-delay 0\n      show-paren-style 'parenthesis\n      show-paren-when-point-inside-paren t)\n\n(require 'rainbow-delimiters)\n\n(add-hook 'prog-mode-hook #'rainbow-delimiters-mode)\n\n(require 'rainbow-mode)\n\n(dolist (hook '(css-ts-mode-hook scss-mode-hook web-mode-hook\n                html-mode-hook emacs-lisp-mode-hook conf-mode-hook\n                js-ts-mode-hook typescript-ts-mode-hook tsx-ts-mode-hook))\n  (add-hook hook #'rainbow-mode))\n\n(require 'evil-mc)\n\n(global-evil-mc-mode 1)\n\n(setq evil-mc-undo-cursors-on-keyboard-quit t)\n\n(defun my/add-cursors ()\n  \"Put a cursor on every match of the symbol at point — the MCstart reflex.\"\n  (interactive)\n  (if (evil-mc-has-cursors-p)\n      (evil-mc-undo-all-cursors)\n    (evil-mc-make-all-cursors)))\n\n(setq iedit-toggle-key-default nil)\n\n(require 'emr)\n\n(emr-initialize)\n\n(require 'restclient)\n\n(add-to-list 'auto-mode-alist '(\"\\\\.http\\\\'\" . restclient-mode))\n\n(with-eval-after-load 'org\n  (require 'verb)\n  (define-key org-mode-map (kbd \"C-c C-r\") verb-command-map))\n\n(require 'sudo-edit)")

(work/load-module "plugins/files/browsing.nix" '(consult consult-dir consult-projectile diredfl embark embark-consult marginalia nerd-icons-completion nerd-icons-dired orderless projectile vertico vertico-posframe)
  "(require 'vertico)\n\n(setq vertico-count 10\n      vertico-cycle t\n      vertico-resize nil)\n\n(vertico-mode 1)\n\n(when (require 'vertico-directory nil t)\n  (define-key vertico-map (kbd \"RET\")   #'vertico-directory-enter)\n  (define-key vertico-map (kbd \"DEL\")   #'vertico-directory-delete-char)\n  (define-key vertico-map (kbd \"M-DEL\") #'vertico-directory-delete-word)\n  (add-hook 'rfn-eshadow-update-overlay-hook #'vertico-directory-tidy))\n\n(when (display-graphic-p)\n  (setq vertico-posframe-poshandler #'posframe-poshandler-frame-center\n        vertico-posframe-border-width 2\n        vertico-posframe-width 120)\n  (vertico-posframe-mode 1))\n\n(require 'orderless)\n\n(setq completion-styles '(orderless basic)\n      completion-category-defaults nil\n      completion-category-overrides '((file (styles partial-completion))\n                                      (lsp-capf (styles orderless))))\n\n(require 'marginalia)\n\n(marginalia-mode 1)\n\n(nerd-icons-completion-mode 1)\n\n(require 'consult)\n\n(setq consult-narrow-key \"<\"\n      consult-preview-key 'any\n      consult-line-start-from-top nil\n      consult-ripgrep-args\n      (concat \"rg --null --line-buffered --color=never --max-columns=1000\"\n              \" --path-separator / --smart-case --no-heading --with-filename\"\n              \" --line-number --hidden --glob !.git/\")\n      consult-fd-args\n      (list (if (executable-find \"fdfind\" 'remote) \"fdfind\" \"fd\")\n            \"--full-path --color=never --hidden --exclude .git\"))\n\n(require 'embark)\n\n(require 'embark-consult)\n\n(setq prefix-help-command #'embark-prefix-help-command)\n\n(add-hook 'embark-collect-mode-hook #'consult-preview-at-point-mode)\n\n(global-set-key (kbd \"C-;\") #'embark-dwim)\n\n(define-key minibuffer-local-map (kbd \"C-.\") #'embark-act)\n\n(with-eval-after-load 'vertico\n  (define-key vertico-map (kbd \"C-.\") #'embark-act))\n\n(setq embark-quit-after-action '((kill-buffer . nil)\n                                 (embark-kill-buffer-and-window . nil)\n                                 (t . t)))\n\n(require 'projectile)\n\n(require 'consult-projectile)\n\n(setq projectile-project-search-path nil\n      projectile-enable-caching t\n      projectile-indexing-method 'alien\n      projectile-completion-system 'default)\n\n(projectile-mode 1)\n\n(defun my/project-root ()\n  \"Project root for the current buffer, or its directory when there is none.\"\n  (or (and (fboundp 'projectile-project-root) (projectile-project-root))\n      default-directory))\n\n(defun my/find-files ()\n  \"Find a file anywhere in the project, hidden files included.\"\n  (interactive)\n  (consult-fd (my/project-root)))\n\n(defun my/find-files-in-dir ()\n  \"Find a file under the directory of the current buffer.\"\n  (interactive)\n  (consult-fd default-directory))\n\n(defun my/recent-files ()\n  \"Open a recently visited file.\"\n  (interactive)\n  (consult-recent-file))\n\n(defun my/search-project ()\n  \"Search the project for a literal string.\"\n  (interactive)\n  (let ((consult-ripgrep-args (concat consult-ripgrep-args \" --fixed-strings\")))\n    (consult-ripgrep (my/project-root))))\n\n(defun my/search-project-regex ()\n  \"Search the project with a regexp.\"\n  (interactive)\n  (consult-ripgrep (my/project-root)))\n\n(defun my/search-buffer-regex ()\n  \"Search only this file, with a regexp.\"\n  (interactive)\n  (consult-ripgrep (list (buffer-file-name))))\n\n(defun my/consult-env ()\n  \"Pick an environment variable; its value goes to the kill ring.\"\n  (interactive)\n  (let ((pair (completing-read \"Environment: \" process-environment nil t)))\n    (when (string-match \"\\\\`\\\\([^=]+\\\\)=\\\\(.*\\\\)\\\\'\" pair)\n      (kill-new (match-string 2 pair))\n      (message \"%s = %s (copied)\" (match-string 1 pair) (match-string 2 pair)))))\n\n(defun my/reload-config ()\n  \"Re-read the generated configuration — the `so $MYVIMRC' reflex.\"\n  (interactive)\n  (let ((file (locate-library \"default\")))\n    (if file\n        (progn (load file nil :nomessage)\n               (message \"Reloaded %s\" file))\n      (message \"Could not locate the generated default.el\"))))\n\n(defun my/kill-buffer-force ()\n  \"Kill this buffer, discarding changes — the `q!' reflex.\"\n  (interactive)\n  (set-buffer-modified-p nil)\n  (kill-buffer))\n\n(defun my/quit-frame ()\n  \"Close this frame, leaving the daemon running.\n\n`save-buffers-kill-terminal' -- what SPC q q used to run -- closes only the\ncurrent frame when that frame belongs to an emacsclient. Frames made by\n`make-frame' inside the daemon are not client frames, so there it killed\nEmacs outright: every buffer, every LSP server, the mu index, gone, with a\nprompt about live processes as the only warning. The launcher creates\nframes that way now, so quitting has to be explicit about meaning the\nframe.\n\nThe daemon surviving is the entire point of running one -- the next frame\nopens instantly with the session intact. SPC q Q still kills it.\"\n  (interactive)\n  (if (cdr (frame-list))\n      (delete-frame)\n    (message \"This is the only frame; SPC q Q kills the daemon\")))\n\n(defun my/quit-force ()\n  \"Quit without saving — `qa!'.\"\n  (interactive)\n  (dolist (buffer (buffer-list))\n    (with-current-buffer buffer (set-buffer-modified-p nil)))\n  (kill-emacs))\n\n(require 'ls-lisp)\n\n(setq ls-lisp-use-insert-directory-program nil\n      ls-lisp-dirs-first t\n      dired-listing-switches \"-alh\"\n      dired-dwim-target t\n      dired-kill-when-opening-new-dired-buffer t)\n\n(add-hook 'dired-mode-hook #'nerd-icons-dired-mode)\n\n(add-hook 'dired-mode-hook #'diredfl-mode)")

(work/load-module "plugins/files/replace.nix" '(deadgrep wgrep)
  "(require 'deadgrep)\n\n(require 'wgrep)\n\n(setq wgrep-auto-save-buffer t\n      wgrep-change-readonly-file t\n      deadgrep-max-line-length 500)\n\n(with-eval-after-load 'deadgrep\n  (define-key deadgrep-mode-map (kbd \"C-c C-e\") #'deadgrep-edit-mode))\n\n(with-eval-after-load 'grep\n  (define-key grep-mode-map (kbd \"C-c C-e\") #'wgrep-change-to-wgrep-mode))\n\n(defun my/replace-buffer ()\n  \"Substitute across this buffer, starting a :%s/ line.\"\n  (interactive)\n  (evil-ex \"%s/\"))\n\n(defun my/replace-word-buffer ()\n  \"Substitute the symbol at point across this buffer.\"\n  (interactive)\n  (let ((word (thing-at-point 'symbol t)))\n    (if word\n        (evil-ex (format \"%%s/\\\\<%s\\\\>/\" (regexp-quote word)))\n      (evil-ex \"%s/\"))))\n\n(defun my/replace-project ()\n  \"Search the project, then edit the matches in place and save them all.\"\n  (interactive)\n  (deadgrep (read-string \"Replace across project — search for: \")))\n\n(defun my/replace-word-project ()\n  \"Same as `my/replace-project', seeded with the symbol at point.\"\n  (interactive)\n  (deadgrep (or (thing-at-point 'symbol t)\n                (read-string \"Search for: \"))))")

(work/load-module "plugins/files/tree.nix" '(treemacs treemacs-evil treemacs-magit treemacs-nerd-icons)
  "(setq treemacs-persist-file (expand-file-name \"treemacs-persist\" user-emacs-directory)\n      treemacs-last-error-persist-file (expand-file-name\n                                        \"treemacs-persist-at-last-error\"\n                                        user-emacs-directory)\n      treemacs-width 35\n      treemacs-follow-after-init t\n      treemacs-indentation 2\n      treemacs-is-never-other-window t\n      treemacs-show-hidden-files t\n      treemacs-silent-filewatch t\n      treemacs-silent-refresh t\n      treemacs-sorting 'alphabetic-asc)\n\n(require 'treemacs)\n\n(require 'treemacs-evil)\n\n(require 'treemacs-nerd-icons)\n\n(require 'treemacs-project-follow-mode)\n\n(with-eval-after-load 'magit (require 'treemacs-magit))\n\n(treemacs-load-theme \"nerd-icons\")\n\n(treemacs-git-mode 'deferred)\n\n(treemacs-filewatch-mode 1)\n\n(treemacs-fringe-indicator-mode 'always)\n\n(setq treemacs-git-commit-diff-mode t)\n\n(treemacs-follow-mode 1)\n\n(treemacs-project-follow-mode 1)\n\n(defun my/treemacs-toggle ()\n  \"Toggle the tree, revealing the current file.\n\nRegisters the current project with treemacs if it is not already there,\nwhich is what `treemacs-find-file' silently requires.\"\n  (interactive)\n  (pcase (treemacs-current-visibility)\n    ('visible (delete-window (treemacs-get-local-window)))\n    (_\n     (if (treemacs--find-current-user-project)\n         (treemacs-add-and-display-current-project-exclusively)\n       (treemacs))\n     (when (buffer-file-name)\n       (ignore-errors (treemacs-find-file))))))\n\n(defun my/treemacs-visit-and-quit ()\n  \"Open the node at point and close the tree.\"\n  (interactive)\n  (treemacs-RET-action)\n  (when (eq (treemacs-current-visibility) 'visible)\n    (delete-window (treemacs-get-local-window))))\n\n(with-eval-after-load 'treemacs\n  (dolist (binding\n           `((\"RET\"   . my/treemacs-visit-and-quit)\n             (\"o\"     . my/treemacs-visit-and-quit)\n             (\"TAB\"   . treemacs-TAB-action)\n             (\"q\"     . treemacs-quit)\n             (\"a\"     . treemacs-create-file)\n             (\"A\"     . treemacs-create-dir)\n             (\"d\"     . treemacs-delete-file)\n             (\"r\"     . treemacs-rename-file)\n             (\"R\"     . treemacs-refresh)\n             (\"c\"     . treemacs-copy-file)\n             (\"x\"     . treemacs-move-file)\n             (\"y\"     . treemacs-copy-file-name)\n             (\"Y\"     . treemacs-copy-relative-path-at-point)\n             (\"gy\"    . treemacs-copy-absolute-path-at-point)\n             (\"m\"     . treemacs-add-bookmark)\n             (\"H\"     . treemacs-toggle-show-dotfiles)\n             (\"I\"     . treemacs-hide-gitignored-files-mode)\n             (\"E\"     . treemacs-expand-all-projects)\n             (\"W\"     . treemacs-collapse-all-projects)\n             (\"S\"     . treemacs-find-file)\n             (\"-\"     . treemacs-root-up)\n             (\"<backspace>\" . treemacs-collapse-parent-node)\n             (\"C-]\"   . treemacs-root-down)\n             (\"C-v\"   . treemacs-visit-node-vertical-split)\n             (\"C-x\"   . treemacs-visit-node-horizontal-split)\n             (\"C-t\"   . treemacs-visit-node-in-most-recently-used-window)\n             (\"C-k\"   . treemacs-show-file-details)))\n    (evil-define-key 'treemacs treemacs-mode-map\n      (kbd (car binding)) (cdr binding))))")

(work/load-module "plugins/lsp/diagnostics.nix" '(consult-flycheck flycheck flycheck-posframe flycheck-projectile)
  "(require 'flycheck)\n\n(require 'consult-flycheck)\n\n(require 'flycheck-posframe)\n\n(setq flycheck-posframe-border-width 1\n          flycheck-posframe-inhibit-functions\n          (list (lambda (&rest _) (bound-and-true-p completion-in-region-mode))\n                #'evil-insert-state-p))\n\n(defun my/flycheck-display-setup ()\n      \"Pick how diagnostics are shown, from the frame this buffer is in.\nposframe needs a child frame, which a terminal cannot make; there the\nfringe is unavailable too, so the indicator moves to the margin.\"\n      (setq-local flycheck-indication-mode\n                  (if (display-graphic-p) 'left-fringe 'left-margin))\n      (when (display-graphic-p)\n        (flycheck-posframe-mode 1)))\n\n(add-hook 'flycheck-mode-hook #'my/flycheck-display-setup)\n\n(defun my/flycheck-display-refresh ()\n      \"Re-decide the diagnostic display for every flycheck buffer.\"\n      (when (display-graphic-p)\n        (dolist (b (buffer-list))\n          (with-current-buffer b\n            (when (bound-and-true-p flycheck-mode)\n              (my/flycheck-display-setup))))))\n\n(add-hook 'server-after-make-frame-hook #'my/flycheck-display-refresh)\n\n(defun my/flycheck-recheck-buffer (buffer)\n      \"Run flycheck once in BUFFER, if it is still around and idle.\"\n      (when (buffer-live-p buffer)\n        (with-current-buffer buffer\n          (when (and (bound-and-true-p flycheck-mode)\n                     (not (flycheck-running-p)))\n            (flycheck-buffer)))))\n\n(defun my/flycheck-after-lsp-open ()\n      \"Re-check this buffer a few seconds after a language server attaches.\"\n      (run-with-timer 4 nil #'my/flycheck-recheck-buffer (current-buffer)))\n\n(add-hook 'lsp-after-open-hook #'my/flycheck-after-lsp-open)\n\n(require 'flycheck-projectile)\n\n(setq flycheck-check-syntax-automatically '(save mode-enabled idle-change)\n          flycheck-idle-change-delay 0.8\n          flycheck-display-errors-delay 0.3\n          flycheck-help-echo-function nil)\n\n(setq flycheck-global-modes\n          '(not vterm-mode eat-mode term-mode eshell-mode comint-mode))\n\n(global-flycheck-mode 1)\n\n(setq flycheck-error-list-format\n          `[(\"Line\" 5 flycheck-error-list-entry-< :right-align t)\n            (\"Col\" 3 nil :right-align t)\n            (\"Level\" 8 flycheck-error-list-entry-level-<)\n            (\"ID\" 6 t)\n            (,(flycheck-error-list-make-last-column \"Message\" 'Checker) 0 t)])\n\n(flycheck-define-checker my/nix-statix\n      \"A nix linter using statix.\"\n      :command (\"statix\" \"check\" \"--format=errfmt\" source-original)\n      :predicate (lambda () (and buffer-file-name (not (buffer-modified-p))))\n      :error-patterns\n      ((warning line-start (file-name) \">\" line \":\" column \":\"\n                (id (one-or-more (not (any \":\")))) \":\"\n                (message (one-or-more not-newline)) line-end))\n      :modes (nix-mode nix-ts-mode))\n\n(add-to-list 'flycheck-checkers 'my/nix-statix)\n\n(setq flycheck-yamllintrc \".yamllint\")\n\n(defun my/diagnostics-list ()\n      \"Project-wide diagnostics list — the `Trouble' reflex.\nPrefers lsp-treemacs when a server is attached (it groups by file and follows the\nworkspace) and falls back to flycheck's own project list otherwise.\"\n      (interactive)\n      (if (bound-and-true-p lsp-mode)\n          (lsp-treemacs-errors-list)\n        (flycheck-projectile-list-errors)))\n\n(defun my/diagnostics-buffer ()\n      \"Diagnostics for this buffer, as a searchable list.\"\n      (interactive)\n      (consult-flycheck))\n\n(defun my/diagnostic-at-point ()\n      \"Explain the diagnostic under the cursor — vim.diagnostic.open_float().\"\n      (interactive)\n      (if (and (bound-and-true-p lsp-ui-mode) (lsp-ui-doc--visible-p))\n          (lsp-ui-doc-hide)\n        (or (ignore-errors (flycheck-display-error-at-point))\n            (message \"No diagnostic at point\"))))\n\n(defun my/diagnostic-explain ()\n      \"Full explanation for the diagnostic under the cursor.\"\n      (interactive)\n      (or (ignore-errors (flycheck-explain-error-at-point))\n          (ignore-errors (flycheck-display-error-at-point))\n          (message \"No diagnostic at point\")))")

(work/load-module "plugins/lsp/format.nix" '(apheleia)
  "(require 'apheleia)\n\n(dolist (entry\n             '((prettierd   . (\"prettierd\" filepath))\n               (stylua      . (\"stylua\" \"--stdin-filepath\" filepath \"-\"))\n               (nixfmt      . (\"nixfmt\"))\n               (black       . (\"black\" \"-q\" \"-\"))\n               (yamlfmt     . (\"yamlfmt\" \"-in\"))\n               (pgformatter . (\"pg_format\"))))\n      (setf (alist-get (car entry) apheleia-formatters) (cdr entry)))\n\n(dolist (entry '((css-ts-mode        . prettierd)\n                     (css-mode           . prettierd)\n                     (scss-mode          . prettierd)\n                     (less-css-mode      . prettierd)\n                     (html-mode          . prettierd)\n                     (mhtml-mode         . prettierd)\n                     (html-ts-mode       . prettierd)\n                     (web-mode           . prettierd)\n                     (js-mode            . prettierd)\n                     (js-ts-mode         . prettierd)\n                     (jsx-mode           . prettierd)\n                     (typescript-mode    . prettierd)\n                     (typescript-ts-mode . prettierd)\n                     (tsx-ts-mode        . prettierd)\n                     (json-mode          . prettierd)\n                     (json-ts-mode       . prettierd)\n                     (markdown-mode      . prettierd)\n                     (gfm-mode           . prettierd)\n                     (graphql-mode       . prettierd)\n                     (lua-mode           . stylua)\n                     (lua-ts-mode        . stylua)\n                     (nix-mode           . nixfmt)\n                     (nix-ts-mode        . nixfmt)\n                     (python-mode        . black)\n                     (python-ts-mode     . black)\n                     (yaml-mode          . yamlfmt)\n                     (yaml-ts-mode       . yamlfmt)\n                     (sql-mode           . pgformatter)))\n      (setf (alist-get (car entry) apheleia-mode-alist) (cdr entry)))\n\n(apheleia-global-mode 1)\n\n(defun my/format-fallback-to-lsp ()\n      \"Let the language server format buffers apheleia has no formatter for.\nconform's `lspFallback = true', for Go, Haskell, Prisma and anything else whose\nserver formats but has no standalone binary here.\"\n      (when (and (bound-and-true-p lsp-mode)\n                 (not (alist-get major-mode apheleia-mode-alist)))\n        (ignore-errors (lsp-format-buffer))))\n\n(add-hook 'before-save-hook #'my/format-fallback-to-lsp)\n\n(defun my/format-buffer ()\n      \"Format now, without waiting for a save.\"\n      (interactive)\n      (if (alist-get major-mode apheleia-mode-alist)\n          (apheleia-format-buffer (alist-get major-mode apheleia-mode-alist))\n        (if (bound-and-true-p lsp-mode)\n            (lsp-format-buffer)\n          (message \"No formatter for %s\" major-mode))))")

(work/load-module "plugins/lsp/lsp.nix" '(consult-lsp lsp-mode lsp-pyright lsp-treemacs lsp-ui)
  "(require 'lsp-mode)\n\n(require 'lsp-ui)\n\n(setq lsp-disabled-clients '(semgrep-ls semgrep-ls-tramp))\n\n(require 'consult-lsp)\n\n(require 'lsp-treemacs)\n\n(setq lsp-keymap-prefix nil\n          lsp-idle-delay 0.3\n          lsp-response-timeout 30\n          lsp-clients-typescript-max-ts-server-memory 4096\n          lsp-log-io nil\n          lsp-completion-provider :none\n          lsp-diagnostics-provider :flycheck\n          lsp-headerline-breadcrumb-enable t\n          lsp-headerline-breadcrumb-icons-enable t\n          lsp-inlay-hint-enable t\n          lsp-modeline-code-actions-enable t\n          lsp-modeline-diagnostics-enable nil\n          lsp-eldoc-enable-hover t\n          lsp-eldoc-render-all nil\n          lsp-signature-auto-activate '(:on-trigger-char :after-completion)\n          lsp-signature-render-documentation nil\n          lsp-enable-symbol-highlighting t\n          lsp-enable-snippet t\n          lsp-enable-file-watchers t\n          lsp-file-watch-threshold 4000\n          lsp-semantic-tokens-enable t\n          lsp-lens-enable nil\n          lsp-enable-on-type-formatting nil\n          lsp-enable-indentation nil)\n\n(setq lsp-ui-doc-enable t\n          lsp-ui-doc-position 'at-point\n          lsp-ui-doc-show-with-cursor t\n          lsp-ui-doc-show-with-mouse nil\n          lsp-ui-doc-delay 0.5\n          lsp-ui-doc-max-height 20\n          lsp-ui-doc-max-width 80\n          lsp-ui-sideline-enable nil\n          lsp-ui-sideline-show-diagnostics nil\n          lsp-ui-sideline-show-code-actions nil\n          lsp-ui-sideline-show-hover nil\n          lsp-ui-sideline-code-actions-prefix \"💡 \"\n          lsp-ui-peek-enable t\n          lsp-ui-peek-show-directory t\n          lsp-ui-imenu-auto-refresh t)\n\n(defun my/lsp-ui-doc-fit-frame (&rest _)\n      \"Keep the doc popup inside the current window.\"\n      (setq lsp-ui-doc-max-width (max 40 (- (window-body-width) 8))))\n\n(defun my/lsp-ui-doc-slack (frame)\n      \"Widen FRAME by one character so its last glyph clears the border.\"\n      (when (frame-live-p frame)\n        (let ((frame-resize-pixelwise t))\n          (set-frame-size frame\n                          (+ (frame-pixel-width frame) (frame-char-width frame))\n                          (frame-pixel-height frame)\n                          t))))\n\n(defun my/lsp-ui-doc-code-actions ()\n      \"Code actions available at point as plain text, or nil if there are none.\"\n      (let ((s (and (bound-and-true-p lsp-modeline--code-actions-string)\n                    (string-trim\n                     (substring-no-properties lsp-modeline--code-actions-string)))))\n        (unless (or (null s) (string-empty-p s)) s)))\n\n(defun my/lsp-ui-doc-with-actions (args)\n      \"Append the code actions at point to the hover string in ARGS.\"\n      (let ((symbol (nth 0 args))\n            (string (nth 1 args))\n            (actions (my/lsp-ui-doc-code-actions)))\n        (if (and string (not (string-empty-p string)) actions)\n            (list symbol (concat string \"\\n\\n---\\n\\n\" actions))\n          args)))\n\n(with-eval-after-load 'lsp-ui\n      (advice-add 'lsp-ui-doc--make-frame :before #'my/lsp-ui-doc-fit-frame)\n      (advice-add 'lsp-ui-doc-glance :before #'my/lsp-ui-doc-fit-frame)\n      (advice-add 'lsp-ui-doc--move-frame :after #'my/lsp-ui-doc-slack)\n      (advice-add 'lsp-ui-doc--display :filter-args #'my/lsp-ui-doc-with-actions))\n\n(setq lsp-javascript-display-enum-member-value-hints t\n          lsp-javascript-display-return-type-hints t\n          lsp-javascript-display-parameter-type-hints t\n          lsp-javascript-display-parameter-name-hints \"all\"\n          lsp-javascript-display-parameter-name-hints-when-argument-matches-name t\n          lsp-javascript-display-property-declaration-type-hints t\n          lsp-javascript-display-variable-type-hints t)\n\n(setq lsp-nix-nixd-server-path \"nixd\"\n          lsp-nix-nixd-formatting-command [\"nixfmt\"])\n\n(add-hook 'web-mode-hook (lambda () (setq-local lsp-semantic-tokens-enable nil)))\n\n(setq lsp-volar-location-for-typescript-plugin\n          work/vue-package)\n\n(require 'lsp-pyright)\n\n(setq lsp-clients-angular-language-server-command\n          `(\"ngserver\"\n            \"--stdio\"\n            \"--tsProbeLocations\" ,work/npm-root\n            \"--ngProbeLocations\" ,work/npm-root))\n\n(lsp-register-client\n     (make-lsp-client\n      :new-connection (lsp-stdio-connection\n                       (lambda ()\n                         (list \"tailwindcss-language-server\" \"--stdio\")))\n      :activation-fn (lambda (_file-name mode)\n                       (memq mode '(html-mode html-ts-mode mhtml-mode web-mode\n                                    css-mode css-ts-mode scss-mode less-css-mode\n                                    js-mode js-ts-mode jsx-mode tsx-ts-mode\n                                    typescript-mode typescript-ts-mode)))\n      :server-id 'tailwindcss-ls\n      :add-on? t\n      :priority -1))\n\n(lsp-register-custom-settings\n     '((\"tailwindCSS.validate\" \"error\")\n       (\"tailwindCSS.classAttributes\" [\"class\" \"className\" \"ngClass\" \"classList\"])\n       (\"tailwindCSS.emmetCompletions\" t t)))\n\n(lsp-register-client\n     (make-lsp-client\n      :new-connection (lsp-stdio-connection\n                       (lambda ()\n                         (list \"prisma-language-server\" \"--stdio\")))\n      :activation-fn (lambda (_file-name mode) (eq mode 'prisma-mode))\n      :server-id 'prisma-ls))\n\n(dolist (hook '(bash-ts-mode-hook\n                    css-ts-mode-hook\n                    dockerfile-ts-mode-hook\n                    go-ts-mode-hook\n                    haskell-mode-hook\n                    html-mode-hook\n                    js-ts-mode-hook\n                    json-ts-mode-hook\n                    lua-ts-mode-hook\n                    mhtml-mode-hook\n                    nix-ts-mode-hook\n                    prisma-mode-hook\n                    python-ts-mode-hook\n                    scss-mode-hook\n                    sh-mode-hook\n                    tsx-ts-mode-hook\n                    typescript-ts-mode-hook\n                    web-mode-hook\n                    yaml-ts-mode-hook))\n      (add-hook hook #'lsp-deferred))\n\n(add-hook 'lsp-mode-hook #'lsp-ui-mode)\n\n(defun my/lsp-signature-help ()\n      \"Signature help for the symbol at point, whichever backend is live.\nBound to C-k in normal and insert state, as the LspAttach autocmd does.\"\n      (interactive)\n      (cond\n       ((and (bound-and-true-p lsp-mode) (fboundp 'lsp-signature-activate))\n        (lsp-signature-activate))\n       ((fboundp 'eldoc-print-current-symbol-info)\n        (eldoc-print-current-symbol-info))\n       (t (message \"No signature help here\"))))\n\n(defun my/lsp-code-action-kind (kind)\n      \"Run the code action of KIND at point, e.g. \\\"refactor.extract\\\".\nThis is how the localleader extract and inline keys work: refactoring.nvim's\ntree-sitter rewrites have no Emacs equivalent, but every language server in this\nconfig implements the standard refactor.* code action kinds, which covers the\ncommon cases for TypeScript, Vue and Python.\"\n      (if (bound-and-true-p lsp-mode)\n          (condition-case err\n              (lsp-execute-code-action-by-kind kind)\n            (error (message \"No %s action available here (%s)\"\n                            kind (error-message-string err))))\n        (message \"lsp-mode is not active in this buffer\")))\n\n(defun my/lsp-extract () \"Extract refactoring at point.\" (interactive)\n           (my/lsp-code-action-kind \"refactor.extract\"))\n\n(defun my/lsp-inline () \"Inline refactoring at point.\" (interactive)\n           (my/lsp-code-action-kind \"refactor.inline\"))\n\n(defun my/lsp-restart ()\n      \"Restart the workspace for this buffer — the LspRestart reflex.\"\n      (interactive)\n      (if (bound-and-true-p lsp-mode) (lsp-workspace-restart (lsp--read-workspace))\n        (message \"lsp-mode is not active in this buffer\")))")

(work/load-module "plugins/lsp/sonar.nix" '(lsp-sonarlint)
  "(when (require 'lsp-sonarlint nil t)\n      (setq lsp-sonarlint-server-path \"sonarlint-ls\"\n            lsp-sonarlint-auto-download nil\n            lsp-sonarlint-plugin-autodownload nil\n            lsp-sonarlint-use-system-jre t\n            lsp-sonarlint-disable-telemetry t\n            lsp-sonarlint-javascript-enabled t\n            lsp-sonarlint-typescript-enabled t\n            lsp-sonarlint-html-enabled t\n            lsp-sonarlint-css-enabled t\n            lsp-sonarlint-python-enabled t\n            lsp-sonarlint-go-enabled t\n            lsp-sonarlint-secrets-enabled t\n            lsp-sonarlint-text-enabled t\n            lsp-sonarlint-xml-enabled t))\n\n(defun my/sonar-scan ()\n      \"Run sonar-scanner over the project.\nReads sonar-project.properties, so a project already wired to SonarQube needs no\narguments; without one the scanner will say so.\"\n      (interactive)\n      (let ((default-directory (my/project-root))\n            (compilation-buffer-name-function (lambda (_) \"*sonar*\")))\n        (compile \"sonar-scanner\")))")

(work/load-module "plugins/devops/default.nix" '(docker dockerfile-mode envrc just-mode k8s-mode terraform-mode)
  "(require 'docker)\n\n(setq docker-show-messages nil\n      docker-container-columns\n      '((:name \"Names\" :width 30 :template \"{{ json .Names }}\" :sort nil :format nil)\n        (:name \"Status\" :width 20 :template \"{{ json .Status }}\" :sort nil :format nil)\n        (:name \"Image\" :width 30 :template \"{{ json .Image }}\" :sort nil :format nil)\n        (:name \"Ports\" :width 20 :template \"{{ json .Ports }}\" :sort nil :format nil)))\n\n(require 'dockerfile-mode)\n\n(add-to-list 'auto-mode-alist '(\"[Dd]ockerfile\\\\'\" . dockerfile-ts-mode))\n\n(require 'k8s-mode)\n\n(require 'terraform-mode)\n\n(require 'just-mode)\n\n(add-to-list 'auto-mode-alist '(\"\\\\.tf\\\\(vars\\\\)?\\\\'\" . terraform-mode))\n\n(add-to-list 'auto-mode-alist '(\"[Jj]ustfile\\\\'\" . just-mode))\n\n(add-hook 'terraform-mode-hook #'terraform-format-on-save-mode)\n\n(require 'envrc)\n\n(envrc-global-mode 1)")

(work/load-module "plugins/data/default.nix" '(prisma-mode sql-indent sqlformat)
  "(require 'sql)\n\n(require 'sql-indent)\n\n(require 'prisma-mode)\n\n(add-to-list 'auto-mode-alist '(\"\\\\.prisma\\\\'\" . prisma-mode))\n\n(add-hook 'sql-mode-hook #'sqlind-minor-mode)\n\n(setq sql-product 'postgres\n      sql-postgres-program \"psql\"\n      sql-postgres-options '(\"--no-psqlrc\" \"--pset=pager=off\")\n      sql-send-terminator t\n      comint-buffer-maximum-size 8192)\n\n(defun my/sql-postgres ()\n  \"Open a psql session, reading credentials from ~/.pgpass or the environment.\"\n  (interactive)\n  (let ((url (getenv \"DATABASE_URL\")))\n    (if (and url (string-match\n                  \"postgres\\\\(?:ql\\\\)?://\\\\([^:]+\\\\)\\\\(?::[^@]*\\\\)?@\\\\([^:/]+\\\\)\\\\(?::\\\\([0-9]+\\\\)\\\\)?/\\\\(.+\\\\)\"\n                  url))\n        (let ((sql-user (match-string 1 url))\n              (sql-server (match-string 2 url))\n              (sql-port (string-to-number (or (match-string 3 url) \"5432\")))\n              (sql-database (match-string 4 url)))\n          (sql-postgres))\n      (call-interactively #'sql-postgres))))\n\n(add-hook 'sql-mode-hook #'lsp-deferred)\n\n(setq sqlformat-command 'pgformatter\n      sqlformat-args '(\"-s2\" \"-g\" \"-u1\"))")

(work/load-module "plugins/ai/default.nix" '(gptel)
  "(setq claude-code-ide-cli-path \"claude\"\n      claude-code-ide-use-side-window nil\n      claude-code-ide-focus-on-open t)\n\n(setq claude-code-ide-manager-window-width 26\n      claude-code-ide-manager-persist-state t)\n\n(setq claude-code-ide-session-idle-default-enabled t\n      claude-code-ide-session-idle-delay 4)\n\n(autoload 'claude-code-ide-manager-toggle-global-sidebar \"claude-code-ide\" nil t)\n\n(autoload 'claude-code-ide-manager-toggle-repo-sidebar \"claude-code-ide\" nil t)\n\n(autoload 'claude-code-ide-manager-focus \"claude-code-ide\" nil t)\n\n(with-eval-after-load 'claude-code-ide\n  (claude-code-ide-emacs-tools-setup))\n\n(custom-set-faces\n '(claude-code-ide-manager-current-session-face\n   ((t (:inherit highlight :weight bold))))\n '(claude-code-ide-manager-current-marker-face\n   ((t (:inherit success :weight bold))))\n '(claude-code-ide-manager-idle-session-face ((t (:inherit warning))))\n '(claude-code-ide-manager-working-session-face\n   ((t (:inherit font-lock-keyword-face))))\n '(claude-code-ide-manager-attention-session-face\n   ((t (:inherit error :weight bold))))\n '(claude-code-ide-manager-done-session-face ((t (:inherit success)))))\n\n(defun my/claude--pane-windows ()\n  \"Windows showing a Claude session on this frame.\"\n  (seq-filter (lambda (win)\n                (and (fboundp 'claude-code-ide-session-buffer-p)\n                     (claude-code-ide-session-buffer-p (window-buffer win))))\n              (window-list nil 'no-minibuffer)))\n\n(defun my/claude--pane-window ()\n  \"The window showing a Claude session on this frame, if one is.\"\n  (car (my/claude--pane-windows)))\n\n(defun my/claude--collapse-stray-panes ()\n  \"Close the windows showing a session outside the drawer.\nOne conversation at a time in one column is the point of the drawer, and a\nsession in an ordinary window is a second pane doing the drawer's job. It is\nalso sticky: `display-buffer-reuse-window' finds a window already showing\nthe buffer before the drawer rule is ever consulted, so every later switch\ninto that conversation goes back to the stray window.\"\n  (dolist (win (my/claude--pane-windows))\n    (when (and (window-live-p win)\n               (not (window-parameter win 'window-side))\n               (not (one-window-p)))\n      (ignore-errors (delete-window win)))))\n\n(defun my/claude-show-session (key)\n  \"Show the session KEY in the Claude pane and put the point in it.\n`pop-to-buffer', so the drawer rule decides where it lands -- the same rule\nevery other route to a session goes through.\"\n  (let ((buf (claude-code-ide-manager--session-buffer key)))\n    (unless (buffer-live-p buf)\n      (user-error \"That session is no longer running\"))\n    (when (fboundp 'claude-code-ide--touch-session)\n      (ignore-errors (claude-code-ide--touch-session key)))\n    (my/claude--collapse-stray-panes)\n    (pop-to-buffer buf)))\n\n(defun my/claude-pane-toggle ()\n  \"Show or hide the Claude pane, leaving the session running behind it.\nStarts one when this project has none, which is what makes this the only\nbinding needed to get to Claude from cold.\"\n  (interactive)\n  (require 'claude-code-ide)\n  (if-let* ((win (my/claude--pane-window)))\n      (delete-window win)\n    (claude-code-ide)))\n\n(defun my/claude-sidebar-visit ()\n  \"Show the session on this sidebar row in the Claude pane.\"\n  (interactive)\n  (let ((item (claude-code-ide-manager--item-at-point)))\n    (unless item (user-error \"No session on this line\"))\n    (my/claude-show-session\n     (claude-code-ide-manager-item-session-key item))))\n\n(defun my/claude-sidebar-peek ()\n  \"Show the session on this row but keep the point in the sidebar.\"\n  (interactive)\n  (save-selected-window (my/claude-sidebar-visit)))\n\n(with-eval-after-load 'claude-code-ide-manager\n  (define-key claude-code-ide-manager-mode-map (kbd \"RET\") #'my/claude-sidebar-visit)\n  (define-key claude-code-ide-manager-mode-map (kbd \"SPC\") #'my/claude-sidebar-peek)\n  (with-eval-after-load 'evil\n    (evil-define-key 'normal claude-code-ide-manager-mode-map\n      (kbd \"RET\") #'my/claude-sidebar-visit\n      (kbd \"SPC\") #'my/claude-sidebar-peek)))\n\n(defun my/claude--manager-switch-in-pane (session-key &optional keep-manager-focus scope)\n  \"Show SESSION-KEY in the Claude pane, in place of the package's workspace.\n\nThe override for `claude-code-ide-manager-switch-to-session', which\notherwise captures the frame's layout under the session being left, runs\n`delete-other-windows', and rebuilds the frame as a status buffer -- magit,\nor dired when magit is absent -- beside the session. Switching conversation\nis not switching project here: the pane is somewhere to talk to Claude, and\nthe windows around it belong to whatever you were reading. A conversation\nthat has nothing to do with the code in front of you is the ordinary case,\nnot the exception.\n\nThe sidebar's own bookkeeping is kept: the row for SESSION-KEY becomes the\ncurrent one, its state glyph clears on the way in, and the recency order\n`claude-code-ide' reopens by is updated. KEEP-MANAGER-FOCUS leaves the point\nwhere it is, which is what the sidebar passes while `n' and `p' walk it.\"\n  (let ((scope (or scope (claude-code-ide-manager--scope-for-command))))\n    (unless (claude-code-ide-manager--ensure-live-target session-key scope)\n      (user-error \"No live session buffer for %s\" session-key))\n    (ignore-errors\n      (setq claude-code-ide-manager--current-session-key session-key)\n      (claude-code-ide-manager--set-scope-active-session-key scope session-key)\n      (claude-code-ide-manager--mark-session-managed session-key)\n      (claude-code-ide-manager--reset-session-idle-state session-key)\n      (claude-code-ide-manager--save-state)\n      (claude-code-ide-manager--refresh-sidebar-state scope nil))\n    (if keep-manager-focus\n        (save-selected-window (my/claude-show-session session-key))\n      (my/claude-show-session session-key))\n    (my/claude--pane-window)))\n\n(defun my/claude--manager-layout-in-pane (session-key &optional _scope)\n  \"Show SESSION-KEY in the pane and return the window it is in.\nThe override for `claude-code-ide-manager--build-default-layout', which is\nwhat opens the project: it is the frame-rebuilding half of the workspace\nmodel, reached from the restore path and from `R' on a sidebar row. There is\nnothing to rebuild when the layout is one pane.\"\n  (my/claude-show-session session-key)\n  (my/claude--pane-window))\n\n(with-eval-after-load 'claude-code-ide-manager\n  (advice-add 'claude-code-ide-manager-switch-to-session\n              :override #'my/claude--manager-switch-in-pane)\n  (advice-add 'claude-code-ide-manager--build-default-layout\n              :override #'my/claude--manager-layout-in-pane))\n\n(defvar my/claude--branch-cache (make-hash-table :test 'equal)\n  \"Directory to (TIME . BRANCH), as the sidebar last read it.\")\n\n(defvar my/claude--branch-cache-ttl 30\n  \"Seconds a cached branch name is trusted before git is asked again.\")\n\n(defun my/claude--cached-branch-name (orig session-or-key)\n  \"Call ORIG for SESSION-OR-KEY at most once per directory per TTL.\"\n  (let* ((dir (ignore-errors\n                (claude-code-ide-manager--session-directory session-or-key)))\n         (hit (and dir (gethash dir my/claude--branch-cache))))\n    (if (and hit (< (- (float-time) (car hit)) my/claude--branch-cache-ttl))\n        (cdr hit)\n      (let ((branch (funcall orig session-or-key)))\n        (when dir\n          (puthash dir (cons (float-time) branch) my/claude--branch-cache))\n        branch))))\n\n(with-eval-after-load 'claude-code-ide-manager\n  (advice-add 'claude-code-ide-manager--session-branch-name\n              :around #'my/claude--cached-branch-name))\n\n(defun my/claude--live-session-p ()\n  \"Non-nil when at least one Claude session is running anywhere.\n\nAsked without loading claude-code-ide, and that is the point rather than a\ndetail: nothing can be running until something has loaded the package, so\nan unloaded package is an honest no. The sidebar therefore stops being the\nthing that drags a websocket client, an HTTP server and a set of\nper-session timers into every frame that opens.\"\n  (and (fboundp 'claude-code-ide-manager--live-sessions)\n       (consp (claude-code-ide-manager--live-sessions))))\n\n(defun my/claude-sidebar-open-maybe (&optional _frame)\n  \"Open the live-session sidebar on this frame, once, if there is a session.\nPer frame rather than once per Emacs: a side window belongs to a frame, and\nthese are daemon frames -- `emacsclient -c' makes a new one every time, and\neach one starts without it.\n\nThe frame parameter is what makes it once: without it, toggling the sidebar\noff and opening another frame would put it back on the first one too. It is\nset only when the sidebar is actually drawn, so a frame that opened with\nnothing running is still owed one when the first session starts.\n\nNothing running, nothing drawn. A list of live sessions with no live\nsessions in it is a 26-column empty strip, permanently, on every frame --\nand the pane is worth its width only once it has something to say. The\nsession-setup hook below is the other half: the sidebar arrives with the\nfirst session rather than waiting for the next frame.\n\n`ignore-errors' because this runs on the path that creates a frame. The\nsidebar is worth having by default; it is not worth a frame that will not\nopen.\n\n`save-selected-window', because opening the sidebar selects it and a frame\nmust not open with the point in a side pane. The pane is in emacs state --\nso hnei do not move -- and every later hook that asks what the frame is\nshowing gets the sidebar as the answer: the dashboard's own new-frame hook\nread that, decided the frame had something of its own to show, and stood\ndown. A frame that opened on an empty strip with the point in it and no\nhome screen behind it is what that looked like.\"\n  (when (and (not (frame-parameter nil 'my/claude-sidebar-shown))\n             (my/claude--live-session-p))\n    (set-frame-parameter nil 'my/claude-sidebar-shown t)\n    (ignore-errors\n      (require 'claude-code-ide)\n      (save-selected-window\n        (claude-code-ide-manager-toggle-global-sidebar)))))\n\n(add-hook 'server-after-make-frame-hook #'my/claude-sidebar-open-maybe)\n\n(add-hook 'emacs-startup-hook #'my/claude-sidebar-open-maybe)\n\n(defun my/claude-sidebar-on-session ()\n  \"Draw the sidebar on this frame now that a session exists.\"\n  (let ((frame (selected-frame)))\n    (run-at-time 0 nil\n                 (lambda ()\n                   (when (frame-live-p frame)\n                     (with-selected-frame frame\n                       (my/claude-sidebar-open-maybe)))))))\n\n(with-eval-after-load 'claude-code-ide-session\n  (add-hook 'claude-code-ide-session-setup-hook #'my/claude-sidebar-on-session))\n\n(defun my/claude-sidebar-reachable (&rest _)\n  \"Let window motion into any manager sidebar on any frame.\"\n  (dolist (window (window-list-1 nil 'nomini t))\n    (when (and (window-parameter window 'claude-code-ide-manager-sidebar)\n               (window-parameter window 'no-other-window))\n      (set-window-parameter window 'no-other-window nil))))\n\n(add-hook 'window-configuration-change-hook #'my/claude-sidebar-reachable)\n\n(defvar-local my/claude--transcript-path nil\n  \"Transcript the Claude session in this buffer is writing.\nThe only exact handle between a running session and its file on disk:\nclaude-code-ide's session id is its own and the CLI never sees it, while\nthe CLI's id is not something the package is told. The hooks know both, so\nthey carry the path across. `my/claude-chats' uses it to recognise that a\nrow in the history and a row in the session list are one conversation.\")\n\n(defun my/claude-set-session-state (buffer-name state &optional transcript)\n  \"Record STATE as the agent state of the Claude session in BUFFER-NAME.\nTRANSCRIPT, when given, is the conversation's file on disk.\n\nThe entry point for the Claude Code hooks in the claude-code module, which\nreach it over emacsclient: the CLI knows it has stopped, or wants an\nanswer, and only Emacs can draw that beside the session's name.\n\nThe sidebar refreshes itself from here — claude-code-ide-manager advises\nthe setter — so there is nothing to redraw by hand.\n\nTolerant on purpose. It is called from outside Emacs with a name that may\nbelong to a session that has since exited, and the setter it wraps errors\non a buffer that is not a live session.\"\n  (let ((buf (get-buffer buffer-name)))\n    (when (and buf\n               (fboundp 'claude-code-ide-session-idle-set-agent-state)\n               (fboundp 'claude-code-ide-session-buffer-p))\n      (with-current-buffer buf\n        (when (claude-code-ide-session-buffer-p buf)\n          (when (and transcript (not (string-empty-p transcript)))\n            (setq-local my/claude--transcript-path transcript))\n          (claude-code-ide-session-idle-set-agent-state state))))))\n\n(defun my/claude-send-region-or-file ()\n  \"Send the region to Claude, or a reference to this file when nothing is selected.\"\n  (interactive)\n  (if (use-region-p)\n      (claude-code-ide-send-prompt\n       (buffer-substring-no-properties (region-beginning) (region-end)))\n    (claude-code-ide-send-current-file-line-reference)))\n\n(defun my/claude--diagnostic-at-point ()\n  \"Text of the diagnostic under point, from flycheck or flymake.\"\n  (or (when-let* ((errs (and (bound-and-true-p flycheck-mode)\n                            (fboundp 'flycheck-overlay-errors-at)\n                            (flycheck-overlay-errors-at (point)))))\n        (mapconcat #'flycheck-error-message errs \"\\n\"))\n      (when-let* ((diags (and (bound-and-true-p flymake-mode)\n                              (fboundp 'flymake-diagnostics)\n                              (flymake-diagnostics (point)))))\n        (mapconcat #'flymake-diagnostic-text diags \"\\n\"))))\n\n(defun my/claude-fix-diagnostic ()\n  \"Ask Claude to fix the diagnostic under point.\nclaude-code-ide has no equivalent of claude-code.el's\n`claude-code-fix-diagnostic'; it exposes the diagnostics to Claude as an\nMCP tool instead, which is the right primitive but not a command. This is\nthe command, built on `claude-code-ide-send-prompt' — the session already\nknows which file and line the point is on, so the prompt only has to carry\nthe message itself.\"\n  (interactive)\n  (let ((msg (my/claude--diagnostic-at-point)))\n    (unless msg\n      (user-error \"No diagnostic under point\"))\n    (claude-code-ide-send-prompt\n     (format \"Fix this error at %s:%d\\n\\n%s\"\n             (if buffer-file-name\n                 (file-name-nondirectory buffer-file-name)\n               (buffer-name))\n             (line-number-at-pos)\n             msg))))\n\n(require 'gptel)\n\n(setq gptel-default-mode 'markdown-mode\n      gptel-model 'claude-sonnet-4-5-20250929\n      gptel-backend (gptel-make-anthropic \"Claude\"\n                      :stream t\n                      :key (lambda ()\n                             (or (auth-source-pick-first-password\n                                  :host \"api.anthropic.com\" :user \"apikey\")\n                                 (getenv \"ANTHROPIC_API_KEY\")))))\n\n(defvar my/ai-drawer-width 0.4\n  \"Fraction of the frame width the AI drawer occupies.\")\n\n(defun my/ai-gptel-buffer-p (buffer &optional _alist)\n  \"Non-nil when BUFFER has gptel-mode turned on.\n\nA predicate rather than the `(derived-mode . gptel-mode)' condition this\nrule used to carry, which never matched anything: gptel-mode is a minor\nmode, and that condition tests the major mode -- so a chat buffer is\nmarkdown-mode with gptel-mode on top, and the rule looked right while\nsilently doing nothing. gptel windows have been landing wherever the window\ntree had room this whole time.\"\n  (let ((buf (get-buffer buffer)))\n    (and (buffer-live-p buf)\n         (buffer-local-value 'gptel-mode buf)\n         t)))\n\n(dolist (rule `((\"\\\\*claude chats\\\\*\" . -1)\n                (\"\\\\*claude-code\\\\[.*\\\\]\\\\*\" . 0)\n                (my/ai-gptel-buffer-p . 1)\n                (\"\\\\*claude transcript:.*\\\\*\" . 2)))\n  (add-to-list 'display-buffer-alist\n               `(,(car rule)\n                 (display-buffer-reuse-window display-buffer-in-side-window)\n                 (side . right)\n                 (slot . ,(cdr rule))\n                 (window-width . ,my/ai-drawer-width)\n                 (preserve-size . (t . nil))\n                 (window-parameters . ((no-delete-other-windows . t))))))\n\n(defvar my/ai-full-frame-width 90\n  \"Frame width below which AI buffers take the whole frame instead of the drawer.\")\n\n(defun my/ai-buffer-p (buffer)\n  \"Non-nil when BUFFER is one of the drawer's AI buffers.\"\n  (let* ((buf (get-buffer buffer))\n         (name (and (buffer-live-p buf) (buffer-name buf))))\n    (and name\n         (or (my/ai-gptel-buffer-p buf)\n             (string-prefix-p \"*claude\" name))\n         t)))\n\n(defun my/ai-cramped-frame-p (buffer &optional _alist)\n  \"Non-nil when BUFFER is an AI buffer and this frame is too narrow to share.\"\n  (and (my/ai-buffer-p buffer)\n       (< (frame-width) my/ai-full-frame-width)))\n\n(add-to-list 'display-buffer-alist\n             '(my/ai-cramped-frame-p\n               (display-buffer-reuse-window display-buffer-full-frame)))\n\n(defun my/ai-drawer-close ()\n  \"Close the AI drawer, leaving the sessions running behind it.\nDeliberately narrower than `window-toggle-side-windows', which would take\nthe bottom terminal down with it.\"\n  (interactive)\n  (dolist (win (window-list))\n    (when (and (window-parameter win 'window-side)\n               (or (my/ai-gptel-buffer-p (window-buffer win))\n                   (string-prefix-p \"*claude\" (buffer-name (window-buffer win)))))\n      (delete-window win))))")

(work/load-module "plugins/ui/dashboard.nix" '(dashboard)
  "(require 'dashboard)\n\n(setq dashboard-startup-banner (expand-file-name \"banner.txt\" user-emacs-directory)\n      dashboard-banner-logo-title \"Made with ❤️\"\n      dashboard-center-content t\n      dashboard-vertically-center-content t\n      dashboard-show-shortcuts t\n      dashboard-set-heading-icons t\n      dashboard-set-file-icons t\n      dashboard-icon-type 'nerd-icons\n      dashboard-items '((recents . 12)\n                        (projects . 8)\n                        (bookmarks . 5))\n      dashboard-projects-switch-function #'projectile-persp-switch-project\n      dashboard-projects-backend 'projectile)\n\n(unless (fboundp 'projectile-persp-switch-project)\n  (setq dashboard-projects-switch-function #'projectile-switch-project-by-name))\n\n(setq dashboard-heading-icons\n      '((todo      . \"nf-oct-checklist\")\n        (config    . \"nf-oct-gear\")\n        (recents   . \"nf-oct-history\")\n        (projects  . \"nf-oct-rocket\")\n        (bookmarks . \"nf-oct-bookmark\")\n        (agenda    . \"nf-oct-calendar\")\n        (registers . \"nf-oct-database\")))\n\n(defun my/dashboard--row-icon (name)\n  \"Row icon NAME plus its trailing space, or the blank of the same width.\nTwo columns either way. A row with no icon still has to occupy the width\nof one, or the text in this section hangs left of the text in the next.\"\n  (let ((icon (and name\n                   (dashboard-display-icons-p)\n                   (ignore-errors\n                     (dashboard-octicon name :height 1.0 :v-adjust 0.0)))))\n    (if (and (stringp icon) (not (string-empty-p icon)))\n        (concat icon \" \")\n      \"  \")))\n\n(defun my/dashboard--row (icon text)\n  \"TEXT as a section row: dashboard's indent, then ICON, then TEXT.\"\n  (concat (make-string (or standard-indent tab-width 4) ?\\s)\n          (my/dashboard--row-icon icon)\n          text))\n\n(defvar avy-all-windows)\n\n(defun my/dashboard-jump-to-entry ()\n  \"Label every dashboard entry with an avy hint and jump to the one picked.\"\n  (interactive)\n  (require 'avy)\n  (let ((avy-all-windows nil))\n    (avy-jump \"^ \\\\{2,\\\\}[^ \\n]\")))\n\n(defun my/dashboard-open-at-point ()\n  \"Act on the dashboard entry at point, whatever kind it is.\n\nNot `(key-binding (kbd \\\"RET\\\"))'. dashboard-mode-map binds RET to\n`dashboard-return', but evil's normal state sits above the major mode map\nand answers with `evil-ret', which only moves down a line -- so asking\nwhat RET does gets the wrong answer here, and plain RET on an entry has\nnever opened anything either.\n\nThe row's own keymap comes first, for a row that carries one as a text\nproperty; then dashboard's own command; then the plain widget.\"\n  (interactive)\n  (let* ((km (get-char-property (point) 'keymap))\n         (own (and (keymapp km) (lookup-key km (kbd \"RET\"))))\n         (cmd (cond ((commandp own) own)\n                    ((fboundp 'dashboard-return) #'dashboard-return)\n                    (t #'widget-button-press))))\n    (call-interactively cmd)))\n\n(defun my/dashboard-jump-and-open ()\n  \"Pick a dashboard entry by hint and act on it.\"\n  (interactive)\n  (when (my/dashboard-jump-to-entry)\n    (my/dashboard-open-at-point)))\n\n(with-eval-after-load 'dashboard\n  (require 'evil nil t)\n  (if (fboundp 'evil-define-key*)\n      (evil-define-key* 'normal dashboard-mode-map\n        (kbd \"o\") #'my/dashboard-jump-and-open\n        (kbd \"O\") #'my/dashboard-jump-to-entry\n        (kbd \"RET\") #'my/dashboard-open-at-point)\n    (define-key dashboard-mode-map (kbd \"o\") #'my/dashboard-jump-and-open)\n    (define-key dashboard-mode-map (kbd \"O\") #'my/dashboard-jump-to-entry)))\n\n(defvar my/dashboard-sections\n  '((recents   \"r\" \"Recent Files:\")\n    (projects  \"p\" \"Projects:\")\n    (bookmarks \"m\" \"Bookmarks:\"))\n  \"Each section: its symbol, the key that jumps to it, and its heading.\")\n\n(defun my/dashboard--jump-to (heading)\n  \"Move point to the first line under HEADING.\"\n  (goto-char (point-min))\n  (when (search-forward heading nil t)\n    (beginning-of-line)\n    (forward-line 1)))\n\n(setq dashboard-item-shortcuts\n      (mapcar (lambda (s) (cons (nth 0 s) (nth 1 s))) my/dashboard-sections))\n\n(defun my/dashboard-bind-sections (&rest _)\n  \"Bind each section key to a jump to that section's heading.\"\n  (dolist (section my/dashboard-sections)\n    (let* ((key (kbd (nth 1 section)))\n           (heading (nth 2 section))\n           (command (lambda ()\n                      (interactive)\n                      (my/dashboard--jump-to heading))))\n      (define-key dashboard-mode-map key command)\n      (when (fboundp 'evil-define-key*)\n        (evil-define-key* 'normal dashboard-mode-map key command)))))\n\n(with-eval-after-load 'dashboard\n  (require 'evil nil t)\n  (my/dashboard-bind-sections)\n  (advice-add 'dashboard-insert-startupify-lists\n              :after #'my/dashboard-bind-sections))\n\n(dashboard-setup-startup-hook)\n\n(defun my/dashboard-home ()\n  \"Switch to the dashboard, building it only if it is not there.\n\n`dashboard-open' regenerates the buffer -- re-reading the recent-file and\nproject lists and redrawing the banner. Reusing an existing one instead\nmeans returning here is instant and the contents stay put while you work,\nrather than reshuffling under you every time.\"\n  (interactive)\n  (if (get-buffer \"*dashboard*\")\n      (switch-to-buffer \"*dashboard*\")\n    (dashboard-open)))\n\n(defun my/dashboard--ordinary-windows (frame)\n  \"FRAME's windows that are not side windows.\"\n  (seq-remove (lambda (w) (window-parameter w 'window-side))\n              (window-list frame)))\n\n(defun my/dashboard--flatten (frame window)\n  \"Leave FRAME showing one ordinary window, WINDOW for preference.\n\nOrdinary windows only. This used to lift `ignore-window-parameters' and\ncall `delete-other-windows', which takes the side windows with it -- and\nnow that the Claude sidebar is opened on every frame, that meant opening a\nframe, drawing the sidebar and deleting it again. The duplicate this exists\nto collapse is a second ordinary pane, so a side window is not its\nbusiness.\n\n`delete-window' per window rather than `delete-other-windows' on the one to\nkeep, for the same reason: there is no way to tell the latter to spare\nthem. Failures are swallowed one at a time -- a signal here abandons the\nrest of the frame hook, and a pane that will not go is worth less than the\nhooks behind this one.\n\nThe window that stays is an ordinary one wherever the frame has one, and\nis stripped of its side parameters where it does not: a survivor keeps\nthem, and a frame rooted on a dedicated slot leaves which-key nowhere to\nput its panel.\"\n  (let ((keep (or (seq-find (lambda (w) (not (window-parameter w 'window-side)))\n                            (cons window (window-list frame)))\n                  window)))\n    (when (window-parameter keep 'window-side)\n      (set-window-parameter keep 'window-side nil)\n      (set-window-parameter keep 'slot nil)\n      (set-window-dedicated-p keep nil))\n    (dolist (w (my/dashboard--ordinary-windows frame))\n      (unless (eq w keep)\n        (ignore-errors (delete-window w))))))\n\n(defun my/dashboard-on-client-frame ()\n  \"Show the dashboard alone in a client frame that has nothing else to show.\n\nTwo things had to be handled. The frame can arrive already displaying the\ndashboard -- `dashboard-setup-startup-hook' points `initial-buffer-choice'\nat it, and server.el honours that -- so matching only *scratch* missed\nthose and matching both is what makes this idempotent.\n\nAnd the frame can arrive split, which is what produced two windows each\nshowing the dashboard with its own modeline. `delete-other-windows' leaves\nthe one window a home screen should be. A frame opened on a file is\nuntouched: its buffer is neither of these.\n\nWhat the frame is showing, not `current-buffer'. Inside\n`server-after-make-frame-hook' the current buffer is \\\" *server*\\\" --\nserver.el's own -- so the guard below never matched and the flattening\nnever ran, which is how the split dashboard came back.\n\nAnd what its ORDINARY windows are showing, not its selected one. The\nClaude sidebar is opened on this same hook, ahead of this function; it is\na side window, and while it was also left selected the question \\\"what is\nthis frame showing\\\" was answered with the sidebar. That is neither\n*scratch* nor the dashboard, so this declined, and the frame opened on an\nempty strip with *scratch* behind it.\"\n  (let* ((frame (selected-frame))\n         (ordinary (my/dashboard--ordinary-windows frame))\n         (window (or (car (memq (frame-selected-window frame) ordinary))\n                     (car ordinary)\n                     (frame-selected-window frame)))\n         (shown (buffer-name (window-buffer window))))\n    (cond\n     ((and (cdr ordinary)\n           (seq-every-p (lambda (w)\n                          (equal (buffer-name (window-buffer w)) \"*dashboard*\"))\n                        ordinary))\n      (my/dashboard--flatten frame window))\n     ((frame-parameter frame 'my/window-state-replayed) nil)\n     ((member shown '(\"*scratch*\" \"*dashboard*\"))\n      (with-selected-window window (my/dashboard-home))\n      (my/dashboard--flatten frame window)\n      (when (window-live-p window)\n        (select-window window))))))\n\n(add-hook 'server-after-make-frame-hook #'my/dashboard-on-client-frame)\n\n(defun my/dashboard ()\n  \"Show the dashboard.\"\n  (interactive)\n  (cond\n   ((fboundp 'dashboard-open) (dashboard-open))\n   ((fboundp 'dashboard-refresh-buffer) (dashboard-refresh-buffer))\n   (t (switch-to-buffer (get-buffer-create dashboard-buffer-name)))))")

(work/load-module "plugins/ui/icons.nix" '(nerd-icons)
  "(require 'nerd-icons)\n\n(setq nerd-icons-font-family \"JetBrainsMono Nerd Font\"\n      nerd-icons-scale-factor 1.0)")

(work/load-module "plugins/ui/indents.nix" '(highlight-indent-guides)
  "(require 'highlight-indent-guides)\n\n(setq highlight-indent-guides-method 'character\n      highlight-indent-guides-character ?│\n      highlight-indent-guides-responsive nil\n      highlight-indent-guides-suppress-auto-error t\n      highlight-indent-guides-auto-enabled nil)\n\n(custom-set-faces\n `(highlight-indent-guides-character-face ((t (:foreground ,(my/tn 'bg-hl))))))\n\n(defvar my/indent-guides-excluded-modes\n  '(dashboard-mode\n    gfm-mode\n    git-commit-mode\n    help-mode\n    markdown-mode\n    special-mode\n    term-mode\n    text-mode\n    treemacs-mode\n    vterm-mode\n    yaml-mode\n    yaml-ts-mode)\n  \"Modes that never get indent guides.\")\n\n(defun my/maybe-indent-guides ()\n  \"Turn guides on unless this mode is excluded.\"\n  (unless (or (apply #'derived-mode-p my/indent-guides-excluded-modes)\n              (minibufferp))\n    (highlight-indent-guides-mode 1)))\n\n(add-hook 'prog-mode-hook #'my/maybe-indent-guides)\n\n(add-hook 'conf-mode-hook #'my/maybe-indent-guides)")

(work/load-module "plugins/ui/linenumbers.nix" '()
  "(require 'adaptive-wrap)\n\n(add-hook 'evil-insert-state-entry-hook\n          (lambda () (when display-line-numbers\n                       (setq-local display-line-numbers t))))\n\n(add-hook 'evil-insert-state-exit-hook\n          (lambda () (when display-line-numbers\n                       (setq-local display-line-numbers 'relative))))\n\n(defun my/prose-setup ()\n  \"The prose layout: no gutter, soft wrap, hanging indent.\"\n  (setq-local display-line-numbers nil\n              truncate-lines nil\n              word-wrap t)\n  (visual-line-mode 1)\n  (adaptive-wrap-prefix-mode 1)\n  (when (fboundp 'treesit-fold-indicators-mode)\n    (treesit-fold-indicators-mode -1))\n  (when (fboundp 'highlight-indent-guides-mode)\n    (highlight-indent-guides-mode -1)))\n\n(dolist (hook '(markdown-mode-hook\n                gfm-mode-hook\n                text-mode-hook\n                git-commit-setup-hook))\n  (add-hook hook #'my/prose-setup))")

(work/load-module "plugins/ui/notifications.nix" '(alert)
  "(require 'alert)\n\n(setq alert-fade-time 5)\n\n(setq alert-default-style 'libnotify)\n\n(defun my/notify (title message &optional severity)\n      \"Send MESSAGE under TITLE at SEVERITY, defaulting to `normal'.\"\n      (alert message :title title :severity (or severity 'normal)))\n\n(defun my/notify-compilation-finished (buffer status)\n      \"Notify that compilation in BUFFER ended with STATUS.\"\n      (my/notify (format \"Emacs — %s\" (buffer-name buffer))\n                 (string-trim status)\n                 (if (string-match-p \"finished\" status) 'normal 'high)))\n\n(add-hook 'compilation-finish-functions #'my/notify-compilation-finished)\n\n(setq message-truncate-lines nil\n          set-message-functions '(inhibit-message set-multi-message set-minibuffer-message)\n          inhibit-message-regexps '(\"^Wrote \" \"^Saving file\"))")

(work/load-module "plugins/ui/statusline.nix" '(doom-modeline flycheck hide-mode-line)
  "(require 'cl-lib)\n\n(require 'doom-modeline)\n\n(require 'flycheck)\n\n(setq doom-modeline-height 25\n          doom-modeline-bar-width 0\n          doom-modeline-icon t\n          doom-modeline-buffer-file-name-style 'relative-from-project\n          doom-modeline-minor-modes nil\n          doom-modeline-enable-word-count nil\n          doom-modeline-buffer-encoding t\n          doom-modeline-checker-simple-format nil\n          doom-modeline-modal nil\n          doom-modeline-percent-position '(-3 \"%p\")\n          doom-modeline-vcs-max-length 45)\n\n(custom-set-faces\n     `(mode-line          ((t (:background \"#1a1b26\" :foreground ,(my/tn 'fg)\n                               :box nil :overline nil :underline nil))))\n     `(mode-line-active   ((t (:background \"#1a1b26\" :foreground ,(my/tn 'fg)\n                               :box nil :overline nil :underline nil))))\n     `(mode-line-inactive ((t (:background \"#1a1b26\" :foreground ,(my/tn 'fg)\n                               :box nil :overline nil :underline nil)))))\n\n(defun my/wide-window-p ()\n      \"Non-nil when this window is wide enough for the optional segments.\"\n      (> (window-width) 80))\n\n(doom-modeline-def-segment my/edge-bar\n      (propertize \"▊\" 'face `(:foreground ,(my/tn 'blue))))\n\n(doom-modeline-def-segment my/mode-dot\n      (let ((color (cond ((evil-insert-state-p)   (my/tn 'green))\n                         ((evil-visual-state-p)   (my/tn 'blue))\n                         ((evil-replace-state-p)  (my/tn 'violet))\n                         ((evil-operator-state-p) (my/tn 'red))\n                         ((evil-motion-state-p)   (my/tn 'blue))\n                         ((evil-emacs-state-p)    (my/tn 'magenta))\n                         (t                       (my/tn 'red)))))\n        (propertize \" ● \" 'face `(:foreground ,color))))\n\n(doom-modeline-def-segment my/filesize\n      (when (and (buffer-file-name) (my/wide-window-p))\n        (propertize (concat \" \" (file-size-human-readable (buffer-size)) \" \")\n                    'face 'mode-line)))\n\n(doom-modeline-def-segment my/filename\n      (propertize (concat \" \" (doom-modeline-buffer-file-name) \" \")\n                  'face `(:foreground ,(my/tn 'magenta) :weight bold)))\n\n(doom-modeline-def-segment my/progress\n      (propertize (format-mode-line '(\"%p\")) 'face `(:foreground ,(my/tn 'fg) :weight bold)))\n\n(doom-modeline-def-segment my/diagnostics\n      (when (bound-and-true-p flycheck-mode)\n        (let* ((counts (flycheck-count-errors flycheck-current-errors))\n               (errors (or (alist-get 'error counts) 0))\n               (warnings (or (alist-get 'warning counts) 0))\n               (infos (or (alist-get 'info counts) 0)))\n          (concat\n           (when (> errors 0)\n             (propertize (format \" %d \" errors)\n                         'face `(:foreground ,(my/tn 'red))))\n           (when (> warnings 0)\n             (propertize (format \" %d \" warnings)\n                         'face `(:foreground ,(my/tn 'yellow))))\n           (when (> infos 0)\n             (propertize (format \" %d \" infos)\n                         'face `(:foreground ,(my/tn 'cyan))))))))\n\n(doom-modeline-def-segment my/encoding\n      (when (and (my/wide-window-p) buffer-file-coding-system)\n        (propertize (concat \" \" (upcase (symbol-name\n                                        (coding-system-base buffer-file-coding-system))) \" \")\n                    'face `(:foreground ,(my/tn 'green) :weight bold))))\n\n(doom-modeline-def-segment my/fileformat\n      (when (and (my/wide-window-p) buffer-file-coding-system)\n        (propertize\n         (format \" %s \"\n                 (pcase (coding-system-eol-type buffer-file-coding-system)\n                   (1 \"DOS\") (2 \"MAC\") (_ \"UNIX\")))\n         'face `(:foreground ,(my/tn 'green) :weight bold))))\n\n(doom-modeline-def-segment my/branch\n      (when (and (buffer-file-name) (stringp vc-mode))\n          (let ((branch (substring-no-properties\n                         (string-trim\n                          (replace-regexp-in-string \"\\\\`[ ]*Git[:-]\" \"\" vc-mode)))))\n          (unless (string-empty-p branch)\n            (propertize (concat \"  \"\n                                (truncate-string-to-width\n                                 branch doom-modeline-vcs-max-length nil nil \"…\")\n                                \" \")\n                        'face `(:foreground ,(my/tn 'violet) :weight bold))))))\n\n(defvar-local my/diff-counts nil\n      \"Cached (added changed removed) line counts for this buffer.\")\n\n(defun my/diff-refresh-counts (&rest _)\n      \"Recompute `my/diff-counts' from diff-hl's overlays.\"\n      (setq my/diff-counts\n            (let ((added 0) (changed 0) (removed 0))\n              (dolist (o (overlays-in (point-min) (point-max)))\n                (when (overlay-get o 'diff-hl-hunk)\n                  (let ((lines (max 1 (count-lines (overlay-start o) (overlay-end o)))))\n                    (pcase (overlay-get o 'diff-hl-hunk-type)\n                      ('insert (cl-incf added lines))\n                      ('change (cl-incf changed lines))\n                      ('delete (cl-incf removed 1))))))\n              (list added changed removed))))\n\n(with-eval-after-load 'diff-hl\n      (advice-add 'diff-hl--update-overlays :after #'my/diff-refresh-counts))\n\n(doom-modeline-def-segment my/diff\n      (when (and my/diff-counts (my/wide-window-p))\n        (cl-destructuring-bind (added changed removed) my/diff-counts\n          (concat\n           (when (> added 0)\n             (propertize (format \" %d \" added)\n                         'face `(:foreground ,(my/tn 'green))))\n           (when (> changed 0)\n             (propertize (format \"󰝤 %d \" changed)\n                         'face `(:foreground ,(my/tn 'orange))))\n           (when (> removed 0)\n             (propertize (format \" %d \" removed)\n                         'face `(:foreground ,(my/tn 'red))))))))\n\n(defvar my/status-claude-tokens 0\n      \"Tokens Claude Code has spent today. Written by `my/status-update-claude'.\")\n\n(defvar my/status--procs (make-hash-table :test 'equal)\n      \"Live status subprocesses, keyed by name, so they cannot stack up.\")\n\n(defun my/status--sentinel (proc _event)\n      \"Hand PROC's output to the callback stashed on it, then repaint.\"\n      (unless (process-live-p proc)\n        (let ((cb (process-get proc 'my/status-callback))\n              (out (with-current-buffer (process-buffer proc)\n                     (string-trim (buffer-string)))))\n          (kill-buffer (process-buffer proc))\n          (when cb (funcall cb out))\n          (force-mode-line-update t))))\n\n(defun my/status--run (key command callback)\n      \"Run COMMAND, then call CALLBACK with its trimmed stdout.\nAsynchronous, so redisplay never waits on it. A second run for KEY is\nskipped while the first is still going: a hung mu should degrade to a\nstale badge, not to an unbounded pile of processes.\"\n      (let ((live (gethash key my/status--procs)))\n        (unless (and live (process-live-p live))\n          (let ((proc (make-process\n                       :name (format \"status-%s\" key)\n                       :buffer (generate-new-buffer (format \" *status-%s*\" key))\n                       :command command\n                       :noquery t\n                       :sentinel #'my/status--sentinel)))\n            (process-put proc 'my/status-callback callback)\n            (puthash key proc my/status--procs)))))\n\n(defun my/status-update-claude ()\n      \"Refresh today's Claude token total.\"\n      (my/status--run\n       \"claude\"\n       (list (expand-file-name \"helpers/claude-usage-today\" user-emacs-directory))\n       (lambda (out)\n         (setq my/status-claude-tokens\n               (or (ignore-errors\n                     (alist-get 'billable\n                                (json-parse-string out :object-type 'alist)))\n                   0)))))\n\n(defun my/status--compact (n)\n      \"N as a short human number: 12, 4k, 1.2M.\"\n      (cond ((>= n 1000000) (format \"%.1fM\" (/ n 1000000.0)))\n            ((>= n 1000) (format \"%dk\" (/ n 1000)))\n            (t (format \"%d\" n))))\n\n(defun my/status-claude--states ()\n      \"The agent state of every live Claude session, `idle' when it has none.\"\n      (when (fboundp 'claude-code-ide-session-buffer-p)\n        (delq nil\n              (mapcar (lambda (buffer)\n                        (when (ignore-errors\n                                (claude-code-ide-session-buffer-p buffer))\n                          (or (buffer-local-value\n                               'claude-code-ide-session-agent-state buffer)\n                              'idle)))\n                      (buffer-list)))))\n\n(defun my/status-claude ()\n      \"Live Claude sessions and what the day has cost.\n\n    The count is coloured by the session that most wants you: one waiting on an\n    answer or stopped on a failure outranks one still working, which outranks a\n    row of idle sessions. Which is the same order the manager sidebar draws its\n    glyphs in, so the strip and the sidebar never disagree.\n\n    The token total is the day across every project, not this session -- the\n    per-session numbers are in the status line under Claude's own prompt, which\n    is where you are looking when they matter.\"\n      (let* ((states (my/status-claude--states))\n             (n (length states))\n             (face (cond ((seq-some (lambda (s) (memq s '(needs-input failed))) states)\n                          'warning)\n                         ((memq 'working states) 'success)\n                         (t 'shadow))))\n        (concat (propertize (format \"✳ %d\" n)\n                            'face (if (> n 0) face 'shadow))\n                (when (> my/status-claude-tokens 0)\n                  (propertize (format \" %s\" (my/status--compact my/status-claude-tokens))\n                              'face 'shadow)))))\n\n(with-eval-after-load 'claude-code-ide\n      (advice-add 'claude-code-ide-session-idle-set-agent-state\n                  :after #'my/status-repaint))\n\n(defun my/status-count (glyph n live-face)\n      \"Render N after GLYPH, in LIVE-FACE when non-zero and dimmed at zero.\"\n      (propertize (format \"%s %d\" glyph n)\n                  'face (if (> n 0)\n                            (if (facep live-face) live-face 'warning)\n                          'shadow)))\n\n(defun my/status-repaint (&rest _)\n      \"Repaint every mode line and tab bar on every frame.\"\n      (force-mode-line-update t))\n\n(defun my/status-string () \"Work coding status.\" (my/status-claude))\n\n(defvar my/status--timers nil)\n\n(unless my/status--timers (setq my/status--timers (list (run-with-timer 12 120 #'my/status-update-claude))))\n\n(defun my/tab-bar-status ()\n      \"Ambient status for `tab-bar-format', at the left of the bar.\"\n      (let ((s (my/status-string)))\n        (unless (string-empty-p s)\n          `((my/status menu-item ,(concat \" \" s) ignore)))))\n\n(setq tab-bar-format '(my/tab-bar-status)\n          tab-bar-show t\n          tab-bar-new-button-show nil\n          tab-bar-close-button-show nil)\n\n(tab-bar-mode 1)\n\n(doom-modeline-def-modeline 'my/eviline\n      '(my/edge-bar my/mode-dot my/filesize my/filename buffer-position\n        my/progress my/diagnostics)\n      '(my/encoding my/fileformat my/branch my/diff my/edge-bar))\n\n(defun my/set-eviline ()\n      \"Install the eviline layout as the default modeline.\"\n      (doom-modeline-set-modeline 'my/eviline 'default))\n\n(add-hook 'doom-modeline-mode-hook #'my/set-eviline)\n\n(doom-modeline-mode 1)\n\n(my/set-eviline)\n\n(require 'hide-mode-line)\n\n(dolist (hook '(treemacs-mode-hook\n                    vterm-mode-hook\n                    help-mode-hook\n                    dashboard-mode-hook\n                    claude-code-ide-manager-mode-hook\n                    my/claude-chats-mode-hook\n                    lsp-treemacs-error-list-mode-hook))\n      (add-hook hook #'hide-mode-line-mode))")

(work/load-module "plugins/ui/twilight.nix" '(focus olivetti)
  "(require 'focus)\n\n(setq focus-dimness 20)\n\n(require 'olivetti)\n\n(setq olivetti-body-width 100\n      olivetti-minimum-body-width 72\n      olivetti-style 'fancy)\n\n(defun my/toggle-twilight ()\n  \"Toggle the dimmed-surroundings view.\"\n  (interactive)\n  (focus-mode 'toggle))\n\n(defun my/toggle-zen ()\n  \"Toggle centred prose mode.\"\n  (interactive)\n  (olivetti-mode 'toggle))")

(work/load-module "plugins/ui/virt-column.nix" '()
  "(setq-default fill-column 80)\n\n(custom-set-faces\n `(fill-column-indicator ((t (:foreground ,(my/tn 'bg-hl) :background unspecified)))))\n\n(defvar my/fill-column-excluded-modes\n  '(dashboard-mode\n    gfm-mode\n    git-commit-mode\n    help-mode\n    lsp-treemacs-error-list-mode\n    man-common\n    markdown-mode\n    special-mode\n    term-mode\n    text-mode\n    treemacs-mode\n    vterm-mode)\n  \"Modes that never draw a column guide.\")\n\n(defun my/maybe-fill-column-indicator ()\n  \"Draw the guide unless this mode is excluded.\"\n  (unless (or (apply #'derived-mode-p my/fill-column-excluded-modes)\n              (minibufferp))\n    (display-fill-column-indicator-mode 1)))\n\n(add-hook 'prog-mode-hook #'my/maybe-fill-column-indicator)\n\n(add-hook 'conf-mode-hook #'my/maybe-fill-column-indicator)")

(work/load-module "plugins/version-control/git.nix" '(blamer browse-at-remote diff-hl difftastic forge git-link git-timemachine magit magit-delta)
  "(with-eval-after-load 'magit\n  (require 'difftastic nil t)\n  (when (fboundp 'difftastic-magit-diff)\n    (setq difftastic-requested-window-width-function\n          (lambda () (- (window-width) 4)))))\n\n(setq magit-diff-refine-hunk 'all\n          magit-save-repository-buffers 'dontask\n          magit-display-buffer-function #'magit-display-buffer-fullframe-status-v1\n          magit-bury-buffer-function #'magit-restore-window-configuration\n          magit-commit-show-diff t\n          git-commit-summary-max-length 72)\n\n(setq magit-delta-delta-executable \"delta\"\n          magit-delta-default-dark-theme \"Nord\")\n\n(with-eval-after-load 'magit-delta\n      (setq magit-delta-delta-args\n            (append magit-delta-delta-args\n                    (list \"--minus-style\"      (concat \"syntax \" (my/tn 'diff-del))\n                          \"--minus-emph-style\" (concat \"syntax \" (my/tn 'diff-del-hl))\n                          \"--plus-style\"       (concat \"syntax \" (my/tn 'diff-add))\n                          \"--plus-emph-style\"  (concat \"syntax \" (my/tn 'diff-add-hl))))))\n\n(add-hook 'magit-mode-hook #'magit-delta-mode)\n\n(setq ediff-window-setup-function #'ediff-setup-windows-plain\n          ediff-split-window-function #'split-window-horizontally\n          ediff-merge-split-window-function #'split-window-horizontally\n          ediff-highlight-all-diffs t)\n\n(custom-set-faces\n     `(ediff-current-diff-A ((t (:background ,(my/tn 'diff-del) :extend t))))\n     `(ediff-fine-diff-A    ((t (:background ,(my/tn 'diff-del-hl) :extend t))))\n     `(ediff-current-diff-B ((t (:background ,(my/tn 'diff-add) :extend t))))\n     `(ediff-fine-diff-B    ((t (:background ,(my/tn 'diff-add-hl) :extend t))))\n     `(ediff-current-diff-C ((t (:background ,(my/tn 'prompt) :extend t))))\n     `(ediff-fine-diff-C    ((t (:background ,(my/tn 'bg-hl) :foreground ,(my/tn 'yellow) :weight bold :extend t))))\n     `(ediff-even-diff-A ((t (:background ,(my/tn 'bg-hl) :extend t))))\n     `(ediff-even-diff-B ((t (:background ,(my/tn 'bg-hl) :extend t))))\n     `(ediff-even-diff-C ((t (:background ,(my/tn 'bg-hl) :extend t))))\n     `(ediff-odd-diff-A  ((t (:background ,(my/tn 'bg-dark) :extend t))))\n     `(ediff-odd-diff-B  ((t (:background ,(my/tn 'bg-dark) :extend t))))\n     `(ediff-odd-diff-C  ((t (:background ,(my/tn 'bg-dark) :extend t)))))\n\n(defvar my/ediff-saved-winconf nil\n      \"Window configuration from before the current ediff session.\")\n\n(defun my/ediff-save-winconf ()\n      (setq my/ediff-saved-winconf (current-window-configuration)))\n\n(defun my/ediff-restore-winconf ()\n      (when my/ediff-saved-winconf\n        (set-window-configuration my/ediff-saved-winconf)\n        (setq my/ediff-saved-winconf nil)))\n\n(add-hook 'ediff-before-setup-hook #'my/ediff-save-winconf)\n\n(add-hook 'ediff-quit-hook #'my/ediff-restore-winconf t)\n\n(setq forge-add-default-bindings nil)\n\n(with-eval-after-load 'magit\n      (require 'forge))\n\n(require 'diff-hl)\n\n(require 'diff-hl-margin)\n\n(require 'diff-hl-flydiff)\n\n(require 'diff-hl-dired)\n\n(require 'diff-hl-show-hunk)\n\n(setq diff-hl-margin-symbols-alist\n          '((insert  . \"│\")\n            (change  . \"│\")\n            (delete  . \"_\")\n            (unknown . \"┆\")\n            (ignored . \"┆\"))\n          diff-hl-draw-borders nil)\n\n(defun my/vc-local-buffer-p ()\n      \"Non-nil when this buffer is a local file, not one over tramp.\"\n      (and buffer-file-name (not (file-remote-p buffer-file-name))))\n\n(defun my/diff-hl-unless-remote ()\n      (when (my/vc-local-buffer-p) (diff-hl-mode 1)))\n\n(define-globalized-minor-mode my/global-diff-hl-mode\n      diff-hl-mode my/diff-hl-unless-remote)\n\n(my/global-diff-hl-mode 1)\n\n(diff-hl-margin-mode 1)\n\n(setq diff-hl-flydiff-delay 0.3)\n\n(diff-hl-flydiff-mode 1)\n\n(add-hook 'magit-pre-refresh-hook #'diff-hl-magit-pre-refresh)\n\n(add-hook 'magit-post-refresh-hook #'diff-hl-magit-post-refresh)\n\n(add-hook 'dired-mode-hook #'diff-hl-dired-mode)\n\n(require 'blamer)\n\n(setq blamer-idle-time 0.1\n          blamer-min-offset 3\n          blamer-type 'visual\n          blamer-prettify-time-p t\n          blamer-author-formatter \"   %s, \"\n          blamer-datetime-formatter \"%s • \"\n          blamer-commit-formatter \"%s\")\n\n(custom-set-faces\n     `(blamer-face ((t (:foreground ,(my/tn 'comment) :slant italic :height 0.9)))))\n\n(defun my/blamer-unless-remote ()\n      (when (my/vc-local-buffer-p) (blamer-mode 1)))\n\n(define-globalized-minor-mode my/global-blamer-mode\n      blamer-mode my/blamer-unless-remote)\n\n(my/global-blamer-mode 1)\n\n(with-eval-after-load 'apheleia\n      (add-hook 'apheleia-post-format-hook #'blamer--clear-overlay))\n\n(defun my/blamer-render-one (orig commit-info buffer render-point &optional type)\n      \"Draw a blame overlay only for the line point is on, replacing any other.\"\n      (when (buffer-live-p buffer)\n        (with-current-buffer buffer\n          (let ((region (region-active-p)))\n            (when (or region\n                      (not (integer-or-marker-p render-point))\n                      (= (line-number-at-pos render-point t)\n                         (line-number-at-pos (point) t)))\n              (unless region (blamer--clear-overlay))\n              (funcall orig commit-info buffer render-point type))))))\n\n(with-eval-after-load 'blamer\n      (advice-add 'blamer--render-line-overlay :around #'my/blamer-render-one))\n\n(require 'browse-at-remote)\n\n(setq browse-at-remote-prefer-symbolic nil)\n\n(defun my/git-browse-repo ()\n      \"Open the repository's home page on its forge — the GO reflex.\nforge knows the remote's web URL directly; browse-at-remote is the fallback, though\nit opens the current file rather than the repository root.\"\n      (interactive)\n      (cond\n       ((fboundp 'forge-browse-remote) (forge-browse-remote))\n       ((fboundp 'browse-at-remote) (call-interactively #'browse-at-remote))\n       (t (message \"No forge remote to browse\"))))\n\n(defun my/git-add-all ()\n      \"Stage every modified and untracked file — `Git add .'.\"\n      (interactive)\n      (magit-with-toplevel\n        (magit-run-git \"add\" \"--all\" \".\"))\n      (magit-refresh)\n      (message \"Staged everything\"))\n\n(defun my/git-stage-hunk ()\n      \"Stage the hunk at point.\ndiff-hl renamed this command between releases, so try the current name first and\nfall back to staging the file through magit.\"\n      (interactive)\n      (cond\n       ((fboundp 'diff-hl-stage-dwim) (diff-hl-stage-dwim))\n       ((fboundp 'diff-hl-stage-current-hunk) (diff-hl-stage-current-hunk))\n       (t (magit-stage-buffer-file))))\n\n(defun my/git-diff-side-by-side ()\n      \"Compare side by side in ediff, the two-pane view VS Code opens on a file.\nFrom a magit buffer, compare whatever the section under point refers to -- a\ncommit, a range, the staged or unstaged changes. From a file buffer, compare the\nfile against HEAD. Anywhere else, ask for two files.\n\nmagit's own `e' would do the first of those, but the Colemak rotation moves `e'\nto a motion key in every evil-collection map, magit's included, so this is the\nway in.\"\n      (interactive)\n      (require 'magit-ediff)\n      (cond\n       ((derived-mode-p 'magit-mode) (call-interactively #'magit-ediff-dwim))\n       ((and buffer-file-name (magit-file-relative-name))\n        (magit-ediff-show-working-tree (magit-file-relative-name)))\n       (t (call-interactively #'ediff-files))))\n\n(defun my/git-toggle-signs ()\n      \"Toggle the git gutter.\"\n      (interactive)\n      (if diff-hl-mode (diff-hl-mode -1) (diff-hl-mode 1))\n      (message \"Git gutter %s\" (if diff-hl-mode \"on\" \"off\")))\n\n(defun my/git-toggle-blame ()\n      \"Toggle the inline current-line blame.\"\n      (interactive)\n      (if (bound-and-true-p blamer-mode) (blamer-mode -1) (blamer-mode 1)))")

(work/load-module "plugins/completion/corfu.nix" '(cape corfu yasnippet yasnippet-snippets)
  "(require 'corfu)\n\n(setq corfu-auto t\n      corfu-auto-prefix 2\n      corfu-auto-delay 0.2\n      corfu-count 10\n      corfu-cycle t\n      corfu-quit-no-match 'separator\n      corfu-preselect 'prompt\n      corfu-on-exact-match nil\n      corfu-scroll-margin 2)\n\n(global-corfu-mode 1)\n\n(require 'corfu-popupinfo nil t)\n\n(when (fboundp 'corfu-popupinfo-mode)\n  (setq corfu-popupinfo-delay '(0.3 . 0.2)\n        corfu-popupinfo-max-height 20)\n  (corfu-popupinfo-mode 1))\n\n(require 'yasnippet)\n\n(require 'yasnippet-snippets)\n\n(yas-global-mode 1)\n\n(require 'cape)\n\n(defun my/setup-capf ()\n  \"Completion sources for a normal editing buffer.\"\n  (setq-local completion-at-point-functions\n              (list (cape-capf-super\n                     #'cape-dabbrev\n                     #'cape-file\n                     #'cape-keyword)\n                    #'cape-abbrev)))\n\n(add-hook 'prog-mode-hook #'my/setup-capf)\n\n(add-hook 'text-mode-hook #'my/setup-capf)\n\n(setq cape-dabbrev-min-length 3\n      cape-dabbrev-check-other-buffers t\n      cape-dict-file \"/usr/share/dict/words\")\n\n(dolist (capf (list #'cape-emoji #'cape-dict))\n  (add-to-list 'completion-at-point-functions capf t))\n\n(defun my/corfu-enable-in-minibuffer ()\n  \"Enable corfu in the minibuffer when nothing else is completing there.\"\n  (when (and (not (bound-and-true-p vertico--input))\n             (not (eq (current-local-map) read-passwd-map)))\n    (setq-local corfu-auto nil)\n    (corfu-mode 1)))\n\n(add-hook 'minibuffer-setup-hook #'my/corfu-enable-in-minibuffer)\n\n(with-eval-after-load 'corfu\n  (define-key corfu-map (kbd \"C-f\") #'corfu-popupinfo-scroll-down)\n  (define-key corfu-map (kbd \"C-s\") #'corfu-popupinfo-scroll-up)\n  (define-key corfu-map (kbd \"C-SPC\") #'completion-at-point)\n  (define-key corfu-map (kbd \"C-t\") #'corfu-quit)\n  (define-key corfu-map (kbd \"TAB\") #'corfu-next)\n  (define-key corfu-map (kbd \"<tab>\") #'corfu-next)\n  (define-key corfu-map (kbd \"S-TAB\") #'corfu-previous)\n  (define-key corfu-map (kbd \"<backtab>\") #'corfu-previous)\n  (define-key corfu-map (kbd \"RET\") #'corfu-insert)\n  (define-key corfu-map (kbd \"C-e\") nil)\n  (define-key corfu-map (kbd \"C-n\") nil))\n\n(defun my/snippet-next ()\n  \"Expand the snippet at point, or jump to its next field.\"\n  (interactive)\n  (cond ((yas-active-snippets) (yas-next-field))\n        ((yas-expand) t)\n        (t (message \"No snippet here\"))))\n\n(defun my/snippet-prev ()\n  \"Jump to the previous snippet field.\"\n  (interactive)\n  (if (yas-active-snippets)\n      (yas-prev-field)\n    (message \"No active snippet\")))\n\n(evil-define-key '(insert) 'global\n  (kbd \"C-e\") #'my/snippet-next\n  (kbd \"C-n\") #'my/snippet-prev)\n\n(defun my/insert-tab ()\n  \"Complete if the popup is showing, expand a snippet if one is pending, else indent.\"\n  (interactive)\n  (cond ((and (bound-and-true-p corfu--candidates) (>= corfu--index 0)) (corfu-insert))\n        ((bound-and-true-p corfu--candidates) (corfu-next))\n        ((and (fboundp 'yas-active-snippets) (yas-active-snippets)) (yas-next-field))\n        (t (indent-for-tab-command))))\n\n(evil-define-key 'insert 'global (kbd \"TAB\") #'my/insert-tab)")

(work/load-module "plugins/completion/icons.nix" '(corfu nerd-icons-corfu)
  "(require 'corfu)\n\n(require 'nerd-icons-corfu)\n\n(add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter)\n\n(setq corfu-max-width 50\n      corfu-min-width 20\n      corfu-right-margin-width 1.0\n      corfu-left-margin-width 0.8)")

(work/load-module "plugins/notes/markview.nix" '(markdown-mode)
  "(require 'markdown-mode)\n\n(setq-default markdown-command \"pandoc\"\n      markdown-enable-math t\n      markdown-enable-wiki-links t\n      markdown-wiki-link-search-type '(project)\n      markdown-fontify-code-blocks-natively t\n      markdown-hide-urls nil\n      markdown-hide-markup t\n      markdown-header-scaling t\n      markdown-header-scaling-values '(1.5 1.425 1.35 1.275 1.2 1.125)\n      markdown-list-item-bullets '(\"•\" \"◦\" \"▪\" \"▫\"))\n\n(markdown-update-header-faces markdown-header-scaling\n                              markdown-header-scaling-values)\n\n(setq markdown-live-preview-window-function #'markdown-live-preview-window-eww\n      markdown-live-preview-delete-export 'delete-on-destroy)\n\n(add-to-list 'auto-mode-alist '(\"README\\\\.md\\\\'\" . gfm-mode))\n\n(add-to-list 'auto-mode-alist '(\"\\\\.markdown\\\\'\" . markdown-mode))\n\n(set-face-attribute 'variable-pitch nil :family \"Inter\" :height 1.0)\n\n(set-face-attribute 'fixed-pitch nil :family \"JetBrainsMono Nerd Font\" :height 1.0)\n\n(defun my/reading-layout (enable)\n  \"Use Obsidian's line height and centred line length when ENABLE is non-nil.\"\n  (setq-local line-spacing (and enable 0.5))\n  (when (fboundp 'olivetti-mode)\n    (if enable\n        (progn (setq-local olivetti-body-width 88)\n               (olivetti-mode 1))\n      (olivetti-mode -1))))\n\n(defconst my/obsidian-body-size 16.0\n  \"Obsidian's body text size in points, which on macOS is its size in px.\")\n\n(defun my/reading-scale (enable)\n  \"Read at Obsidian's body size when ENABLE is non-nil, the frame's otherwise.\"\n  (require 'face-remap)\n  (setq-local text-scale-mode-step\n              (/ my/obsidian-body-size\n                 (/ (face-attribute 'default :height nil t) 10.0)))\n  (text-scale-set (if enable 1 0)))\n\n(defun my/markdown-code-faces ()\n  \"Keep code, tables and bullets monospaced under a proportional body face.\"\n  (dolist (face '(markdown-code-face\n                  markdown-pre-face\n                  markdown-inline-code-face\n                  markdown-table-face\n                  markdown-language-keyword-face))\n    (when (facep face)\n      (set-face-attribute face nil :inherit 'fixed-pitch))))\n\n(defun my/markdown-images (enable)\n  \"Show inline images when ENABLE is non-nil, hide them otherwise.\n\nGuarded on `display-images-p' on both sides, because a terminal frame cannot\nshow an image and asking anyway signals rather than declining: markdown-mode\nraises \\\"Cannot show images\\\" on the display side, and the remove side ends in\na `clear-image-cache' that raises \\\"Window system frame should be used\\\".\n\nOnly files get images at all -- a GhostText buffer from a comment box has no\ndirectory to resolve a relative path against.\"\n  (when (display-images-p)\n    (if enable\n        (when buffer-file-name\n          (ignore-errors (markdown-display-inline-images)))\n      (markdown-remove-inline-images))))\n\n(defun my/markdown-render (enable)\n  \"Show the rendered look when ENABLE is non-nil, raw markdown otherwise.\"\n  (setq-local markdown-hide-markup (and enable t))\n  (variable-pitch-mode (if enable 1 -1))\n  (my/reading-layout enable)\n  (my/reading-scale enable)\n  (my/markdown-images enable)\n  (font-lock-flush))\n\n(defun my/markdown-toggle-render ()\n  \"Flip the buffer between the rendered look and raw markdown.\"\n  (interactive)\n  (my/markdown-render (not markdown-hide-markup))\n  (message \"Markdown %s\" (if markdown-hide-markup \"rendered\" \"raw\")))\n\n(defun my/markdown-setup ()\n  \"Open a markdown buffer in the rendered look.\"\n  (my/markdown-code-faces)\n  (my/markdown-render t))\n\n(add-hook 'markdown-mode-hook #'my/markdown-setup)\n\n(defun my/toggle-markdown-images ()\n  \"Show or hide inline images.\"\n  (interactive)\n  (my/markdown-images (not (bound-and-true-p markdown-inline-image-overlays))))\n\n(defun my/toggle-markdown-markup ()\n  \"Show or hide the markdown markup characters, leaving the rest as it is.\"\n  (interactive)\n  (setq-local markdown-hide-markup (not markdown-hide-markup))\n  (font-lock-flush)\n  (message \"Markdown markup %s\" (if markdown-hide-markup \"hidden\" \"shown\")))")

(work/load-module "plugins/keybinds/default.nix" '(popper vterm vterm-toggle)
  "(require 'vterm)\n\n(setq vterm-max-scrollback 10000\n      vterm-kill-buffer-on-exit t\n      vterm-copy-exclude-prompt t)\n\n(defun my/vterm-force-repaint ()\n  \"Make the program in this terminal redraw its whole frame.\"\n  (interactive)\n  (unless (derived-mode-p 'vterm-mode)\n    (user-error \"Not a vterm buffer\"))\n  (let ((w (window-body-width))\n        (h (window-body-height)))\n    (vterm--set-size vterm--term h (1- w))\n    (redisplay t)\n    (vterm--set-size vterm--term h w)))\n\n(define-key vterm-mode-map (kbd \"C-c C-l\") #'my/vterm-force-repaint)\n\n(add-to-list 'display-buffer-alist\n             `(\"\\\\*term:.*\\\\*\"\n               (display-buffer-reuse-window display-buffer-in-side-window)\n               (side . bottom)\n               (slot . 0)\n               (window-height . 10)\n               (dedicated . t)))\n\n(defun my/term-toggle (name)\n  \"Show or hide the bottom terminal called NAME, opened at the project root.\"\n  (let* ((bufname (format \"*term:%s*\" name))\n         (buffer (get-buffer bufname))\n         (window (and buffer (get-buffer-window buffer))))\n    (if window\n        (delete-window window)\n      (let ((default-directory (my/project-root)))\n        (unless buffer\n          (setq buffer (save-window-excursion (vterm bufname))))\n        (pop-to-buffer buffer)\n        (evil-insert-state)))))\n\n(defun my/term-main ()\n  \"Toggle the main terminal.\"\n  (interactive)\n  (my/term-toggle \"main\"))\n\n(defun my/term-extra ()\n  \"Toggle the second terminal.\"\n  (interactive)\n  (my/term-toggle \"extra\"))\n\n(defvar vterm-shell)\n\n(defun my/tuicr--gitlab-token-env ()\n  \"GITLAB_ACCESS_TOKEN for glab, when this Emacs has none of its own.\"\n  (let ((file \"/var/run/secrets/gitlab_access_token\"))\n    (when (and (not (getenv \"GITLAB_ACCESS_TOKEN\")) (file-readable-p file))\n      (list (concat \"GITLAB_ACCESS_TOKEN=\"\n                    (string-trim (with-temp-buffer\n                                   (insert-file-contents file)\n                                   (buffer-string))))))))\n\n(defun my/tuicr ()\n  \"Review the project's changes in tuicr, at the project root.\"\n  (interactive)\n  (let* ((default-directory (my/project-root))\n         (bufname (format \"*tuicr:%s*\"\n                          (file-name-nondirectory\n                           (directory-file-name default-directory))))\n         (buffer (get-buffer bufname)))\n    (if (and buffer (get-buffer-process buffer))\n        (switch-to-buffer buffer)\n      (when buffer (kill-buffer buffer))\n      (let ((vterm-shell \"tuicr\")\n            (process-environment\n             (append (list \"EDITOR=emacsclient -n\")\n                     (my/tuicr--gitlab-token-env)\n                     process-environment)))\n        (vterm bufname)))\n    (evil-emacs-state)))\n\n(require 'popper)\n\n(setq popper-reference-buffers\n      '(\"\\\\*Messages\\\\*\" \"\\\\*Warnings\\\\*\" \"\\\\*compilation\\\\*\" \"\\\\*tests\\\\*\"\n        \"\\\\*sonar\\\\*\" \"\\\\*devcontainer\\\\*\" \"\\\\*Backtrace\\\\*\"\n        help-mode helpful-mode compilation-mode)\n      popper-window-height 15)\n\n(popper-mode 1)\n\n(popper-echo-mode 1)\n\n(defun my/split-below-and-focus ()\n  \"Split downwards and move into the new window — <C-W>s<C-W>j.\"\n  (interactive)\n  (evil-window-split)\n  (other-window 1))\n\n(defun my/split-right-and-focus ()\n  \"Split rightwards and move into the new window — <C-W>v<C-W>l.\"\n  (interactive)\n  (evil-window-vsplit)\n  (other-window 1))\n\n(my/leader\n  \"SPC\" '(execute-extended-command :which-key \"run command\")\n  \"TAB\" '(evil-switch-to-windows-last-buffer :which-key \"last buffer\")\n  \"'\"   '(my/term-main :which-key \"toggle terminal\")\n  \"/\"   '(my/term-extra :which-key \"toggle extra terminal\")\n  \"c\"   '(my/add-cursors :which-key \"add cursor\")\n\n  \"a\"  '(:ignore t :which-key \"ai\")\n  \"aa\" '(my/claude-chats :which-key \"chat list (all chats + state)\")\n  \"aA\" '(claude-code-ide-manager-toggle-global-sidebar :which-key \"toggle left pane\")\n  \"ab\" '(my/claude-send-region-or-file :which-key \"send region or file\")\n  \"ac\" '(gptel :which-key \"chat\")\n  \"ad\" '(my/claude-fix-diagnostic :which-key \"fix diagnostic at point\")\n  \"af\" '(claude-code-ide-send-current-file-line-reference :which-key \"send file reference\")\n  \"ag\" '(my/claude-search :which-key \"search all conversations\")\n  \"ah\" '(my/claude-resume :which-key \"resume conversation (C-u: any project)\")\n  \"aH\" '(my/claude-view :which-key \"view transcript (C-u: any project)\")\n  \"al\" '(claude-code-ide-list-sessions :which-key \"switch live session\")\n  \"am\" '(claude-code-ide-menu :which-key \"claude menu\")\n  \"an\" '(claude-code-ide-new-session :which-key \"new session here\")\n  \"ar\" '(claude-code-ide-manager-toggle-repo-sidebar :which-key \"this repo's sessions\")\n  \"aR\" '(my/tuicr :which-key \"review changes (tuicr)\")\n  \"at\" '(my/claude-pane-toggle :which-key \"toggle right pane\")\n  \"ax\" '(my/ai-drawer-close :which-key \"close drawer\")\n  \"aq\" '(claude-code-ide-stop :which-key \"quit claude\")\n  \"as\" '(gptel-send :which-key \"send to chat\")\n  \"aw\" '(gptel-rewrite :which-key \"rewrite region\")\n\n  \"b\"  '(:ignore t :which-key \"buffers\")\n  \"bb\" '(consult-buffer :which-key \"find buffer\")\n  \"bt\" '(browser-gt-tab-jump :which-key \"find browser tab\")\n  \"bT\" '(browser-gt-tab-manager :which-key \"browser tab manager\")\n  \"bc\" '(my/clean-buffers :which-key \"clean stale buffers\")\n  \"bd\" '(kill-current-buffer :which-key \"destroy buffer\")\n  \"bh\" '(my/dashboard-home :which-key \"home buffer\")\n  \"bk\" '(my/kill-buffer-force :which-key \"kill buffer\")\n\n  \"d\"  '(:ignore t :which-key \"diagnostics\")\n  \"db\" '(my/diagnostics-buffer :which-key \"buffer diagnostics\")\n  \"dl\" '(flycheck-list-errors :which-key \"loclist\")\n  \"dq\" '(consult-compile-error :which-key \"quickfixes\")\n  \"dr\" '(lsp-treemacs-references :which-key \"references\")\n  \"dt\" '(my/diagnostics-list :which-key \"toggle trouble\")\n\n  \"e\"  '(:ignore t :which-key \"errors\")\n  \"ed\" '(my/diagnostic-at-point :which-key \"show diagnostics for cursor\")\n  \"eD\" '(my/diagnostic-explain :which-key \"show diagnostics for line\")\n  \"ee\" '(flycheck-previous-error :which-key \"prev\")\n  \"en\" '(flycheck-next-error :which-key \"next\")\n\n  \"f\"  '(:ignore t :which-key \"files\")\n  \"fd\" '(my/find-files-in-dir :which-key \"find files in dir\")\n  \"ff\" '(my/find-files :which-key \"find files\")\n  \"fr\" '(my/recent-files :which-key \"recent files\")\n  \"fR\" '(my/reload-config :which-key \"reload configuration\")\n  \"fs\" '(save-buffer :which-key \"save files\")\n  \"ft\" '(my/treemacs-toggle :which-key \"toggle filetree\")\n\n  \"g\"  '(:ignore t :which-key \"git\")\n  \"ga\" '(my/git-add-all :which-key \"add .\")\n  \"gb\" '(magit-branch-checkout :which-key \"branches\")\n  \"gB\" '(browse-at-remote :which-key \"git browse\")\n  \"gc\" '(magit-commit :which-key \"commit\")\n  \"gd\" '(magit-diff-unstaged :which-key \"diff\")\n  \"gw\" '(difftastic-magit-diff :which-key \"diff (structural)\")\n  \"gD\" '(magit-diff-buffer-file :which-key \"diff split\")\n  \"gE\" '(my/git-diff-side-by-side :which-key \"diff side by side\")\n  \"ge\" '(diff-hl-previous-hunk :which-key \"prev hunk\")\n  \"gf\" '(forge-dispatch :which-key \"forge (PRs, MRs, issues)\")\n  \"gA\" '(my/gitlab-approve-mr :which-key \"approve MR (gitlab)\")\n  \"gC\" '(forge-create-post :which-key \"comment on MR/issue\")\n  \"gM\" '(my/forge-mr-diff :which-key \"review MR diff\")\n  \"gU\" '(my/gitlab-unapprove-mr :which-key \"unapprove MR (gitlab)\")\n  \"gR\" '(my/gitlab-list-my-reviews :which-key \"MRs awaiting my review\")\n  \"gg\" '(magit-status :which-key \"status\")\n  \"gh\" '(my/git-toggle-blame :which-key \"highlight hunks\")\n  \"gH\" '(diff-hl-show-hunk :which-key \"preview hunk\")\n  \"gl\" '(magit-log-current :which-key \"log\")\n  \"gm\" '(magit-branch :which-key \"toggle merginal\")\n  \"gn\" '(diff-hl-next-hunk :which-key \"next hunk\")\n  \"go\" '(my/git-browse-repo :which-key \"open repo\")\n  \"gp\" '(magit-push :which-key \"push\")\n  \"gP\" '(magit-pull :which-key \"pull\")\n  \"gr\" '(magit-file-delete :which-key \"rm\")\n  \"gs\" '(my/git-stage-hunk :which-key \"stage hunk\")\n  \"gt\" '(my/git-toggle-signs :which-key \"toggle gutter signs\")\n  \"gT\" '(git-timemachine :which-key \"time machine\")\n  \"gu\" '(diff-hl-revert-hunk :which-key \"undo hunk\")\n  \"gv\" '(magit-log-all :which-key \"view commits\")\n  \"gV\" '(magit-log-buffer-file :which-key \"view buffer commits\")\n  \"gy\" '(git-link :which-key \"yank link\")\n\n  \"j\"  '(:ignore t :which-key \"jump\")\n  \"jb\" '(my/jump-word-above :which-key \"word backwards\")\n  \"jf\" '(my/jump-word-below :which-key \"word forward\")\n  \"jj\" '(my/jump-char :which-key \"char\")\n  \"jJ\" '(my/jump-char-2 :which-key \"2 chars\")\n  \"jl\" '(my/jump-line :which-key \"line bidirectional\")\n  \"jw\" '(my/jump-word :which-key \"word bidirectional\")\n\n  \"l\"  '(:ignore t :which-key \"lsp\")\n  \"lh\" '(lsp-ui-doc-glance :which-key \"hover doc popup\")\n  \"lb\" '(my/diagnostics-buffer :which-key \"buffer diagnostics\")\n  \"lc\" '(lsp-execute-code-action :which-key \"code action\")\n  \"ld\" '(consult-lsp-diagnostics :which-key \"diagnostics\")\n  \"le\" '(flycheck-previous-error :which-key \"prev diagnostic\")\n  \"li\" '(lsp-describe-session :which-key \"info\")\n  \"ln\" '(flycheck-next-error :which-key \"next diagnostic\")\n  \"lq\" '(flycheck-list-errors :which-key \"quickfix\")\n  \"lr\" '(my/lsp-restart :which-key \"restart server\")\n  \"ls\" '(consult-lsp-file-symbols :which-key \"document symbols\")\n  \"lS\" '(consult-lsp-symbols :which-key \"workspace symbols\")\n\n  \"n\"  '(:ignore t :which-key \"markdown\")\n  \"nr\" '(my/markdown-toggle-render :which-key \"rendered / raw markdown\")\n  \"np\" '(markdown-live-preview-mode :which-key \"rendered HTML preview\")\n\n  \"h\"  '(:ignore t :which-key \"help\")\n  \"hr\" '(my/emacs-report :which-key \"write diagnostics report\")\n  \"hp\" '(my/report-profiler-start :which-key \"start profiler\")\n  \"hP\" '(my/report-profiler-stop :which-key \"stop profiler + write\")\n  \"hk\" '(describe-key :which-key \"describe key\")\n  \"hf\" '(describe-function :which-key \"describe function\")\n  \"hv\" '(describe-variable :which-key \"describe variable\")\n\n  \"?\"  '(which-key-show-major-mode :which-key \"keys in this buffer\")\n  \"h?\" '(which-key-show-full-major-mode :which-key \"keys in this buffer (full)\")\n\n\n\n\n\n  \"o\"  '(:ignore t :which-key \"open\")\n  \"oc\" '(my/devcontainer-up :which-key \"devcontainer up + shell\")\n  \"oC\" '(my/devcontainer-open :which-key \"reopen in container\")\n  \"od\" '(docker :which-key \"docker\")\n  \"oD\" '(my/dashboard :which-key \"dashboard\")\n  \"of\" '(my/devcontainer-find-file :which-key \"file in container\")\n  \"oe\" '(my/devcontainer-shell :which-key \"shell in container\")\n  \"oX\" '(my/devcontainer-down :which-key \"stop container\")\n  \"ob\" '(my/browse-url-at-point :which-key \"browser (in emacs)\")\n  \"oh\" '(restclient-mode :which-key \"http scratchpad\")\n  \"os\" '(my/sql-postgres :which-key \"postgres\")\n  \"oS\" '(my/sonar-scan :which-key \"sonar scan\")\n\n  \"p\"  '(:ignore t :which-key \"projects\")\n  \"pe\" '(my/consult-env :which-key \"environment variables\")\n  \"pf\" '(projectile-find-file :which-key \"find files\")\n  \"pp\" '(consult-projectile-switch-project :which-key \"switch\")\n  \"ps\" '(my/search-project :which-key \"search\")\n  \"pS\" '(my/search-project-regex :which-key \"search regex\")\n  \"pt\" '(my/todos-project :which-key \"TODOs\")\n\n  \"q\"  '(:ignore t :which-key \"quit\")\n  \"qq\" '(my/quit-frame :which-key \"close frame\")\n  \"qQ\" '(my/quit-force :which-key \"quit without saving\")\n\n  \"r\"  '(:ignore t :which-key \"replace\")\n  \"rb\" '(my/replace-buffer :which-key \"buffer\")\n  \"rp\" '(my/replace-project :which-key \"project\")\n  \"rw\" '(my/replace-word-buffer :which-key \"word in buffer\")\n  \"rW\" '(my/replace-word-project :which-key \"word in project\")\n\n\n\n  \"s\"  '(:ignore t :which-key \"search\")\n  \"sp\" '(my/search-project :which-key \"project\")\n  \"sP\" '(my/search-project-regex :which-key \"project regex\")\n  \"ss\" '(consult-line :which-key \"buffer\")\n  \"sS\" '(my/search-buffer-regex :which-key \"buffer regex\")\n  \"st\" '(consult-imenu :which-key \"buffer tags\")\n  \"sT\" '(consult-imenu-multi :which-key \"project tags\")\n\n  \"t\"  '(:ignore t :which-key \"test\")\n  \"tt\" '(jest-popup :which-key \"menu (watch, coverage, -t, --config)\")\n  \"ta\" '(jest :which-key \"all\")\n  \"tf\" '(jest-file :which-key \"this file\")\n  \"tF\" '(jest-file-dwim :which-key \"this file's test (needs projectile suffix)\")\n  \"tn\" '(jest-function :which-key \"test at point\")\n  \"tr\" '(jest-repeat :which-key \"repeat last run\")\n  \"td\" '(dape :which-key \"debug\")\n\n  \"T\"  '(:ignore t :which-key \"toggles\")\n  \"Tb\" '(my/git-toggle-blame :which-key \"inline blame\")\n  \"Ti\" '(highlight-indent-guides-mode :which-key \"indent guides\")\n  \"Tl\" '(display-line-numbers-mode :which-key \"line numbers\")\n  \"Tm\" '(my/toggle-markdown-markup :which-key \"markdown markup\")\n  \"TI\" '(my/toggle-markdown-images :which-key \"markdown images\")\n  \"Ts\" '(evil-ex-nohighlight :which-key \"search highlight\")\n  \"Tt\" '(my/toggle-twilight :which-key \"twilight\")\n  \"Tw\" '(visual-line-mode :which-key \"wrap\")\n  \"Tz\" '(my/toggle-zen :which-key \"zen\")\n\n  \"w\"  '(:ignore t :which-key \"windows\")\n  \"wd\" '(evil-window-delete :which-key \"close\")\n  \"we\" '(evil-window-up :which-key \"up\")\n  \"wE\" '(evil-window-decrease-height :which-key \"expand up\")\n  \"wh\" '(evil-window-left :which-key \"left\")\n  \"wH\" '(evil-window-decrease-width :which-key \"expand left\")\n  \"wi\" '(evil-window-right :which-key \"right\")\n  \"wI\" '(evil-window-increase-width :which-key \"expand right\")\n  \"wn\" '(evil-window-down :which-key \"down\")\n  \"wN\" '(evil-window-increase-height :which-key \"expand down\")\n  \"wo\" '(delete-other-windows :which-key \"close others\")\n  \"wr\" '(evil-window-rotate-downwards :which-key \"rotate\")\n  \"ws\" '(my/split-below-and-focus :which-key \"split down\")\n  \"wv\" '(my/split-right-and-focus :which-key \"split right\")\n  \"w=\" '(balance-windows :which-key \"balance\")\n\n  \"x\"  '(:ignore t :which-key \"text\")\n  \"xd\" '(delete-trailing-whitespace :which-key \"delete trailing whitespace\")\n  \"xf\" '(my/format-buffer :which-key \"format buffer\"))\n\n(my/localleader\n  \",\"  '(emmet-expand-line :which-key \"expand emmet\")\n\n  \"g\"  '(:ignore t :which-key \"go to\")\n  \"gd\" '(lsp-find-definition :which-key \"definition\")\n  \"gD\" '(lsp-find-declaration :which-key \"declaration\")\n  \"gI\" '(lsp-find-implementation :which-key \"implementation\")\n  \"gr\" '(lsp-find-references :which-key \"references\")\n  \"gT\" '(lsp-find-type-definition :which-key \"type definition\")\n  \"gx\" '(browse-url-at-point :which-key \"open link\")\n\n  \"c\"  '(:ignore t :which-key \"code\")\n  \"ca\" '(lsp-execute-code-action :which-key \"code action\")\n  \"cd\" '(my/diagnostic-at-point :which-key \"diagnostics\")\n  \"cf\" '(my/format-buffer :which-key \"format\")\n  \"cn\" '(my/symbol-outline :which-key \"navigate\")\n  \"cr\" '(lsp-rename :which-key \"rename\")\n  \"cR\" '(my/lsp-restart :which-key \"restart server\")\n\n  \"ce\"  '(:ignore t :which-key \"extract\")\n  \"ceb\" '(my/lsp-extract :which-key \"block\")\n  \"cef\" '(my/lsp-extract :which-key \"function\")\n  \"cev\" '(my/lsp-extract :which-key \"variable\")\n  \"cem\" '(emr-show-refactor-menu :which-key \"menu\")\n\n  \"ci\"  '(:ignore t :which-key \"inline\")\n  \"cif\" '(my/lsp-inline :which-key \"function\")\n  \"civ\" '(my/lsp-inline :which-key \"variable\"))")

(work/load-module "plugins/devops/containers.nix" '()
  "(require 'tramp)\n\n(require 'tramp-container)\n\n(setq tramp-verbose 1\n      tramp-default-method \"ssh\")\n\n(add-to-list 'tramp-remote-path 'tramp-own-remote-path)\n\n(setq lsp-enable-file-watchers-remote nil)\n\n(defun my/devcontainer--root ()\n  \"Project root, or `default-directory' when there is no project.\"\n  (or (ignore-errors (my/project-root)) default-directory))\n\n(defun my/devcontainer-id ()\n  \"Name of the devcontainer for this project, or nil.\nThe devcontainer CLI labels every container it starts with the folder it was\nstarted from, which is a reliable project -> container mapping; matching on\nimage or name guesses.\"\n  (let* ((root (directory-file-name (expand-file-name (my/devcontainer--root))))\n         (out (shell-command-to-string\n               (format \"docker ps --filter label=devcontainer.local_folder=%s --format '{{.Names}}' 2>/dev/null\"\n                       (shell-quote-argument root))))\n         (name (car (split-string out \"\\n\" t))))\n    (and name (not (string-empty-p name)) name)))\n\n(defun my/devcontainer--pick ()\n  \"This project's container, else ask among the running ones.\"\n  (or (my/devcontainer-id)\n      (let ((names (split-string\n                    (shell-command-to-string \"docker ps --format '{{.Names}}' 2>/dev/null\")\n                    \"\\n\" t)))\n        (if names\n            (completing-read \"Container: \" names nil t)\n          (user-error \"No running containers\")))))\n\n(defun my/devcontainer-workdir (container)\n  \"Working directory configured in CONTAINER, defaulting to /workspace.\"\n  (let ((wd (string-trim\n             (shell-command-to-string\n              (format \"docker inspect -f '{{.Config.WorkingDir}}' %s 2>/dev/null\"\n                      (shell-quote-argument container))))))\n    (if (string-empty-p wd) \"/workspace\" wd)))\n\n(defun my/devcontainer-up-then (callback)\n  \"Bring this project's devcontainer up, then call CALLBACK with no arguments.\nAsynchronous: the CLI pulls and builds on a cold start, which is minutes, and\nblocking Emacs for that is not acceptable.\"\n  (let* ((default-directory (my/devcontainer--root))\n         (buf (get-buffer-create \"*devcontainer*\")))\n    (with-current-buffer buf (erase-buffer))\n    (message \"devcontainer up...\")\n    (make-process\n     :name \"devcontainer-up\"\n     :buffer buf\n     :command (list \"devcontainer\" \"up\" \"--workspace-folder\" \".\")\n     :sentinel\n     (lambda (_proc event)\n       (if (string-match-p \"finished\" event)\n           (progn (message \"devcontainer up: ready\")\n                  (when callback (funcall callback)))\n         (message \"devcontainer up failed -- see *devcontainer*\")\n         (display-buffer \"*devcontainer*\"))))))\n\n(defun my/devcontainer-up ()\n  \"Bring this project's devcontainer up, then open a shell inside it.\"\n  (interactive)\n  (my/devcontainer-up-then #'my/devcontainer-shell))\n\n(defun my/devcontainer--ensure (callback)\n  \"Run CALLBACK once this project has a running container.\nStarts one if there is none, rather than failing: reaching for \\\"open in\ncontainer\\\" when the container happens to be down is the same intent as\nstarting it, and making that two commands in a fixed order is a trap.\"\n  (if (my/devcontainer-id)\n      (funcall callback)\n    (if (y-or-n-p \"No container running for this project. Start it? \")\n        (my/devcontainer-up-then callback)\n      (user-error \"No container for %s\" (my/devcontainer--root)))))\n\n(defun my/devcontainer-shell ()\n  \"Open a shell inside this project's container.\"\n  (interactive)\n  (let* ((container (my/devcontainer--pick))\n         (wd (my/devcontainer-workdir container))\n         (bufname (format \"*term:%s*\" container)))\n    (if (get-buffer bufname)\n        (pop-to-buffer bufname)\n      (let ((default-directory (format \"/docker:%s:%s/\" container wd)))\n        (vterm bufname)))\n    (evil-insert-state)))\n\n(defun my/devcontainer-open ()\n  \"Open this project's root from inside the container -- \\\"reopen in container\\\".\nEverything opened from the resulting dired carries the /docker: prefix, so the\nremote LSP clients below start their servers in the container. Brings the\ncontainer up first if it is not already running.\"\n  (interactive)\n  (my/devcontainer--ensure\n   (lambda ()\n     (let* ((container (my/devcontainer--pick))\n            (wd (my/devcontainer-workdir container)))\n       (dired (format \"/docker:%s:%s/\" container wd))))))\n\n(defun my/devcontainer-find-file ()\n  \"Open a file inside a running container over tramp.\"\n  (interactive)\n  (let* ((container (my/devcontainer--pick))\n         (wd (my/devcontainer-workdir container)))\n    (find-file (format \"/docker:%s:%s/\" container wd))))\n\n(defun my/devcontainer-down ()\n  \"Stop this project's container.\"\n  (interactive)\n  (let ((container (my/devcontainer--pick)))\n    (shell-command (format \"docker stop %s\" (shell-quote-argument container)))\n    (message \"stopped %s\" container)))\n\n(with-eval-after-load 'lsp-mode\n  (dolist (spec '((ts-ls-remote      (\"typescript-language-server\" \"--stdio\")\n                   (js-mode js-ts-mode typescript-mode typescript-ts-mode\n                    tsx-ts-mode jsx-mode web-mode))\n                  (vue-ls-remote     (\"vue-language-server\" \"--stdio\")\n                   (vue-mode web-mode))\n                  (gopls-remote      (\"gopls\")\n                   (go-mode go-ts-mode))\n                  (bash-ls-remote    (\"bash-language-server\" \"start\")\n                   (sh-mode bash-ts-mode))\n                  (yaml-ls-remote    (\"yaml-language-server\" \"--stdio\")\n                   (yaml-mode yaml-ts-mode))))\n    (let ((id (nth 0 spec)) (cmd (nth 1 spec)) (modes (nth 2 spec)))\n      (lsp-register-client\n       (make-lsp-client\n        :new-connection (lsp-tramp-connection cmd)\n        :major-modes modes\n        :remote? t\n        :server-id id\n        :priority -2))))\n  (setq lsp-enable-suggest-server-download nil))")

(work/load-module "plugins/ai/sessions.nix" '()
  "(defun my/claude--sessions ()\n  \"Parsed rows from the session index, newest first.\"\n  (let ((out (shell-command-to-string (expand-file-name \"helpers/claude-session-index\" user-emacs-directory))))\n    (delq nil\n          (mapcar (lambda (line)\n                    (let ((f (split-string line \"\\t\")))\n                      (when (= (length f) 7) f)))\n                  (split-string out \"\\n\" t)))))\n\n(defvar my/claude--root nil\n  \"Project root `my/claude--row-here-p' matches against.\")\n\n(defun my/claude--project-root ()\n  \"Root of the project the current buffer belongs to.\"\n  (expand-file-name\n   (or (and (fboundp 'projectile-project-root)\n            (ignore-errors (projectile-project-root)))\n       (and (fboundp 'project-current)\n            (ignore-errors\n              (let ((pr (project-current nil)))\n                (and pr (project-root pr)))))\n       default-directory)))\n\n(defun my/claude--row-here-p (f)\n  \"Non-nil when session row F took place under `my/claude--root'.\n`file-in-directory-p' rather than `string-prefix-p': the latter counts\n~/nix-config-literate as living under ~/nix-config, since one path really\nis a prefix of the other. Two sibling projects whose names share a stem is\nnot an edge case here, it is the literate setup.\"\n  (file-in-directory-p (nth 5 f) my/claude--root))\n\n(defun my/claude--pick (prompt &optional all)\n  \"Choose a session, returning its field list.\nOffers only the current project's conversations unless ALL is non-nil.\"\n  (let* ((my/claude--root (my/claude--project-root))\n         (rows (my/claude--sessions))\n         (here (seq-filter #'my/claude--row-here-p rows))\n         (rows (if (or all (null here)) rows here))\n         (table (mapcar (lambda (f)\n                          (cons (format \"%s  %-22s %-18s %s\"\n                                        (nth 0 f) (nth 1 f)\n                                        (truncate-string-to-width (nth 2 f) 18)\n                                        (nth 3 f))\n                                f))\n                        rows)))\n    (unless table (user-error \"No Claude sessions found\"))\n    (let* ((choice (completing-read\n                    prompt\n                    (lambda (str pred action)\n                      (if (eq action 'metadata)\n                          '(metadata (display-sort-function . identity)\n                                     (cycle-sort-function . identity))\n                        (complete-with-action action table str pred)))\n                    nil t)))\n      (cdr (assoc choice table)))))\n\n(defvar claude-code-ide-cli-extra-flags)\n\n(defvar-local my/claude--resumed-sid nil\n  \"Conversation this session was resumed from, when it was resumed.\n\nThe transcript path is the exact handle between a running session and its\nfile on disk, but it only holds until a resumed session says something:\n`claude --resume' continues the conversation into a transcript of its own,\nand the hooks then report that new file. This is the handle that does not\nmove, so the chat list can still tell that a row in the history and the\nsession running in the pane are one conversation.\")\n\n(defun my/claude--live-session-for (sid path)\n  \"Key of the session already running conversation SID, if one is.\nMatched on the transcript at PATH while a session is still writing that\nfile, and on the conversation it was resumed from once it is not.\"\n  (when (and (fboundp 'claude-code-ide-manager--build-items)\n             (fboundp 'claude-code-ide-manager--session-buffer))\n    (catch 'found\n      (dolist (item (claude-code-ide-manager--build-items '(:type global)))\n        (let* ((key (claude-code-ide-manager-item-session-key item))\n               (buf (claude-code-ide-manager--session-buffer key)))\n          (when (and (buffer-live-p buf)\n                     (or (and path\n                              (equal path (buffer-local-value\n                                           'my/claude--transcript-path buf)))\n                         (and sid\n                              (equal sid (buffer-local-value\n                                          'my/claude--resumed-sid buf)))))\n            (throw 'found key))))\n      nil)))\n\n(defun my/claude-resume-session (sid cwd &optional label path)\n  \"Resume conversation SID in a claude-code-ide session rooted at CWD.\nLABEL, when given, names the session so the manager sidebar has something\nto show for it. PATH is the conversation's transcript, recorded on the new\nsession's buffer so the chat list can tell the two are one thing before the\nfirst hook has fired and told it the same.\n\nRuns in the conversation's own directory: Claude resolves a session against\nthe project it belongs to and does not find it from anywhere else.\n\nStarted through claude-code-ide rather than by typing `claude --resume' into\na bare vterm, which is what this used to do. A raw vterm is invisible to\neverything that makes the manager sidebar useful -- it is not in the session\nregistry, so it gets no row, no state glyph and no saved layout, and it has\nno MCP server, so Claude cannot reach xref or the diagnostics. A resumed\nconversation is a conversation; it should arrive with the same machinery a\nfresh one does.\n\n`claude-code-ide-cli-extra-flags' is the seam for this: the only documented\nway in is the -r flag, which makes the CLI draw its own picker, and the\npicker is exactly what this command exists to replace. Bound dynamically\naround a private entry point, because the public commands cannot express\n\\\"this directory, a new session, these flags\\\" -- `claude-code-ide-resume'\nwould toggle into the project's existing session instead of starting one on\nthe conversation asked for.\n\nA conversation already resumed and still running is switched into rather\nthan resumed again: a second CLI on one conversation is two panes, two sets\nof hooks and two claims on the transcript, and it is never what picking the\nrow meant.\"\n  (unless (file-directory-p cwd)\n    (user-error \"That conversation's directory no longer exists: %s\" cwd))\n  (require 'claude-code-ide)\n  (if-let* ((running (my/claude--live-session-for sid path)))\n      (my/claude-show-session running)\n    (let* ((claude-code-ide-cli-extra-flags (format \"--resume %s\" sid))\n           (session (claude-code-ide--start-session nil nil cwd t))\n           (buf (or (and (claude-code-ide-session-p session)\n                         (claude-code-ide-session-buffer session))\n                    (and (claude-code-ide-session-buffer-p (current-buffer))\n                         (current-buffer)))))\n      (when (buffer-live-p buf)\n        (with-current-buffer buf\n          (setq-local my/claude--resumed-sid sid)\n          (when path\n            (setq-local my/claude--transcript-path path)))\n        (when label\n          (ignore-errors\n            (when-let* ((key (claude-code-ide-manager--session-key-for-buffer\n                              buf)))\n              (claude-code-ide-manager-rename-session\n               key (truncate-string-to-width label 28)))))))))\n\n(defun my/claude-resume (&optional all)\n  \"Pick a past Claude conversation from this project and resume it.\nWith a prefix argument ALL, offer conversations from every project.\"\n  (interactive \"P\")\n  (let ((row (my/claude--pick (if all \"Resume any Claude session: \"\n                                \"Resume Claude session: \")\n                              all)))\n    (my/claude-resume-session (nth 4 row) (nth 5 row) (nth 3 row) (nth 6 row))))\n\n(defun my/claude--render-transcript (path sid header)\n  \"Render the conversation at PATH read-only and show it.\nSID names the buffer; HEADER is the line put above the conversation.\"\n  (let ((buf (get-buffer-create (format \"*claude transcript: %s*\" sid))))\n    (with-current-buffer buf\n      (let ((inhibit-read-only t))\n        (erase-buffer)\n        (insert header \"\\n\\n\")\n        (insert (shell-command-to-string\n                 (format \"%s %s\" (expand-file-name \"helpers/claude-transcript\" user-emacs-directory)\n                         (shell-quote-argument path))))\n        (goto-char (point-min))\n        (markdown-mode)\n        (view-mode 1)))\n    (pop-to-buffer buf)))\n\n(defun my/claude-view (&optional all)\n  \"Open a past conversation as text, without starting Claude.\nWith a prefix argument ALL, offer conversations from every project.\"\n  (interactive \"P\")\n  (let ((row (my/claude--pick (if all \"View any Claude transcript: \"\n                                \"View Claude transcript: \")\n                              all)))\n    (my/claude--render-transcript\n     (nth 6 row) (nth 4 row)\n     (format \"# %s  %s  %s\" (nth 0 row) (nth 1 row) (nth 2 row)))))\n\n(defun my/claude-search (term)\n  \"Search every past conversation for TERM and open the one you pick.\"\n  (interactive \"sSearch all Claude conversations: \")\n  (let* ((default-directory (expand-file-name \"~/.claude/projects\"))\n         (hits (split-string\n                (shell-command-to-string\n                 (format \"rg --no-heading --with-filename --max-count 1 -l -F %s . 2>/dev/null\"\n                         (shell-quote-argument term)))\n                \"\\n\" t)))\n    (unless hits (user-error \"No conversation mentions %s\" term))\n    (message \"%d conversations mention %s\" (length hits) term)\n    (find-file (completing-read \"Transcript: \" hits nil t))))\n\n(defvar my/claude--chats-scope 'all\n  \"Whether the chat list shows `project' or `all' conversations.\nEvery project by default: this list exists to be browsed, and the fold\nbelow keeps that from being a wall of text -- five conversations a project,\nthe rest a TAB away. Narrowing to one project is the special case, and `a'\nis what asks for it.\")\n\n(defface my/claude-chats-project-face\n  '((t (:inherit font-lock-keyword-face :weight bold)))\n  \"Face for a project heading in the chat list.\")\n\n(defface my/claude-chats-fold-face\n  '((t (:inherit font-lock-comment-face)))\n  \"Face for the line that folds away a project's older conversations.\")\n\n(defun my/claude--chats-glyph-face (glyph)\n  \"Face for GLYPH, taken from the meaning claude-code-ide gives it.\nCompared against the package's own constants rather than against literal\ncharacters, so changing a glyph upstream drops the colour rather than\nquietly colouring the wrong state.\"\n  (cond\n   ((not (boundp 'claude-code-ide-manager--needs-input-glyph)) 'default)\n   ((member glyph (list claude-code-ide-manager--needs-input-glyph\n                        claude-code-ide-manager--failed-glyph))\n    'error)\n   ((equal glyph claude-code-ide-manager--done-glyph) 'success)\n   ((equal glyph claude-code-ide-manager--working-glyph)\n    'font-lock-keyword-face)\n   ((equal glyph claude-code-ide-manager--bell-glyph) 'warning)\n   (t 'default)))\n\n(defvar my/claude--chats-index nil\n  \"Conversation index the chat list is being built from.\nA defvar rather than an argument threaded inward, for the reason\n`my/claude--root' is one: this file is generated without a lexical-binding\ncookie, so a lambda cannot capture a local. Bound once per refresh, because\nreading it shells out.\")\n\n(defvar my/claude--chats-index-cache nil\n  \"Cons of the time the index was last read and the rows it returned.\")\n\n(defvar my/claude--chats-force-index nil\n  \"Non-nil while a refresh should re-read the index rather than reuse it.\")\n\n(defun my/claude--chats-read-index (&optional force)\n  \"Index rows, from the cache unless FORCE or the cache has aged out.\nReading the index spawns a process that walks every transcript on disk. The\nglyph refreshes want to redraw far more often than that history changes: a\nturn starting or finishing moves the live half of the list and leaves every\nother row exactly as it was. So a state change redraws from the cache and\n`g' re-reads.\"\n  (let ((now (float-time)))\n    (when (or force\n              (null my/claude--chats-index-cache)\n              (> (- now (car my/claude--chats-index-cache)) 30))\n      (setq my/claude--chats-index-cache (cons now (my/claude--sessions))))\n    (cdr my/claude--chats-index-cache)))\n\n(defun my/claude--chat-here-p (row)\n  \"Non-nil when chat ROW took place under `my/claude--root'.\nReads its root from the defvar for the reason `my/claude--row-here-p' does.\"\n  (file-in-directory-p (plist-get row :cwd) my/claude--root))\n\n(defun my/claude--chat-title (path sid fallback)\n  \"Title the index gives the conversation at PATH or with id SID, or FALLBACK.\nclaude-code-ide names a live session after its directory, which says where\na conversation is and nothing about which one it is -- so a live row borrows\nthe title the index already has for its transcript, and reads the same as\nthe past rows below it. SID is the same lookup for a resumed session, whose\ntranscript has moved on but whose conversation the index still knows.\nFALLBACK covers a session that has not written anything yet, or one running\nsomewhere the index skips.\"\n  (or (when (or path sid)\n        (let ((found nil))\n          (dolist (f my/claude--chats-index)\n            (when (and (not found)\n                       (or (and path (equal (nth 6 f) path))\n                           (and sid (equal (nth 4 f) sid))))\n              (setq found (nth 3 f))))\n          found))\n      fallback))\n\n(defun my/claude--live-chats ()\n  \"Rows for the sessions running right now.\nBuilt from claude-code-ide's own items, so the glyph is the one its sidebar\nwould draw for each -- the states the Claude Code hooks push in included.\n\nEmpty, rather than an error, when the package has never been loaded: the\nlist is then just the conversation history, which is a reasonable thing to\nopen before starting anything.\"\n  (when (and (fboundp 'claude-code-ide-manager--build-items)\n             (boundp 'claude-code-ide--sessions))\n    (let ((rows nil))\n      (dolist (item (claude-code-ide-manager--build-items '(:type global)))\n        (let* ((key (claude-code-ide-manager-item-session-key item))\n               (dir (claude-code-ide-manager-item-directory item))\n               (buf (claude-code-ide-manager--session-buffer key))\n               (path (and (buffer-live-p buf)\n                          (buffer-local-value 'my/claude--transcript-path\n                                              buf)))\n               (sid (and (buffer-live-p buf)\n                         (buffer-local-value 'my/claude--resumed-sid buf))))\n          (push (list :live t\n                      :key key\n                      :glyph (string-trim\n                              (claude-code-ide-manager--marker-gutter item))\n                      :cwd dir\n                      :project (file-name-nondirectory\n                                (directory-file-name dir))\n                      :when \"live\"\n                      :title (my/claude--chat-title\n                              path sid\n                              (claude-code-ide-manager-item-display-name item))\n                      :sid sid\n                      :path path)\n                rows)))\n      (nreverse rows))))\n\n(defun my/claude--past-chats (live)\n  \"Rows for the conversations on disk, minus the ones LIVE already covers.\nMatched on the transcript path, which is exact: it is the file the CLI says\nit is writing, and the same string the index reports. claude-code-ide's own\nsession id cannot do this job -- it is its own, and the CLI never sees it.\n\nA resumed conversation is matched on the conversation it came from as well,\nsince the CLI writes the continuation to a transcript of its own and the\npath stops matching as soon as it does.\"\n  (let ((open (delq nil (mapcar (lambda (row) (plist-get row :path)) live)))\n        (resumed (delq nil (mapcar (lambda (row) (plist-get row :sid)) live)))\n        (rows nil))\n    (dolist (f my/claude--chats-index)\n      (unless (or (member (nth 6 f) open)\n                  (member (nth 4 f) resumed))\n        (push (list :live nil\n                    :glyph \"\"\n                    :cwd (nth 5 f)\n                    :project (nth 1 f)\n                    :when (nth 0 f)\n                    :title (nth 3 f)\n                    :sid (nth 4 f)\n                    :path (nth 6 f))\n              rows)))\n    (nreverse rows)))\n\n(defvar my/claude--chats-narrowed nil\n  \"Non-nil when the last redraw actually narrowed to one project.\nNot the same question as `my/claude--chats-scope': asking for one project\nwith no conversations in it falls back to showing every project, and the\nheader has to say what is on screen rather than what was asked for.\")\n\n(defun my/claude--chats-entries ()\n  \"Live sessions first, then the conversations on disk by recency.\"\n  (let* ((my/claude--chats-index\n          (my/claude--chats-read-index my/claude--chats-force-index))\n         (live (my/claude--live-chats))\n         (rows (append live (my/claude--past-chats live)))\n         (entries nil))\n    (setq my/claude--chats-narrowed nil)\n    (when (eq my/claude--chats-scope 'project)\n      (let* ((my/claude--root (my/claude--project-root))\n             (here (seq-filter #'my/claude--chat-here-p rows)))\n        (when here\n          (setq rows here\n                my/claude--chats-narrowed t))))\n    (dolist (row rows)\n      (let ((glyph (plist-get row :glyph)))\n        (push (list row\n                    (vector (propertize glyph 'face\n                                        (my/claude--chats-glyph-face glyph))\n                            (propertize (plist-get row :title)\n                                        'face (if (plist-get row :live)\n                                                  'bold\n                                                'default))\n                            (plist-get row :when)))\n              entries)))\n    (nreverse entries)))\n\n(defvar my/claude--chats-limit 5\n  \"Conversations shown per project before the rest are folded away.\")\n\n(defvar my/claude--chats-expanded nil\n  \"Working directories whose folded conversations are currently shown.\")\n\n(defun my/claude--chats-more-row (cwd hidden expanded)\n  \"The fold line for CWD: HIDDEN conversations away, EXPANDED as it stands.\"\n  (list (list :more cwd)\n        (vector \"\"\n                (propertize (if expanded\n                                \"fewer\"\n                              (format \"%d older\" hidden))\n                            'face 'my/claude-chats-fold-face)\n                \"\")))\n\n(defun my/claude--chats-groups ()\n  \"Entries grouped by project, live sessions first, the old ones folded.\n\nKeyed on the working directory rather than its name. Two directories can\nshare a basename -- a worktree beside the repository it came from, which is\nhow several tickets get worked at once -- and merging those under one\nheading would file conversations from different trees together. The\nheading falls back to parent/name when a basename is not unique.\n\nThe fold applies to the conversations on disk, not to the running ones: a\nproject with eight sessions open wants all eight, and its history from\nMarch does not need to be on screen to get at them.\"\n  (let ((order nil) (buckets nil) (counts nil) (groups nil))\n    (dolist (entry (my/claude--chats-entries))\n      (let* ((cwd (plist-get (nth 0 entry) :cwd))\n             (bucket (assoc cwd buckets)))\n        (unless bucket\n          (setq bucket (list cwd))\n          (push bucket buckets)\n          (push cwd order))\n        (setcdr bucket (cons entry (cdr bucket)))))\n    (setq order (nreverse order))\n    (dolist (cwd order)\n      (let* ((name (file-name-nondirectory (directory-file-name cwd)))\n             (seen (assoc name counts)))\n        (if seen\n            (setcdr seen (1+ (cdr seen)))\n          (push (cons name 1) counts))))\n    (dolist (cwd order)\n      (let* ((dir (directory-file-name cwd))\n             (name (file-name-nondirectory dir))\n             (heading (if (> (cdr (assoc name counts)) 1)\n                          (concat (file-name-nondirectory\n                                   (directory-file-name\n                                    (file-name-directory dir)))\n                                  \"/\" name)\n                        name))\n             (expanded (member cwd my/claude--chats-expanded))\n             (live nil)\n             (past nil)\n             (rows nil))\n        (dolist (entry (nreverse (cdr (assoc cwd buckets))))\n          (if (plist-get (nth 0 entry) :live)\n              (push entry live)\n            (push entry past)))\n        (setq live (nreverse live)\n              past (nreverse past))\n        (setq rows (append live (if expanded\n                                    past\n                                  (seq-take past my/claude--chats-limit))))\n        (when (> (length past) my/claude--chats-limit)\n          (setq rows (append rows\n                             (list (my/claude--chats-more-row\n                                    cwd\n                                    (- (length past) my/claude--chats-limit)\n                                    expanded)))))\n        (push (cons (propertize heading\n                                'face 'my/claude-chats-project-face)\n                    rows)\n              groups)))\n    (nreverse groups)))\n\n(defun my/claude--chats-goto-fold (cwd)\n  \"Put the point on CWD's fold line. Non-nil when there was one.\"\n  (let ((target nil))\n    (goto-char (point-min))\n    (while (and (not target) (not (eobp)))\n      (let ((id (tabulated-list-get-id)))\n        (when (and id (equal (plist-get id :more) cwd))\n          (setq target (point))))\n      (forward-line 1))\n    (when target\n      (goto-char target)\n      t)))\n\n(defun my/claude-chats-toggle-group ()\n  \"Fold or unfold the older conversations of the project at point.\nLeaves the point on the fold line rather than on whatever row its old line\nnumber now holds. Unfolding pushes that line down past everything it\nrevealed, so restoring by number lands on a conversation -- and a second\nRET there resumes one nobody asked for.\"\n  (interactive)\n  (let* ((row (tabulated-list-get-id))\n         (cwd (and row (or (plist-get row :more) (plist-get row :cwd))))\n         (line (line-number-at-pos)))\n    (unless cwd (user-error \"No project on this line\"))\n    (setq my/claude--chats-expanded\n          (if (member cwd my/claude--chats-expanded)\n              (delete cwd my/claude--chats-expanded)\n            (cons cwd my/claude--chats-expanded)))\n    (tabulated-list-print)\n    (unless (my/claude--chats-goto-fold cwd)\n      (goto-char (point-min))\n      (forward-line (1- line)))))\n\n(defun my/claude--chats-redraw ()\n  \"Redraw the list in the current buffer, keeping the point on its line.\nThe header goes in after the print, not before: it names the scope the\nrows are actually in, and that is only known once they have been built.\"\n  (let ((line (line-number-at-pos)))\n    (tabulated-list-print)\n    (my/claude--chats-header)\n    (goto-char (point-min))\n    (forward-line (1- line))))\n\n(defun my/claude-chats-refresh ()\n  \"Re-read the conversation history and rebuild the list.\"\n  (interactive)\n  (let ((my/claude--chats-force-index t))\n    (my/claude--chats-redraw)))\n\n(defun my/claude--chats-restate (&rest _)\n  \"Redraw the chat list when a session's state changes under it.\nThe glyph is the part of the list that goes stale fastest: a turn that\nfinishes while the list is on screen would otherwise still read as working\nuntil the next `g'. claude-code-ide-manager keeps its own sidebar current\nthrough these same three signals -- the two state hooks, and the setter the\nClaude Code hooks reach over emacsclient -- so the list rides on them too.\n\nOnly when the list is actually on a window somewhere. Redrawing a buffer\nnobody is looking at would spend a subprocess on every turn transition in\nevery project, and `my/claude-chats' re-reads on the way in anyway.\"\n  (when-let* ((buf (get-buffer \"*claude chats*\")))\n    (when (get-buffer-window buf t)\n      (with-current-buffer buf\n        (my/claude--chats-redraw)))))\n\n(with-eval-after-load 'claude-code-ide\n  (add-hook 'claude-code-ide-session-idle-hook #'my/claude--chats-restate)\n  (add-hook 'claude-code-ide-session-working-hook #'my/claude--chats-restate)\n  (advice-add 'claude-code-ide-session-idle-set-agent-state\n              :after #'my/claude--chats-restate))\n\n(defun my/claude-chats-toggle-scope ()\n  \"Switch between this project's conversations and every project's.\"\n  (interactive)\n  (setq my/claude--chats-scope\n        (if (eq my/claude--chats-scope 'project) 'all 'project))\n  (my/claude-chats-refresh)\n  (message \"Claude chats: %s\"\n           (if (eq my/claude--chats-scope 'all)\n               \"every project\"\n             \"this project\")))\n\n(defun my/claude--chats-window ()\n  \"The window showing the chat list, if it is on screen.\"\n  (get-buffer-window \"*claude chats*\" t))\n\n(defun my/claude--chats-close ()\n  \"Close the chat list window, leaving the buffer behind it.\"\n  (when-let* ((win (my/claude--chats-window)))\n    (when (window-live-p win)\n      (delete-window win))))\n\n(defun my/claude-chats-visit ()\n  \"Enter the conversation on this line, resuming it when it is not running.\nOn a fold line, unfolds the project instead.\n\nCloses the list on the way through, before the conversation opens. It is a\npicker and the two share a column: leaving it up would halve the pane the\nconversation is about to appear in.\"\n  (interactive)\n  (let ((row (tabulated-list-get-id)))\n    (unless row (user-error \"No conversation on this line\"))\n    (if (plist-get row :more)\n        (my/claude-chats-toggle-group)\n      (my/claude--chats-close)\n      (if (plist-get row :live)\n          (my/claude-show-session (plist-get row :key))\n        (message \"Resuming %s...\" (plist-get row :title))\n        (my/claude-resume-session (plist-get row :sid)\n                                  (plist-get row :cwd)\n                                  (plist-get row :title)\n                                  (plist-get row :path))))))\n\n(defun my/claude-chats-view ()\n  \"Read the conversation on this line without starting Claude.\"\n  (interactive)\n  (let ((row (tabulated-list-get-id)))\n    (when (or (null row) (plist-get row :more))\n      (user-error \"No conversation on this line\"))\n    (let ((path (plist-get row :path)))\n      (unless path\n        (user-error \"This session has not written a transcript yet\"))\n      (my/claude--render-transcript\n       path (or (plist-get row :sid) (plist-get row :project))\n       (format \"# %s  %s\" (plist-get row :when) (plist-get row :project))))))\n\n(defvar my/claude-chats-mode-map\n  (let ((map (make-sparse-keymap)))\n    (define-key map (kbd \"RET\") #'my/claude-chats-visit)\n    (define-key map (kbd \"TAB\") #'my/claude-chats-toggle-group)\n    (define-key map (kbd \"v\") #'my/claude-chats-view)\n    (define-key map (kbd \"a\") #'my/claude-chats-toggle-scope)\n    (define-key map (kbd \"r\") #'my/claude-chats-refresh)\n    (define-key map (kbd \"g\") #'my/claude-chats-refresh)\n    (define-key map (kbd \"q\") #'quit-window)\n    map)\n  \"Keymap for `my/claude-chats-mode'.\nAvoids h/n/e/i/p/f, which are movement and scrolling on this layout.\")\n\n(defun my/claude--chats-scope-label ()\n  \"How the header names the scope the rows on screen are in.\"\n  (if my/claude--chats-narrowed\n      (file-name-nondirectory (directory-file-name (my/claude--project-root)))\n    \"every project\"))\n\n(defun my/claude--chats-header ()\n  \"Install the column header, with the current scope named in it.\"\n  (setq tabulated-list-format\n        (vector '(\"\" 2 nil)\n                (list (format \"Chat — %s\" (my/claude--chats-scope-label)) 58 nil)\n                '(\"When\" 18 nil)))\n  (tabulated-list-init-header))\n\n(define-derived-mode my/claude-chats-mode tabulated-list-mode \"Claude chats\"\n  \"Every Claude conversation, the running ones and the kept ones.\"\n  (setq tabulated-list-padding 1\n        tabulated-list-groups #'my/claude--chats-groups)\n  (my/claude--chats-header))\n\n(with-eval-after-load 'evil\n  (evil-set-initial-state 'my/claude-chats-mode 'normal)\n  (evil-define-key 'normal my/claude-chats-mode-map\n    (kbd \"RET\") #'my/claude-chats-visit\n    (kbd \"TAB\") #'my/claude-chats-toggle-group\n    (kbd \"v\") #'my/claude-chats-view\n    (kbd \"a\") #'my/claude-chats-toggle-scope\n    (kbd \"r\") #'my/claude-chats-refresh\n    (kbd \"q\") #'quit-window))\n\n(defun my/claude-chats ()\n  \"Every Claude conversation in one list: the running ones and the kept ones.\nGrouped under the project each belongs to, running sessions at the top of\ntheir group and the rest by recency, five deep before the older ones fold\naway behind a line that unfolds them.\n\nA live row is prefixed with the state glyph claude-code-ide draws for it --\n`?' waiting on you, `✓' finished, `✗' failed, `⚙︎' working, `🔔' gone quiet --\nand RET switches into it. A past row has no glyph, and RET resumes it in its\nown project directory.\n\nOpens on every project, which is the case both the manager sidebar and\n`claude --resume' refuse; `a' narrows it to this one and back, and the\ncolumn header says which of the two is on screen. TAB folds and unfolds a\nproject, `v' reads a conversation without starting anything, `r' refreshes.\n\nCalled again while it is up, closes it.\"\n  (interactive)\n  (if (my/claude--chats-window)\n      (my/claude--chats-close)\n    (let ((root (my/claude--project-root))\n          (buf (get-buffer-create \"*claude chats*\")))\n      (with-current-buffer buf\n        (setq default-directory root)\n        (my/claude-chats-mode)\n        (my/claude-chats-refresh))\n      (pop-to-buffer buf))))")

(work/load-module "plugins/ui/report.nix" '()
  "(setq message-log-max 10000)\n\n(defun my/report--buffer (name)\n  \"Contents of buffer NAME, or a note that it does not exist.\"\n  (if (get-buffer name)\n      (with-current-buffer name (buffer-substring-no-properties (point-min) (point-max)))\n    (format \"(no %s buffer)\" name)))\n\n(defun my/emacs-report ()\n  \"Write a diagnostics report and show where it went.\nIncludes *Messages*, *Warnings*, any *Backtrace*, startup timing and the\nloaded-feature count. Written to a file rather than the kill ring because\n*Messages* routinely runs to thousands of lines.\"\n  (interactive)\n  (let* ((file (expand-file-name\n                (format-time-string \"~/emacs-report-%Y%m%d-%H%M%S.txt\")))\n         (text\n          (concat\n           \"=== emacs ===\\n\"\n           (format \"version:      %s\\n\" emacs-version)\n           (format \"init time:    %s\\n\" (emacs-init-time))\n           (format \"features:     %d loaded\\n\" (length features))\n           (format \"daemon:       %s\\n\" (daemonp))\n           (format \"system:       %s\\n\" system-configuration)\n           (format \"frame:        %s\\n\" (framep (selected-frame)))\n           (format \"invocation:   %s\\n\" (expand-file-name invocation-name invocation-directory))\n           \"\\n=== *Warnings* ===\\n\" (my/report--buffer \"*Warnings*\")\n           \"\\n\\n=== *Backtrace* ===\\n\" (my/report--buffer \"*Backtrace*\")\n           \"\\n\\n=== *Messages* ===\\n\" (my/report--buffer \"*Messages*\"))))\n    (with-temp-file file (insert text))\n    (kill-new file)\n    (message \"Report written to %s (path copied)\" file)\n    file))\n\n(defun my/report-profiler-start ()\n  \"Start the CPU profiler, to catch a freeze in the act.\"\n  (interactive)\n  (profiler-start 'cpu)\n  (message \"Profiler running -- reproduce the problem, then SPC h P\"))\n\n(defun my/report-profiler-stop ()\n  \"Stop the profiler and write its report next to the diagnostics one.\"\n  (interactive)\n  (profiler-stop)\n  (profiler-report)\n  (let ((file (expand-file-name\n               (format-time-string \"~/emacs-profile-%Y%m%d-%H%M%S.txt\"))))\n    (with-current-buffer (get-buffer \"*CPU-Profiler-Report*\")\n      (profiler-report-expand-entry)\n      (write-region (point-min) (point-max) file))\n    (kill-new file)\n    (message \"Profile written to %s (path copied)\" file)))")

(work/load-module "plugins/apps/browser.nix" '(browser-gt websocket)
  "(require 'xwidget nil t)\n\n(setq xwidget-webkit-enable-plugins t\n      xwidget-webkit-buffer-name-format \"*web: %T*\")\n\n(defun my/browse-external (url)\n  \"Open URL in the system browser.\"\n  (interactive \"sURL: \")\n  (browse-url-default-browser url))\n\n(defun my/browse-internal (url)\n  \"Open URL in an xwidget-webkit buffer inside Emacs.\"\n  (interactive \"sURL: \")\n  (if (featurep 'xwidget-internal) (xwidget-webkit-browse-url url t) (eww url)))\n\n(defun my/browse-url-at-point ()\n  \"Open the URL at point in Emacs, or prompt when there is none.\"\n  (interactive)\n  (let ((url (or (thing-at-point 'url t)\n                 (read-string \"URL: \" \"https://\"))))\n    (my/browse-internal url)))\n\n(setq browse-url-browser-function 'browse-url-default-browser\n      eww-search-prefix \"https://duckduckgo.com/html/?q=\")\n\n(require 'browser-gt)\n\n(require 'browser-gt-tab-manager)\n\n(browser-gt-start)\n\n(with-eval-after-load 'browser-gt-tab-manager\n  (evil-make-overriding-map browser-gt-tab-manager-mode-map 'normal))")

(work/load-module "plugins/version-control/gitlab.nix" '()
  "(with-eval-after-load 'forge\n  (require 'forge-gitlab)\n\n  (defun my/forge--gitlab-mr (&optional demand)\n    \"Return the merge request at point, or nil.\nErrors instead of returning nil when DEMAND is non-nil, and always errors\nwhen point is on a topic belonging to a host that is not GitLab -- the\napproval endpoint below is GitLab's alone.\"\n    (let ((topic (forge-current-pullreq demand)))\n      (cond ((null topic) nil)\n            ((forge-gitlab-repository-p (forge-get-repository topic)) topic)\n            (demand (user-error \"Not a GitLab merge request\"))\n            (t nil))))\n\n  (defun my/forge--ensure-mr-ref (mr)\n    \"Fetch MR's head ref if it is not local yet, and return the ref.\nGitLab publishes merge request heads under refs/merge-requests/N/head, and\nforge maps them to refs/pullreqs/N. Until something fetches that,\n`forge--pullreq-range' has no head to anchor on and quietly returns nil,\nwhich reads as \\\"no changes\\\" rather than \\\"not downloaded\\\".\"\n    (let ((n (oref mr number)))\n      (or (forge--pullreq-ref mr)\n          (progn\n            (message \"Fetching merge request !%s...\" n)\n            (magit-run-git \"fetch\" (forge--get-remote)\n                           (format \"+refs/merge-requests/%s/head:refs/pullreqs/%s\" n n))\n            (forge--pullreq-ref mr)))))\n\n  (defun my/forge-mr-diff ()\n    \"Show the diff of the merge request at point.\nDiffs against the merge base rather than the target branch's tip, so\nunrelated commits landing on the target while the review is open do not\nappear as part of the change under review.\"\n    (interactive)\n    (let ((mr (or (forge-current-pullreq t)\n                  (user-error \"Not on a merge request\"))))\n      (unless (my/forge--ensure-mr-ref mr)\n        (user-error \"Could not fetch the head of !%s\" (oref mr number)))\n      (magit-diff-range (forge--pullreq-range mr))))\n\n\n  (defun my/gitlab--report (verb number &rest _)\n    \"Say that NUMBER was VERB'd. The callback for the two commands below.\"\n    (message \"%s !%s\" verb number))\n\n  (defun my/gitlab-approve-mr ()\n    \"Approve the GitLab merge request at point.\"\n    (interactive)\n    (let* ((mr (my/forge--gitlab-mr t))\n           (n (oref mr number)))\n      (when (y-or-n-p (format \"Approve !%s: %s? \" n (oref mr title)))\n        (forge--glab-post mr \"/projects/:project/merge_requests/:number/approve\" nil\n          :callback (apply-partially #'my/gitlab--report \"Approved\" n)))))\n\n  (defun my/gitlab-unapprove-mr ()\n    \"Withdraw your approval of the GitLab merge request at point.\"\n    (interactive)\n    (let* ((mr (my/forge--gitlab-mr t))\n           (n (oref mr number)))\n      (when (y-or-n-p (format \"Withdraw approval of !%s? \" n))\n        (forge--glab-post mr \"/projects/:project/merge_requests/:number/unapprove\" nil\n          :callback (apply-partially #'my/gitlab--report \"Unapproved\" n))))))\n\n(defvar my/gitlab-reviewer nil\n  \"GitLab username to treat as \\\"me\\\" when listing review requests.\")\n\n(defun my/gitlab-list-my-reviews (&optional reread)\n  \"List open merge requests across tracked repositories awaiting my review.\nWith a prefix argument REREAD, ask for the username again.\n\nReads forge's database rather than the API, so a repository appears only\nonce it is tracked and pulled -- `forge-add-repository' then `forge-pull'.\nThat is the trade for the rest working: topics here open with\n`forge-topic-menu', where the diff and approval commands above live.\"\n  (interactive \"P\")\n  (require 'forge)\n  (when (or reread (not my/gitlab-reviewer))\n    (setq my/gitlab-reviewer\n          (if (forge-get-repository :tracked?)\n              (forge--read-filter-by-user \"Review requests for\")\n            (read-string \"Review requests for (GitLab username): \"))))\n  (forge-topics-setup-buffer nil nil\n                             :global t\n                             :type 'pullreq\n                             :active t\n                             :reviewer my/gitlab-reviewer)\n  (transient-setup 'forge-topics-menu))")

(when work/colemak
(work/load-module "keybinds.nix" '()
  "(defun my/colemak-rotate-states ()\n  \"Rotate the four evil state maps, capitals included.\"\n  (dolist (map (list evil-motion-state-map\n                     evil-normal-state-map\n                     evil-visual-state-map\n                     evil-operator-state-map))\n    (my/colemak-rotate map (append my/colemak-swaps\n                                   my/colemak-swaps-shifted))))\n\n(my/colemak-rotate-states)\n\n(add-hook 'emacs-startup-hook #'my/colemak-rotate-states)\n\n(evil-define-key 'normal 'global\n  (kbd \"C-p\") #'evil-scroll-line-down\n  (kbd \"C-e\") #'evil-scroll-line-up)\n\n(evil-define-key 'normal 'global\n  (kbd \"C-S-p\") #'evil-scroll-down\n  (kbd \"C-S-e\") #'evil-scroll-up)")
)

(work/load-module "keybinds.nix" '()
  "(defun my/delete-char-no-yank (count)\n  \"Delete COUNT characters forward, leaving the unnamed register alone.\"\n  (interactive \"p\")\n  (evil-delete-char (point) (min (point-max) (+ (point) count)) 'exclusive ?_))\n\n(defun my/delete-backward-char-no-yank (count)\n  \"Delete COUNT characters backward, leaving the unnamed register alone.\"\n  (interactive \"p\")\n  (evil-delete-backward-char\n   (max (point-min) (- (point) count)) (point) 'exclusive ?_))\n\n(evil-define-key 'normal 'global\n  \"x\" #'my/delete-char-no-yank\n  \"X\" #'my/delete-backward-char-no-yank\n  (kbd \"<delete>\") #'my/delete-char-no-yank)\n\n(evil-define-key 'normal 'global\n  \"+\" #'evil-numbers/dec-at-pt\n  \"-\" #'evil-numbers/inc-at-pt)\n\n(evil-define-key 'normal 'global\n  (kbd \"TAB\") #'indent-for-tab-command)\n\n(defvar-local my/vterm-escape-target nil\n  \"Where <escape> goes in this vterm.\n`process' hands it to the program, `evil' keeps it for normal state, and nil\ndecides from the buffer name.\")\n\n(defun my/vterm-escape-to-process-p ()\n  \"Whether <escape> belongs to the program running in this vterm.\"\n  (pcase my/vterm-escape-target\n    ('process t)\n    ('evil nil)\n    (_ (string-prefix-p \"*claude-code[\" (buffer-name)))))\n\n(defun my/vterm-escape ()\n  \"Leave the terminal, or send <escape> on to a program that reads it.\"\n  (interactive)\n  (if (my/vterm-escape-to-process-p)\n      (vterm-send-escape)\n    (evil-normal-state)))\n\n(defun my/vterm-escape-toggle ()\n  \"Flip where <escape> goes in this terminal.\nFor the other programs that read it: nvim over ssh, htop, a nested emacs.\"\n  (interactive)\n  (setq my/vterm-escape-target\n        (if (my/vterm-escape-to-process-p) 'evil 'process))\n  (message \"<escape> -> %s\"\n           (if (eq my/vterm-escape-target 'process) \"the program\" \"normal state\")))\n\n(with-eval-after-load 'vterm\n  (evil-define-key '(insert emacs) vterm-mode-map\n    (kbd \"<escape>\") #'my/vterm-escape\n    (kbd \"C-\\\\\") #'evil-normal-state))\n\n(evil-define-key '(normal insert) 'global\n  (kbd \"C-k\") #'my/lsp-signature-help)\n\n(defun my/escape-dwim ()\n  \"Drop whatever is in progress and settle in normal state.\"\n  (interactive)\n  (cond\n   ((minibufferp) (abort-recursive-edit))\n   ((region-active-p) (deactivate-mark))\n   ((not (evil-normal-state-p)) (evil-force-normal-state))\n   (t (keyboard-quit))))\n\n(global-set-key (kbd \"C-<escape>\") esc-map)\n\n(global-set-key (kbd \"<escape>\") #'my/escape-dwim)")

(work/load-module "portability" '(lsp-mode) ";;; emacs-portability.el --- Runtime portability, not personal settings -*- lexical-binding: t; -*-\n;; Keep the source features while resolving tools outside Nix.\n(require 'treesit)\n(defvar work/grammar-sources\n  '((bash \"https://github.com/tree-sitter/tree-sitter-bash\")\n    (c \"https://github.com/tree-sitter/tree-sitter-c\")\n    (cpp \"https://github.com/tree-sitter/tree-sitter-cpp\")\n    (css \"https://github.com/tree-sitter/tree-sitter-css\")\n    (dockerfile \"https://github.com/camdencheek/tree-sitter-dockerfile\")\n    (go \"https://github.com/tree-sitter/tree-sitter-go\")\n    (html \"https://github.com/tree-sitter/tree-sitter-html\")\n    (javascript \"https://github.com/tree-sitter/tree-sitter-javascript\" \"master\" \"src\")\n    (json \"https://github.com/tree-sitter/tree-sitter-json\")\n    (lua \"https://github.com/tree-sitter-grammars/tree-sitter-lua\")\n    (nix \"https://github.com/nix-community/tree-sitter-nix\")\n    (python \"https://github.com/tree-sitter/tree-sitter-python\")\n    (rust \"https://github.com/tree-sitter/tree-sitter-rust\")\n    (toml \"https://github.com/tree-sitter-grammars/tree-sitter-toml\")\n    (tsx \"https://github.com/tree-sitter/tree-sitter-typescript\" \"master\" \"tsx/src\")\n    (typescript \"https://github.com/tree-sitter/tree-sitter-typescript\" \"master\" \"typescript/src\")\n    (yaml \"https://github.com/tree-sitter-grammars/tree-sitter-yaml\")))\n(dolist (source work/grammar-sources) (add-to-list 'treesit-language-source-alist source))\n(defun work/install-grammars ()\n  \"Build the coding language grammars. Requires Git and a C/C++ toolchain.\"\n  (interactive)\n  (unless (treesit-available-p) (user-error \"This Emacs needs tree-sitter support\"))\n  (let (failures)\n    (dolist (source work/grammar-sources)\n      (unless (treesit-language-available-p (car source))\n        (condition-case err (treesit-install-language-grammar (car source))\n          (error (push (cons (car source) (error-message-string err)) failures)))))\n    (if failures\n        (error \"Some grammars failed (other languages were still attempted): %S\" (nreverse failures))\n      (message \"Work grammars installed. Restart Emacs.\"))))\n\n;; Keep classic modes available until grammars have been built. All syntax-aware\n;; features activate with the same modes once their grammar is available.\n(defun work/grammar-ready-p (language) (treesit-language-available-p language))\n(let ((mode-languages '((js-ts-mode . javascript) (json-ts-mode . json)\n                       (typescript-ts-mode . typescript) (tsx-ts-mode . tsx)\n                       (css-ts-mode . css) (yaml-ts-mode . yaml)\n                       (bash-ts-mode . bash) (python-ts-mode . python)\n                       (go-ts-mode . go) (lua-ts-mode . lua) (toml-ts-mode . toml))))\n  (setq major-mode-remap-alist\n        (seq-filter (lambda (pair)\n                      (let ((lang (alist-get (cdr pair) mode-languages)))\n                        (or (not lang) (work/grammar-ready-p lang))))\n                    major-mode-remap-alist))\n  (unless (work/grammar-ready-p 'tsx)\n    (setf (alist-get \"\\\\.tsx\\\\'\" auto-mode-alist nil nil #'equal) 'web-mode\n          (alist-get \"\\\\.jsx\\\\'\" auto-mode-alist nil nil #'equal) 'web-mode))\n  (unless (work/grammar-ready-p 'typescript)\n    (setf (alist-get \"\\\\.mts\\\\'\" auto-mode-alist nil nil #'equal) 'typescript-mode\n          (alist-get \"\\\\.cts\\\\'\" auto-mode-alist nil nil #'equal) 'typescript-mode)))\n(dolist (entry '((\"\\\\.go\\\\'\" . go-mode) (\"\\\\.lua\\\\'\" . lua-mode)\n                 (\"\\\\.ya?ml\\\\'\" . yaml-mode) (\"\\\\.json\\\\'\" . json-mode)))\n  (when (fboundp (cdr entry)) (add-to-list 'auto-mode-alist entry)))\n;; nix-ts-mode has no classic fallback in the source; use nix-mode until built.\n(when (and (not (treesit-language-available-p 'nix)) (require 'nix-mode nil t))\n  (setf (alist-get \"\\\\.nix\\\\'\" auto-mode-alist nil nil #'equal) 'nix-mode))\n;; Keep LSP on classic modes too while grammars are absent.\n(dolist (hook '(js-mode-hook typescript-mode-hook python-mode-hook go-mode-hook\n                lua-mode-hook css-mode-hook yaml-mode-hook json-mode-hook nix-mode-hook))\n  (add-hook hook #'lsp-deferred))\n(when (and (< emacs-major-version 31) (require 'corfu-terminal nil t))\n  (corfu-terminal-mode 1))\n;; Linux uses libnotify; macOS uses the platform notifier when available.\n(when (eq system-type 'darwin) (setq alert-default-style 'osx-notifier))\n;; GUI login-shell import can replace PATH; restore the private work tools after it.\n(let* ((root (expand-file-name \"work-vdi/tools/\"\n                               (or (getenv \"XDG_DATA_HOME\") \"~/.local/share/\")))\n       (paths (list (expand-file-name \"bin\" root)\n                    (expand-file-name \"python/bin\" root)\n                    (expand-file-name \"~/.local/bin\"))))\n  (dolist (path (reverse paths))\n    (when (file-directory-p path)\n      (add-to-list 'exec-path path)\n      (setenv \"PATH\" (concat path path-separator (getenv \"PATH\"))))))\n\n;; Work stack: Java/Spring Boot, PHP/Laravel, Vue/Nuxt, Python/FastAPI and markup.\n(dolist (source '((java \"https://github.com/tree-sitter/tree-sitter-java\")\n                  (php \"https://github.com/tree-sitter/tree-sitter-php\" nil \"php/src\")\n                  (php_only \"https://github.com/tree-sitter/tree-sitter-php\" nil \"php_only/src\")\n                  (scss \"https://github.com/serenadeai/tree-sitter-scss\")\n                  (xml \"https://github.com/tree-sitter-grammars/tree-sitter-xml\" nil \"xml/src\")\n                  (dtd \"https://github.com/tree-sitter-grammars/tree-sitter-xml\" nil \"dtd/src\")\n                  (vue \"https://github.com/tree-sitter-grammars/tree-sitter-vue\")\n                  (blade \"https://github.com/EmranMR/tree-sitter-blade\")\n                  (properties \"https://github.com/tree-sitter-grammars/tree-sitter-properties\")))\n  (add-to-list 'work/grammar-sources source)\n  (add-to-list 'treesit-language-source-alist source))\n(when (and (fboundp 'java-ts-mode) (treesit-language-available-p 'java))\n  (add-to-list 'major-mode-remap-alist '(java-mode . java-ts-mode)))\n(add-to-list 'auto-mode-alist '(\"\\\\.php\\\\'\" . php-mode))\n(add-to-list 'auto-mode-alist '(\"\\\\.blade\\\\.php\\\\'\" . web-mode))\n(dolist (extension '(\"xml\" \"xsd\" \"xsl\" \"xslt\" \"svg\" \"wsdl\" \"fxml\"))\n  (add-to-list 'auto-mode-alist (cons (concat \"\\\\.\" extension \"\\\\'\") 'nxml-mode)))\n(defun work/blade-p ()\n  \"Whether this buffer is a Laravel Blade template.\"\n  (and buffer-file-name (string-suffix-p \".blade.php\" buffer-file-name)))\n(defun work/web-stack ()\n  \"Select the right embedded language for a Blade template.\"\n  (when (work/blade-p)\n    (setq-local web-mode-engine \"blade\")\n    (setq-local lsp-language-id-configuration\n                (cons '(web-mode . \"php\") lsp-language-id-configuration))))\n(add-hook 'web-mode-hook #'work/web-stack)\n(with-eval-after-load 'lsp-mode\n  (let ((tools (expand-file-name \"work-vdi/tools/\"\n                                 (or (getenv \"XDG_DATA_HOME\") \"~/.local/share/\"))))\n    (setq lsp-java-server-install-dir (expand-file-name \"share/jdtls/\" tools)\n          lsp-java-jdt-ls-prefer-native-command t\n          lsp-java-jdt-ls-command \"jdtls\"\n          lsp-java-format-enabled t))\n  (lsp-register-client\n   (make-lsp-client :new-connection (lsp-stdio-connection '(\"intelephense\" \"--stdio\"))\n                    :activation-fn (lambda (file _mode)\n                                     (and file (string-match-p \"\\\\.php\\\\'\" file)))\n                    :server-id 'work-php :priority 10))\n  (lsp-register-client\n   (make-lsp-client :new-connection (lsp-stdio-connection '(\"lemminx\"))\n                    :major-modes '(nxml-mode xml-mode)\n                    :server-id 'work-xml :priority 10))\n  (lsp-register-client\n   (make-lsp-client :new-connection (lsp-stdio-connection '(\"ruff\" \"server\"))\n                    :major-modes '(python-mode python-ts-mode)\n                    :server-id 'work-ruff :priority 10 :add-on? t)))\n(defun work/java-start ()\n  \"Start JDTLS with Maven/Gradle project support.\"\n  (if (require 'lsp-java nil t) (lsp-deferred)\n    (display-warning 'work-vdi \"Java needs lsp-java: run M-x work/install-packages.\" :warning)))\n(add-hook 'java-mode-hook #'work/java-start)\n(add-hook 'java-ts-mode-hook #'work/java-start)\n(add-hook 'php-mode-hook #'lsp-deferred)\n(add-hook 'nxml-mode-hook #'lsp-deferred)\n(defun work/formatter-available-p (kind)\n  \"Whether the shared KIND formatter can handle this buffer.\"\n  (and buffer-file-name (executable-find \"work-format\")\n       (eq 0 (call-process \"work-format\" nil nil nil \"--available\" kind buffer-file-name))))\n(defvar-local work/lsp-format-on-save nil)\n(defun work/lsp-format-save ()\n  \"Use the language server when it supplies this buffer's formatter.\"\n  (when (and work/lsp-format-on-save (bound-and-true-p lsp-mode)\n             (lsp-feature? \"textDocument/formatting\"))\n    (lsp-format-buffer)))\n(defun work/stack-formatter ()\n  \"Choose project-aware formatting, falling back to the attached language server.\"\n  (let ((kind (cond ((work/blade-p) \"blade\")\n                    ((derived-mode-p 'php-mode) \"php\")\n                    ((derived-mode-p 'nxml-mode) \"xml\"))))\n    (when (or kind (derived-mode-p 'java-mode 'java-ts-mode))\n      (if (and kind (work/formatter-available-p kind))\n          (progn (setq-local apheleia-formatter (intern (concat \"work-\" kind)))\n                 (setq-local work/lsp-format-on-save nil)\n                 (when (fboundp 'apheleia-mode) (apheleia-mode 1)))\n        (setq-local work/lsp-format-on-save t)\n        (when (fboundp 'apheleia-mode) (apheleia-mode -1)))\n      (add-hook 'before-save-hook #'work/lsp-format-save nil t))))\n(with-eval-after-load 'apheleia\n  (dolist (kind '(php xml blade))\n    (setf (alist-get (intern (concat \"work-\" (symbol-name kind))) apheleia-formatters)\n          (list \"work-format\" (symbol-name kind) 'filepath))))\n(add-hook 'after-change-major-mode-hook #'work/stack-formatter t)\n\n;; Stable shared tsserver fallback; workspace language runtimes stay project-owned.\n(when work/npm-root\n  (let ((server (expand-file-name \"typescript/lib/tsserver.js\" work/npm-root)))\n    (when (file-exists-p server)\n      (setq lsp-clients-typescript-server-args (list \"--stdio\" \"--tsserver-path\" server)))))\n\n;; Keep the manual format command and the save hook consistent with project tools.\n(with-eval-after-load 'apheleia\n  (dolist (mode '(yaml-mode yaml-ts-mode))\n    (setf (alist-get mode apheleia-mode-alist)\n          (if (executable-find \"yamlfmt\") 'yamlfmt 'prettierd))))\n(defun work/stack-own-formatter-p ()\n  (or work/lsp-format-on-save\n      (memq (bound-and-true-p apheleia-formatter) '(work-php work-xml work-blade))))\n(when (fboundp 'my/format-fallback-to-lsp)\n  (advice-add 'my/format-fallback-to-lsp :before-while\n              (lambda () (not (work/stack-own-formatter-p)))))\n(defun work/manual-stack-format (original &rest args)\n  (cond (work/lsp-format-on-save\n         (if (bound-and-true-p lsp-mode) (lsp-format-buffer)\n           (user-error \"Language server is not attached; see M-x work/doctor\")))\n        ((memq (bound-and-true-p apheleia-formatter) '(work-php work-xml work-blade))\n         (apheleia-format-buffer apheleia-formatter))\n        (t (apply original args))))\n(when (fboundp 'my/format-buffer)\n  (advice-add 'my/format-buffer :around #'work/manual-stack-format))\n")

(when (and work/module-errors (not (getenv "WORK_VDI_BOOTSTRAP")))
  (display-warning 'work-vdi "Some work modules need setup. Run M-x work/doctor for details." :warning))
WORK_VDI_FILE_END
backup "$config_root/work-emacs/early-init.el" "early-init.el"
cat > "$config_root/work-emacs/early-init.el" <<'WORK_VDI_FILE_END'
;;; early-init.el --- Work editor frame setup -*- lexical-binding: t; -*-
(push '(background-color . "#24283b") default-frame-alist)
(push '(foreground-color . "#c0caf5") default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars . nil) default-frame-alist)
(defun work/frame-fonts (&optional frame)
  "Use source fonts when installed, falling back to the VDI's default font."
  (when (display-graphic-p frame)
    (with-selected-frame (or frame (selected-frame))
      (when (find-font (font-spec :family "JetBrainsMono Nerd Font Mono"))
        (set-frame-font "JetBrainsMono Nerd Font Mono-12" nil))
      (when (find-font (font-spec :family "JuliaMono"))
        (set-fontset-font t '(#x2190 . #x2bff) "JuliaMono" nil 'append)))))
(add-hook 'after-make-frame-functions #'work/frame-fonts)
(add-hook 'window-setup-hook #'work/frame-fonts)
WORK_VDI_FILE_END
backup "$config_root/work-emacs/banner.txt" "banner.txt"
cat > "$config_root/work-emacs/banner.txt" <<'WORK_VDI_FILE_END'
███████╗███╗   ███╗ █████╗  ██████╗███████╗
██╔════╝████╗ ████║██╔══██╗██╔════╝██╔════╝
█████╗  ██╔████╔██║███████║██║     ███████╗
██╔══╝  ██║╚██╔╝██║██╔══██║██║     ╚════██║
███████╗██║ ╚═╝ ██║██║  ██║╚██████╗███████║
╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝╚══════╝
WORK_VDI_FILE_END
backup "$config_root/work-emacs/language-stack.json" "language-stack.json"
cat > "$config_root/work-emacs/language-stack.json" <<'WORK_VDI_FILE_END'
{
  "grammars": [
    "bash",
    "blade",
    "c",
    "cpp",
    "css",
    "dockerfile",
    "dtd",
    "go",
    "graphql",
    "haskell",
    "html",
    "java",
    "javadoc",
    "javascript",
    "jsdoc",
    "json",
    "lua",
    "markdown",
    "markdown_inline",
    "nix",
    "php",
    "php_only",
    "phpdoc",
    "properties",
    "python",
    "regex",
    "rust",
    "scss",
    "sql",
    "toml",
    "tsx",
    "typescript",
    "vue",
    "xml",
    "yaml"
  ],
  "npm": [
    "typescript@5.9.3",
    "typescript-language-server",
    "@vue/language-server",
    "@vue/typescript-plugin",
    "@angular/language-server",
    "@tailwindcss/language-server",
    "@prisma/language-server",
    "@olrtg/emmet-language-server",
    "bash-language-server",
    "vscode-langservers-extracted",
    "yaml-language-server",
    "pyright",
    "intelephense",
    "prettier",
    "@fsouza/prettierd",
    "@prettier/plugin-xml",
    "blade-formatter",
    "tree-sitter-cli"
  ],
  "pip": [
    "black",
    "ruff",
    "yamllint"
  ],
  "jdtls_url": "https://www.eclipse.org/downloads/download.php?file=/jdtls/milestones/1.57.0/jdt-language-server-1.57.0-202602261110.tar.gz&r=1",
  "lombok_url": "https://projectlombok.org/downloads/lombok.jar",
  "lemminx_version": "0.29.3"
}
WORK_VDI_FILE_END
backup "$config_root/work-emacs/helpers/claude-session-index" "claude-session-index"
cat > "$config_root/work-emacs/helpers/claude-session-index" <<'WORK_VDI_FILE_END'
#!/usr/bin/env python3
import glob
import json
import os
import sys
import time

root = os.path.expanduser("~/.claude/projects")

# The desktop app keeps its own metadata beside the CLI transcripts, under
# Application Support/Claude/claude-code-sessions/<account>/<workspace>/.
# It carries a human title ("Nix flake inputs update") where the CLI store
# has only the opening prompt, and links to the transcript by cliSessionId.
# Same conversations, better labels -- so titles are borrowed where they
# exist and the prompt is the fallback.
titles = {}
desktop = os.path.expanduser(
    "~/Library/Application Support/Claude/claude-code-sessions"
)
for meta_path in glob.glob(os.path.join(desktop, "**", "local_*.json"), recursive=True):
    try:
        with open(meta_path, errors="replace") as fh:
            meta = json.load(fh)
    except (ValueError, OSError):
        continue
    cli_id = meta.get("cliSessionId")
    title = meta.get("title")
    if cli_id and title:
        titles[cli_id] = title

rows = []
for path in glob.glob(os.path.join(root, "**", "*.jsonl"), recursive=True):
    cwd = branch = prompt = None
    sidechain = False
    sid = os.path.basename(path)[:-6]
    try:
        with open(path, errors="replace") as fh:
            for i, line in enumerate(fh):
                if i > 40:
                    break
                try:
                    d = json.loads(line)
                except ValueError:
                    continue
                cwd = cwd or d.get("cwd")
                branch = branch or d.get("gitBranch")
                sid = d.get("sessionId") or sid
                # Sidechains are subagent transcripts. `claude --resume' cannot
                # open one, so a row for it is an entry that only ever fails.
                # Labelling it "[subagent]" and listing it anyway -- which is
                # what this did -- is how a fifth of the picker became unusable.
                if d.get("isSidechain"):
                    sidechain = True
                    break
                if prompt is None and d.get("type") == "user":
                    msg = d.get("message") or {}
                    content = msg.get("content")
                    if isinstance(content, str):
                        prompt = content
                    elif isinstance(content, list):
                        for part in content:
                            if isinstance(part, dict) and part.get("type") == "text":
                                prompt = part.get("text")
                                break
                if prompt and cwd:
                    break
        mtime = os.path.getmtime(path)
        size = os.path.getsize(path)
    except OSError:
        continue
    if sidechain:
        continue
    # Skip the near-empty ones: a session that never got a reply is noise.
    if size < 2048:
        continue
    # And the ones with nowhere to run. Claude resolves a session against
    # its project directory, so a conversation from a deleted worktree or a
    # moved repository cannot be resumed from anywhere. Most of these are
    # the throwaway .claude/worktrees/* that agent runs leave behind.
    if not cwd or not os.path.isdir(cwd):
        continue
    text = titles.get(sid) or " ".join((prompt or "(no prompt)").split())[:90]
    rows.append((mtime, cwd, branch or "", text, sid, path))

rows.sort(reverse=True)
for mtime, cwd, branch, text, sid, path in rows:
    stamp = time.strftime("%Y-%m-%d %H:%M", time.localtime(mtime))
    sys.stdout.write("\t".join([stamp, os.path.basename(cwd), branch, text, sid, cwd, path]) + "\n")
WORK_VDI_FILE_END
backup "$config_root/work-emacs/helpers/claude-transcript" "claude-transcript"
cat > "$config_root/work-emacs/helpers/claude-transcript" <<'WORK_VDI_FILE_END'
#!/usr/bin/env python3
import json
import sys

for line in open(sys.argv[1], errors="replace"):
    try:
        d = json.loads(line)
    except ValueError:
        continue
    if d.get("type") not in ("user", "assistant"):
        continue
    msg = d.get("message") or {}
    content = msg.get("content")
    parts = []
    if isinstance(content, str):
        parts.append(content)
    elif isinstance(content, list):
        for part in content:
            if isinstance(part, dict) and part.get("type") == "text":
                parts.append(part.get("text") or "")
    body = "\n".join(p for p in parts if p.strip())
    if body.strip():
        who = "##" if d.get("type") == "user" else "###"
        sys.stdout.write("%s %s\n\n%s\n\n" % (who, d.get("type"), body))
WORK_VDI_FILE_END
backup "$config_root/work-emacs/helpers/claude-usage-today" "claude-usage-today"
cat > "$config_root/work-emacs/helpers/claude-usage-today" <<'WORK_VDI_FILE_END'
#!/usr/bin/env python3
"""Sum today's Claude Code token usage across every session transcript."""

import datetime
import json
import os
import pathlib
import sys

ROOT = pathlib.Path.home() / ".claude" / "projects"
CACHE = pathlib.Path(
    os.environ.get("XDG_CACHE_HOME", pathlib.Path.home() / ".cache")
) / "claude-usage"
STATE = CACHE / "state.json"

FIELDS = {
    "input": "input_tokens",
    "output": "output_tokens",
    "cache_write": "cache_creation_input_tokens",
    "cache_read": "cache_read_input_tokens",
}


def local_date(stamp):
    """The local calendar date of an ISO-8601 UTC timestamp, or None."""
    try:
        when = datetime.datetime.fromisoformat(stamp.replace("Z", "+00:00"))
    except (AttributeError, ValueError):
        return None
    return when.astimezone().date()


def load_state():
    try:
        with STATE.open() as handle:
            state = json.load(handle)
    except (OSError, ValueError):
        state = {}
    state.setdefault("date", "")
    state.setdefault("files", {})
    return state


def main():
    today = datetime.date.today()
    midnight = datetime.datetime.combine(
        today, datetime.time.min
    ).timestamp()

    state = load_state()
    fresh_day = state["date"] != today.isoformat()
    totals = {key: 0 for key in FIELDS}
    totals["messages"] = 0
    if not fresh_day:
        for key in totals:
            totals[key] = state.get("totals", {}).get(key, 0)

    # The substring gate. A UTC day straddles two local ones and the other
    # way round, so both UTC dates that can carry a local-today message are
    # let through and the real check happens after parsing.
    day = datetime.timedelta(days=1)
    stamps = tuple(
        '"timestamp":"%s' % d.isoformat()
        for d in (today - day, today, today + day)
    )

    files = {}
    paths = sorted(ROOT.rglob("*.jsonl")) if ROOT.is_dir() else []
    for path in paths:
        name = str(path)
        try:
            stat = path.stat()
        except OSError:
            continue
        offset = state["files"].get(name, 0)
        # Untouched today: nothing of today's can be in it, and its offset
        # is worth keeping so tomorrow does not re-read it either.
        if stat.st_mtime < midnight:
            files[name] = min(offset, stat.st_size)
            continue
        # Truncated or replaced since the last run: start over.
        if offset > stat.st_size:
            offset = 0
        try:
            with path.open("rb") as handle:
                handle.seek(offset)
                data = handle.read()
        except OSError:
            files[name] = offset
            continue
        # Only whole lines: the file may be mid-write.
        cut = data.rfind(b"\n")
        if cut == -1:
            files[name] = offset
            continue
        files[name] = offset + cut + 1
        for raw in data[:cut].split(b"\n"):
            line = raw.decode("utf-8", "replace")
            if not any(stamp in line for stamp in stamps):
                continue
            try:
                record = json.loads(line)
            except ValueError:
                continue
            message = record.get("message")
            if not isinstance(message, dict):
                continue
            usage = message.get("usage")
            if not isinstance(usage, dict):
                continue
            if local_date(record.get("timestamp")) != today:
                continue
            totals["messages"] += 1
            for key, field in FIELDS.items():
                value = usage.get(field)
                if isinstance(value, int):
                    totals[key] += value

    totals["billable"] = (
        totals["input"] + totals["output"] + totals["cache_write"]
    )
    try:
        CACHE.mkdir(parents=True, exist_ok=True)
        with STATE.open("w") as handle:
            json.dump(
                {
                    "date": today.isoformat(),
                    "totals": totals,
                    "files": files,
                },
                handle,
            )
    except OSError:
        pass

    json.dump(dict(totals, date=today.isoformat()), sys.stdout)
    sys.stdout.write("\n")


main()
WORK_VDI_FILE_END
backup "$config_root/work-emacs/helpers/install-editors.py" "install-editors.py"
cat > "$config_root/work-emacs/helpers/install-editors.py" <<'WORK_VDI_FILE_END'
#!/usr/bin/env python3
"""Install versioned Linux editors and ordinary commands in a user's home."""
import hashlib, importlib.util, os, pathlib, platform, shlex, shutil, subprocess, sys, tempfile, time

NVIM_VERSION = '0.12.6'
EMACS_VERSION = '30.2'
NVIM_HASHES = {
    'x86_64': '474430d53e6264f6d6dd18db42d6dc9df3a1b56ca9e88a325bbf860e1a811d87',
    'aarch64': '8f1f64a0bdb97247034038c3823c6cbad5bdf9ecd5751b85494b71c3ee04c815',
}
EMACS_HASHES = {
    'x86_64': '9bce97b2f3638d9d74181d0ff6a8a8da79368aafe27727d6cd8519f1502aa31d',
    'aarch64': '55ab47ac564bfbc94ff92e71d14a231dd195cce61427d7b64c97ce7d177048a5',
}


def support():
    spec = importlib.util.spec_from_file_location('native_tools', pathlib.Path(__file__).with_name('install-native-tools.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def download(native, url, path, digest):
    native.fetch(url, path)
    with path.open('rb') as stream:
        actual = hashlib.file_digest(stream, 'sha256').hexdigest() if sys.version_info >= (3, 11) else None
    if actual is None:
        hasher = hashlib.sha256()
        with path.open('rb') as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                hasher.update(chunk)
        actual = hasher.hexdigest()
    if actual != digest:
        raise RuntimeError('Checksum mismatch for ' + url)


def validate(name, command):
    if name == 'nvim':
        args = ['--headless', '-u', 'NONE', '-i', 'NONE', '+lua if vim.fn.has("nvim-0.12")==0 then vim.cmd("cquit 1") end', '+qa']
    else:
        args = ['--batch', '-Q', '--eval', '(unless (and (>= emacs-major-version 29) (fboundp (quote treesit-available-p)) (treesit-available-p) (bound-and-true-p module-file-suffix)) (kill-emacs 1))']
    result = subprocess.run([str(command), *args], capture_output=True, text=True, timeout=60)
    if result.returncode:
        raise RuntimeError(f'{name} cannot run with the required features on this VDI:\n{result.stderr[-3000:]}')


def replace_file(path, text, executable=False):
    if path.is_file() and not path.is_symlink() and path.read_bytes() == text.encode():
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() or path.is_symlink():
        backup = path.with_name(path.name + '.before-work-vdi-' + str(time.time_ns()))
        path.rename(backup)
    path.write_text(text)
    if executable:
        path.chmod(0o755)


def install(home, data):
    if platform.system() != 'Linux':
        raise RuntimeError('--editors currently supports Linux/WSL; install editors normally on macOS.')
    arch = {'x86_64': 'x86_64', 'aarch64': 'aarch64', 'arm64': 'aarch64'}.get(platform.machine())
    if arch is None:
        raise RuntimeError('Editor downloads support Linux x86_64 and aarch64.')
    native = support()
    root = data / 'work-vdi/editors'
    root.mkdir(parents=True, exist_ok=True)
    installed = {}
    for name, version in [('nvim', NVIM_VERSION), ('emacs', EMACS_VERSION)]:
        target = root / (name + '-' + version)
        binary = target / ('bin/nvim' if name == 'nvim' else 'AppRun')
        if not binary.is_file():
            with tempfile.TemporaryDirectory(prefix='.' + name + '-', dir=root) as tmp:
                tmp = pathlib.Path(tmp)
                if name == 'nvim':
                    package = 'nvim-linux-' + ('arm64' if arch == 'aarch64' else arch)
                    archive = tmp / 'nvim.tar.gz'
                    download(native, f'https://github.com/neovim/neovim/releases/download/v{version}/{package}.tar.gz', archive, NVIM_HASHES[arch])
                    native.unpack_tar(archive, tmp)
                    stage = tmp / package
                    candidate = stage / 'bin/nvim'
                else:
                    image = tmp / 'emacs.AppImage'
                    url = f'https://github.com/blahgeek/emacs-appimage/releases/download/github-action-build-17008212441/Emacs-{version}-lucid-{arch}.AppImage'
                    download(native, url, image, EMACS_HASHES[arch])
                    image.chmod(0o755)
                    # Extract once: no FUSE package or privileged mount is needed.
                    result = subprocess.run([str(image), '--appimage-extract'], cwd=tmp, capture_output=True, text=True, timeout=180)
                    if result.returncode:
                        raise RuntimeError('Cannot extract Emacs AppImage: ' + result.stderr[-2000:])
                    stage = tmp / 'squashfs-root'
                    candidate = stage / 'AppRun'
                validate(name, candidate)
                native.activate(stage, target)
        validate(name, binary)
        command = home / '.local/bin' / name
        replace_file(command, '#!/bin/sh\nexec ' + shlex.quote(str(binary)) + ' "$@"\n', executable=True)
        installed[name] = command
    env_file = data / 'work-vdi/env.sh'
    replace_file(env_file, '# Work VDI user-installed editor commands\nexport PATH="$HOME/.local/bin:$PATH"\n')
    marker = '# Work VDI editor commands'
    block = '\n' + marker + '\n. ' + shlex.quote(str(env_file)) + '\n'
    shell_files = ['.profile', '.bashrc', '.zshrc']
    shell_files += [name for name in ['.bash_profile', '.bash_login'] if (home / name).exists()]
    for filename in shell_files:
        rc = home / filename
        old = rc.read_text() if rc.exists() else ''
        if marker not in old:
            # Preserve the shell file's identity (including symlinks) and contents.
            if rc.exists():
                shutil.copyfile(rc, rc.with_name(rc.name + '.before-work-vdi-' + str(time.time_ns())))
            with rc.open('a') as stream:
                stream.write(block)
    for name, command in installed.items():
        # Desktop Exec fields use double-quote escaping, not shell quoting.
        quoted = '"' + str(command).replace('\\', '\\\\').replace('"', '\\"').replace('`', '\\`').replace('$', '\\$').replace('%', '%%') + '"'
        desktop = f'[Desktop Entry]\nType=Application\nName={"Emacs" if name == "emacs" else "Neovim"}\nExec={quoted} %F\nIcon=accessories-text-editor\nTerminal={"true" if name == "nvim" else "false"}\nCategories=Development;TextEditor;\n'
        replace_file(data / 'applications' / (name + '.desktop'), desktop)
    print('Installed Neovim ' + NVIM_VERSION + ' and Emacs ' + EMACS_VERSION + ' without sudo.')
    print('Open a new terminal, or run: . ' + shlex.quote(str(env_file)))


if __name__ == '__main__':
    try:
        install(pathlib.Path.home(), pathlib.Path(os.environ.get('XDG_DATA_HOME', str(pathlib.Path.home() / '.local/share'))).resolve())
    except Exception as error:
        print('Editor installation failed: ' + str(error), file=sys.stderr)
        raise SystemExit(1)
WORK_VDI_FILE_END
backup "$config_root/work-emacs/helpers/install-native-tools.py" "install-native-tools.py"
cat > "$config_root/work-emacs/helpers/install-native-tools.py" <<'WORK_VDI_FILE_END'
#!/usr/bin/env python3
"""Install shared Java/XML servers into the work-tools prefix; no administrator rights."""
import json, os, pathlib, platform, shlex, shutil, stat, subprocess, sys, tarfile, tempfile, urllib.request, zipfile

def fetch(url,target):
    request=urllib.request.Request(url,headers={'User-Agent':'work-vdi-editor-installer/1.0'})
    try:
        with urllib.request.urlopen(request,timeout=120) as source,open(target,'wb') as out:shutil.copyfileobj(source,out)
    except Exception as error:raise RuntimeError(f'{url}: {error}') from error
def safe_path(root,name):
    path=(root/name).resolve()
    if not path.is_relative_to(root.resolve()):raise RuntimeError('Archive path escapes destination')
    return path
def unpack_tar(archive,destination):
    with tarfile.open(archive) as tar:
        for member in tar.getmembers():
            safe_path(destination,member.name)
            if member.issym():safe_path(destination,str(pathlib.PurePosixPath(member.name).parent/member.linkname))
            elif member.islnk():safe_path(destination,member.linkname)
            elif not (member.isfile() or member.isdir()):raise RuntimeError('Unsupported archive member')
        tar.extractall(destination,**({'filter':'data'} if sys.version_info>=(3,12) else {}))
def activate(stage,target):
    previous=target.with_name(target.name+'.previous')
    if previous.exists():shutil.rmtree(previous)
    if target.exists():target.rename(previous)
    stage.rename(target)
def install(root,spec):
    share=root/'share';share.mkdir(parents=True,exist_ok=True);(root/'bin').mkdir(parents=True,exist_ok=True)
    target=share/'jdtls'
    if not (target/'.work-source').exists() or (target/'.work-source').read_text()!=spec['jdtls_url']:
        with tempfile.TemporaryDirectory(dir=share,prefix='.jdtls-') as tmp:
            tmp=pathlib.Path(tmp);archive=tmp/'jdtls.tar.gz';stage=tmp/'server';stage.mkdir()
            fetch(spec['jdtls_url'],archive);unpack_tar(archive,stage)
            if not (stage/'bin/jdtls').is_file():raise RuntimeError('JDTLS archive has no launcher')
            fetch(spec['lombok_url'],stage/'lombok.jar')
            (stage/'.work-source').write_text(spec['jdtls_url']);activate(stage,target)
    launcher=root/'bin/jdtls'
    launcher.write_text('#!/bin/sh\nexec python3 '+shlex.quote(str(target/'bin/jdtls'))+' '+shlex.quote('--jvm-arg=-javaagent:'+str(target/'lombok.jar'))+' "$@"\n');launcher.chmod(0o755)
    system={'Linux':'linux','Darwin':'osx'}.get(platform.system());arch={'x86_64':'x86_64','aarch64':'aarch_64','arm64':'aarch_64'}.get(platform.machine())
    if not system or not arch:raise RuntimeError('No LemMinX distribution for this OS/architecture')
    binary='lemminx-'+system+'-'+arch
    url=f"https://github.com/redhat-developer/vscode-xml/releases/download/{spec['lemminx_version']}/{binary}.zip"
    target=share/'lemminx'
    if not (target/'.work-source').exists() or (target/'.work-source').read_text()!=url:
        with tempfile.TemporaryDirectory(dir=share,prefix='.lemminx-') as tmp:
            tmp=pathlib.Path(tmp);archive=tmp/'server.zip';stage=tmp/'server';stage.mkdir();fetch(url,archive)
            with zipfile.ZipFile(archive) as zipped:
                for entry in zipped.infolist():
                    safe_path(stage,entry.filename)
                    if stat.S_ISLNK(entry.external_attr>>16):raise RuntimeError('Unexpected archive symlink')
                zipped.extractall(stage)
            candidate=next(iter(stage.rglob(binary)),None)
            if candidate is None:raise RuntimeError('LemMinX archive has no server executable')
            if candidate!=stage/binary:shutil.copyfile(candidate,stage/binary)
            (stage/binary).chmod(0o755);(stage/'.work-source').write_text(url);activate(stage,target)
    launcher=root/'bin/lemminx';launcher.write_text('#!/bin/sh\nexec '+shlex.quote(str(target/binary))+' "$@"\n');launcher.chmod(0o755)
    print('Installed shared JDTLS (with Lombok) and LemMinX servers.')
    if not shutil.which('java'):print('Java support needs JDK 21+ on PATH or JAVA_HOME.',file=sys.stderr)
if __name__=='__main__':
    try:install(pathlib.Path(sys.argv[1]).resolve(),json.loads(pathlib.Path(sys.argv[2]).read_text()))
    except Exception as error:print('Work server installation failed: '+str(error),file=sys.stderr);raise SystemExit(1)
WORK_VDI_FILE_END
backup "$config_root/work-emacs/helpers/work-format" "work-format"
cat > "$config_root/work-emacs/helpers/work-format" <<'WORK_VDI_FILE_END'
#!/usr/bin/env python3
"""Shared stdin formatter. Prefer project tools; never replace the real source file."""
import json, os, pathlib, shutil, subprocess, sys, tempfile

def ancestors(file):
    parent=pathlib.Path(file).expanduser().resolve().parent
    return [parent,*parent.parents]
def local_tool(file,relative,fallback):
    for parent in ancestors(file):
        candidate=parent/relative
        if candidate.is_file() and os.access(candidate,os.X_OK):return str(candidate)
    return shutil.which(fallback)
def php_tool(file):
    for parent in ancestors(file):
        for relative,name in [('vendor/bin/pint','pint'),('vendor/bin/php-cs-fixer','php-cs-fixer'),('tools/php-cs-fixer/vendor/bin/php-cs-fixer','php-cs-fixer')]:
            p=parent/relative
            if p.is_file():return str(p),name,parent
    for name in ['pint','php-cs-fixer']:
        found=shutil.which(name)
        if found:return found,name,next((p for p in ancestors(file) if (p/'composer.json').exists()),pathlib.Path(file).resolve().parent)
    return None

def xml_plugin(file):
    tools=pathlib.Path(os.environ.get('XDG_DATA_HOME',str(pathlib.Path.home()/'.local/share')))/'work-vdi/tools'
    for root in [*(p/'node_modules' for p in ancestors(file)),tools/'lib/node_modules']:
        plugin=root/'@prettier/plugin-xml'
        if (plugin/'package.json').is_file():
            result=subprocess.run(['node','-e','process.stdout.write(require.resolve(process.argv[1]))',str(plugin)],capture_output=True,text=True)
            if result.returncode==0:return result.stdout
    return None

def main():
    args=sys.argv[1:];check=bool(args and args[0]=='--available')
    if check:args=args[1:]
    if len(args)!=2:raise SystemExit('usage: work-format [--available] php|xml|blade FILE')
    kind,file=args;file=str(pathlib.Path(file).expanduser().resolve())
    if kind=='php':
        selected=php_tool(file)
        if check:return 0 if selected and shutil.which('php') else 1
        if not selected:raise RuntimeError('Install project vendor/bin/pint or PHP-CS-Fixer, or use the PHP language-server formatter')
        executable,name,cwd=selected
        # A sibling temporary file preserves project-relative configuration lookup.
        with tempfile.NamedTemporaryFile(prefix='.work-vdi-format-',suffix='.php',dir=str(pathlib.Path(file).parent),delete=False) as out:
            temporary=pathlib.Path(out.name);out.write(sys.stdin.buffer.read())
        try:
            command=([executable,str(temporary)] if name=='pint' else [executable,'fix','--using-cache=no',str(temporary)])
            result=subprocess.run(command,cwd=cwd,capture_output=True,timeout=60)
            if result.returncode:raise RuntimeError(result.stderr.decode(errors='replace') or result.stdout.decode(errors='replace'))
            sys.stdout.buffer.write(temporary.read_bytes())
        finally:temporary.unlink(missing_ok=True)
        return 0
    if kind=='blade':
        executable=local_tool(file,'node_modules/.bin/blade-formatter','blade-formatter')
        if check:return 0 if executable else 1
        command=[executable,'--stdin'] if executable else None
        cwd=next((p for p in ancestors(file) if (p/'composer.json').exists()),pathlib.Path(file).parent)
    elif kind=='xml':
        executable=local_tool(file,'node_modules/.bin/prettier','prettier');plugin=xml_plugin(file) if executable else None
        if check:return 0 if executable and plugin else 1
        command=[executable,'--plugin',plugin,'--parser','xml','--stdin-filepath',file] if executable and plugin else None
        cwd=pathlib.Path(file).parent
    else:raise RuntimeError('Unknown formatter '+kind)
    if not command:raise RuntimeError('Formatter unavailable for '+kind)
    result=subprocess.run(command,input=sys.stdin.buffer.read(),cwd=cwd,capture_output=True,timeout=60)
    if result.returncode:raise RuntimeError(result.stderr.decode(errors='replace'))
    sys.stdout.buffer.write(result.stdout)
    return 0
if __name__=='__main__':
    try:raise SystemExit(main())
    except (OSError,RuntimeError,subprocess.SubprocessError) as error:
        print(str(error),file=sys.stderr);raise SystemExit(1)
WORK_VDI_FILE_END
backup "$config_root/work-emacs/portability.el" portability.el
cat > "$config_root/work-emacs/portability.el" <<'WORK_VDI_FILE_END'
;;; emacs-portability.el --- Runtime portability, not personal settings -*- lexical-binding: t; -*-
;; Keep the source features while resolving tools outside Nix.
(require 'treesit)
(defvar work/grammar-sources
  '((bash "https://github.com/tree-sitter/tree-sitter-bash")
    (c "https://github.com/tree-sitter/tree-sitter-c")
    (cpp "https://github.com/tree-sitter/tree-sitter-cpp")
    (css "https://github.com/tree-sitter/tree-sitter-css")
    (dockerfile "https://github.com/camdencheek/tree-sitter-dockerfile")
    (go "https://github.com/tree-sitter/tree-sitter-go")
    (html "https://github.com/tree-sitter/tree-sitter-html")
    (javascript "https://github.com/tree-sitter/tree-sitter-javascript" "master" "src")
    (json "https://github.com/tree-sitter/tree-sitter-json")
    (lua "https://github.com/tree-sitter-grammars/tree-sitter-lua")
    (nix "https://github.com/nix-community/tree-sitter-nix")
    (python "https://github.com/tree-sitter/tree-sitter-python")
    (rust "https://github.com/tree-sitter/tree-sitter-rust")
    (toml "https://github.com/tree-sitter-grammars/tree-sitter-toml")
    (tsx "https://github.com/tree-sitter/tree-sitter-typescript" "master" "tsx/src")
    (typescript "https://github.com/tree-sitter/tree-sitter-typescript" "master" "typescript/src")
    (yaml "https://github.com/tree-sitter-grammars/tree-sitter-yaml")))
(dolist (source work/grammar-sources) (add-to-list 'treesit-language-source-alist source))
(defun work/install-grammars ()
  "Build the coding language grammars. Requires Git and a C/C++ toolchain."
  (interactive)
  (unless (treesit-available-p) (user-error "This Emacs needs tree-sitter support"))
  (let (failures)
    (dolist (source work/grammar-sources)
      (unless (treesit-language-available-p (car source))
        (condition-case err (treesit-install-language-grammar (car source))
          (error (push (cons (car source) (error-message-string err)) failures)))))
    (if failures
        (error "Some grammars failed (other languages were still attempted): %S" (nreverse failures))
      (message "Work grammars installed. Restart Emacs."))))

;; Keep classic modes available until grammars have been built. All syntax-aware
;; features activate with the same modes once their grammar is available.
(defun work/grammar-ready-p (language) (treesit-language-available-p language))
(let ((mode-languages '((js-ts-mode . javascript) (json-ts-mode . json)
                       (typescript-ts-mode . typescript) (tsx-ts-mode . tsx)
                       (css-ts-mode . css) (yaml-ts-mode . yaml)
                       (bash-ts-mode . bash) (python-ts-mode . python)
                       (go-ts-mode . go) (lua-ts-mode . lua) (toml-ts-mode . toml))))
  (setq major-mode-remap-alist
        (seq-filter (lambda (pair)
                      (let ((lang (alist-get (cdr pair) mode-languages)))
                        (or (not lang) (work/grammar-ready-p lang))))
                    major-mode-remap-alist))
  (unless (work/grammar-ready-p 'tsx)
    (setf (alist-get "\\.tsx\\'" auto-mode-alist nil nil #'equal) 'web-mode
          (alist-get "\\.jsx\\'" auto-mode-alist nil nil #'equal) 'web-mode))
  (unless (work/grammar-ready-p 'typescript)
    (setf (alist-get "\\.mts\\'" auto-mode-alist nil nil #'equal) 'typescript-mode
          (alist-get "\\.cts\\'" auto-mode-alist nil nil #'equal) 'typescript-mode)))
(dolist (entry '(("\\.go\\'" . go-mode) ("\\.lua\\'" . lua-mode)
                 ("\\.ya?ml\\'" . yaml-mode) ("\\.json\\'" . json-mode)))
  (when (fboundp (cdr entry)) (add-to-list 'auto-mode-alist entry)))
;; nix-ts-mode has no classic fallback in the source; use nix-mode until built.
(when (and (not (treesit-language-available-p 'nix)) (require 'nix-mode nil t))
  (setf (alist-get "\\.nix\\'" auto-mode-alist nil nil #'equal) 'nix-mode))
;; Keep LSP on classic modes too while grammars are absent.
(dolist (hook '(js-mode-hook typescript-mode-hook python-mode-hook go-mode-hook
                lua-mode-hook css-mode-hook yaml-mode-hook json-mode-hook nix-mode-hook))
  (add-hook hook #'lsp-deferred))
(when (and (< emacs-major-version 31) (require 'corfu-terminal nil t))
  (corfu-terminal-mode 1))
;; Linux uses libnotify; macOS uses the platform notifier when available.
(when (eq system-type 'darwin) (setq alert-default-style 'osx-notifier))
;; GUI login-shell import can replace PATH; restore the private work tools after it.
(let* ((root (expand-file-name "work-vdi/tools/"
                               (or (getenv "XDG_DATA_HOME") "~/.local/share/")))
       (paths (list (expand-file-name "bin" root)
                    (expand-file-name "python/bin" root)
                    (expand-file-name "~/.local/bin"))))
  (dolist (path (reverse paths))
    (when (file-directory-p path)
      (add-to-list 'exec-path path)
      (setenv "PATH" (concat path path-separator (getenv "PATH"))))))

;; Work stack: Java/Spring Boot, PHP/Laravel, Vue/Nuxt, Python/FastAPI and markup.
(dolist (source '((java "https://github.com/tree-sitter/tree-sitter-java")
                  (php "https://github.com/tree-sitter/tree-sitter-php" nil "php/src")
                  (php_only "https://github.com/tree-sitter/tree-sitter-php" nil "php_only/src")
                  (scss "https://github.com/serenadeai/tree-sitter-scss")
                  (xml "https://github.com/tree-sitter-grammars/tree-sitter-xml" nil "xml/src")
                  (dtd "https://github.com/tree-sitter-grammars/tree-sitter-xml" nil "dtd/src")
                  (vue "https://github.com/tree-sitter-grammars/tree-sitter-vue")
                  (blade "https://github.com/EmranMR/tree-sitter-blade")
                  (properties "https://github.com/tree-sitter-grammars/tree-sitter-properties")))
  (add-to-list 'work/grammar-sources source)
  (add-to-list 'treesit-language-source-alist source))
(when (and (fboundp 'java-ts-mode) (treesit-language-available-p 'java))
  (add-to-list 'major-mode-remap-alist '(java-mode . java-ts-mode)))
(add-to-list 'auto-mode-alist '("\\.php\\'" . php-mode))
(add-to-list 'auto-mode-alist '("\\.blade\\.php\\'" . web-mode))
(dolist (extension '("xml" "xsd" "xsl" "xslt" "svg" "wsdl" "fxml"))
  (add-to-list 'auto-mode-alist (cons (concat "\\." extension "\\'") 'nxml-mode)))
(defun work/blade-p ()
  "Whether this buffer is a Laravel Blade template."
  (and buffer-file-name (string-suffix-p ".blade.php" buffer-file-name)))
(defun work/web-stack ()
  "Select the right embedded language for a Blade template."
  (when (work/blade-p)
    (setq-local web-mode-engine "blade")
    (setq-local lsp-language-id-configuration
                (cons '(web-mode . "php") lsp-language-id-configuration))))
(add-hook 'web-mode-hook #'work/web-stack)
(with-eval-after-load 'lsp-mode
  (let ((tools (expand-file-name "work-vdi/tools/"
                                 (or (getenv "XDG_DATA_HOME") "~/.local/share/"))))
    (setq lsp-java-server-install-dir (expand-file-name "share/jdtls/" tools)
          lsp-java-jdt-ls-prefer-native-command t
          lsp-java-jdt-ls-command "jdtls"
          lsp-java-format-enabled t))
  (lsp-register-client
   (make-lsp-client :new-connection (lsp-stdio-connection '("intelephense" "--stdio"))
                    :activation-fn (lambda (file _mode)
                                     (and file (string-match-p "\\.php\\'" file)))
                    :server-id 'work-php :priority 10))
  (lsp-register-client
   (make-lsp-client :new-connection (lsp-stdio-connection '("lemminx"))
                    :major-modes '(nxml-mode xml-mode)
                    :server-id 'work-xml :priority 10))
  (lsp-register-client
   (make-lsp-client :new-connection (lsp-stdio-connection '("ruff" "server"))
                    :major-modes '(python-mode python-ts-mode)
                    :server-id 'work-ruff :priority 10 :add-on? t)))
(defun work/java-start ()
  "Start JDTLS with Maven/Gradle project support."
  (if (require 'lsp-java nil t) (lsp-deferred)
    (display-warning 'work-vdi "Java needs lsp-java: run M-x work/install-packages." :warning)))
(add-hook 'java-mode-hook #'work/java-start)
(add-hook 'java-ts-mode-hook #'work/java-start)
(add-hook 'php-mode-hook #'lsp-deferred)
(add-hook 'nxml-mode-hook #'lsp-deferred)
(defun work/formatter-available-p (kind)
  "Whether the shared KIND formatter can handle this buffer."
  (and buffer-file-name (executable-find "work-format")
       (eq 0 (call-process "work-format" nil nil nil "--available" kind buffer-file-name))))
(defvar-local work/lsp-format-on-save nil)
(defun work/lsp-format-save ()
  "Use the language server when it supplies this buffer's formatter."
  (when (and work/lsp-format-on-save (bound-and-true-p lsp-mode)
             (lsp-feature? "textDocument/formatting"))
    (lsp-format-buffer)))
(defun work/stack-formatter ()
  "Choose project-aware formatting, falling back to the attached language server."
  (let ((kind (cond ((work/blade-p) "blade")
                    ((derived-mode-p 'php-mode) "php")
                    ((derived-mode-p 'nxml-mode) "xml"))))
    (when (or kind (derived-mode-p 'java-mode 'java-ts-mode))
      (if (and kind (work/formatter-available-p kind))
          (progn (setq-local apheleia-formatter (intern (concat "work-" kind)))
                 (setq-local work/lsp-format-on-save nil)
                 (when (fboundp 'apheleia-mode) (apheleia-mode 1)))
        (setq-local work/lsp-format-on-save t)
        (when (fboundp 'apheleia-mode) (apheleia-mode -1)))
      (add-hook 'before-save-hook #'work/lsp-format-save nil t))))
(with-eval-after-load 'apheleia
  (dolist (kind '(php xml blade))
    (setf (alist-get (intern (concat "work-" (symbol-name kind))) apheleia-formatters)
          (list "work-format" (symbol-name kind) 'filepath))))
(add-hook 'after-change-major-mode-hook #'work/stack-formatter t)

;; Stable shared tsserver fallback; workspace language runtimes stay project-owned.
(when work/npm-root
  (let ((server (expand-file-name "typescript/lib/tsserver.js" work/npm-root)))
    (when (file-exists-p server)
      (setq lsp-clients-typescript-server-args (list "--stdio" "--tsserver-path" server)))))

;; Keep the manual format command and the save hook consistent with project tools.
(with-eval-after-load 'apheleia
  (dolist (mode '(yaml-mode yaml-ts-mode))
    (setf (alist-get mode apheleia-mode-alist)
          (if (executable-find "yamlfmt") 'yamlfmt 'prettierd))))
(defun work/stack-own-formatter-p ()
  (or work/lsp-format-on-save
      (memq (bound-and-true-p apheleia-formatter) '(work-php work-xml work-blade))))
(when (fboundp 'my/format-fallback-to-lsp)
  (advice-add 'my/format-fallback-to-lsp :before-while
              (lambda () (not (work/stack-own-formatter-p)))))
(defun work/manual-stack-format (original &rest args)
  (cond (work/lsp-format-on-save
         (if (bound-and-true-p lsp-mode) (lsp-format-buffer)
           (user-error "Language server is not attached; see M-x work/doctor")))
        ((memq (bound-and-true-p apheleia-formatter) '(work-php work-xml work-blade))
         (apheleia-format-buffer apheleia-formatter))
        (t (apply original args))))
(when (fboundp 'my/format-buffer)
  (advice-add 'my/format-buffer :around #'work/manual-stack-format))

WORK_VDI_FILE_END

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
  npm install --global --prefix "$tools_root" typescript@5.9.3 typescript-language-server @vue/language-server @vue/typescript-plugin @angular/language-server @tailwindcss/language-server @prisma/language-server @olrtg/emmet-language-server bash-language-server vscode-langservers-extracted yaml-language-server pyright intelephense prettier @fsouza/prettierd @prettier/plugin-xml blade-formatter tree-sitter-cli
  python3 -m venv "$tools_root/python"
  "$tools_root/python/bin/python" -m pip install black ruff yamllint
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
        '+lua require("nvim-treesitter").install(vim.env.WORK_VDI_ALL_GRAMMARS=="1" and require("nvim-treesitter").get_available() or {"bash", "blade", "c", "cpp", "css", "dockerfile", "dtd", "go", "graphql", "haskell", "html", "java", "javadoc", "javascript", "jsdoc", "json", "lua", "markdown", "markdown_inline", "nix", "php", "php_only", "phpdoc", "properties", "python", "regex", "rust", "scss", "sql", "toml", "tsx", "typescript", "vue", "xml", "yaml"}):wait(600000)' +qa
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
        -l "$config_root/work-emacs/portability.el" \
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
