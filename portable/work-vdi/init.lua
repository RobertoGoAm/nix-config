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
