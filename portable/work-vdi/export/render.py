#!/usr/bin/env python3
"""Render evaluated source settings into standalone editor configs."""
import json, os, pathlib, re
OUT=pathlib.Path(__file__).resolve().parents[1]
D=json.loads((OUT/'export/evaluated.json').read_text())
STACK=json.loads((OUT/'export/language-stack.json').read_text())
HELPERS={entry['name']:entry['text'] for entry in D['helpers']}
HELPER_PATHS={entry['name']:entry['path'] for entry in D['helpers']}
# Build-time export uses the locked nixpkgs source; no Nix process runs in the build.
if os.environ.get('WORK_VDI_NIXPKGS_SOURCE'):
    generated=pathlib.Path(os.environ['WORK_VDI_NIXPKGS_SOURCE'])/'pkgs/applications/editors/vim/plugins/generated.nix'
    sources={}
    for block in re.findall(r'  [\w-]+ = buildVimPlugin \{(.*?)\n  \};',generated.read_text(),re.S):
        owner=re.search(r'owner = "([^"\n]+)"',block)
        repo=re.search(r'repo = "([^"\n]+)"',block)
        rev=re.search(r'(rev|tag) = "([^"\n]+)"',block)
        if owner and repo and rev:sources[owner[1]+'/'+repo[1]]={rev[1]:rev[2]}
    D['plugin_sources']=sources

def forms(text):
    """Read balanced top-level Lisp forms (preserving their original contents)."""
    result=[]; start=None; depth=0; string=False; comment=False; escape=False
    for i,c in enumerate(text):
        if comment:
            if c=='\n': comment=False
            continue
        if string:
            if escape: escape=False
            elif c=='\\': escape=True
            elif c=='"': string=False
            continue
        if c==';':comment=True;continue
        if c=='"':string=True;continue
        if c in '([':
            if depth==0:start=i
            depth+=1
        elif c in ')]':
            depth-=1
            if depth==0 and start is not None:
                result.append(text[start:i+1]); start=None
    assert depth==0, ('unbalanced exported Lisp',depth)
    return result

def strip_comments(text):
    return '\n'.join(line for line in text.splitlines() if not line.lstrip().startswith(';'))

def clean_el(name,text):
    text='\n\n'.join(forms(text))
    # Store paths are replaced with commands available on the VDI's PATH.
    replacements={'delta':'delta','postgresql':'psql','pgformatter':'pg_format'}
    text=re.sub(r'/WORK_PACKAGES/([^/" ]+)/bin/([^" ]+)',lambda m:replacements.get(m[1],m[2]),text)
    text=text.replace('/WORK_PACKAGES/vue-language-server/lib/language-tools/packages/language-server','WORK_VUE_PACKAGE')
    text=text.replace('/WORK_PACKAGES/typescript/lib/node_modules','WORK_NPM_ROOT')
    text=text.replace('/WORK_PACKAGES/angular-language-server/lib/node_modules','WORK_NPM_ROOT')
    for helper in HELPERS:
        text=text.replace(f'"{HELPER_PATHS[helper]}/bin/{helper}"',f'(expand-file-name "helpers/{helper}" user-emacs-directory)')
    if name=='plugins/apps/browser.nix':
        text='\n\n'.join(f for f in forms(text) if not f.startswith('(setq browser-gt-client-app-names'))
        text=text.replace("(require 'xwidget)","(require 'xwidget nil t)")
        text=text.replace('(xwidget-webkit-browse-url url t)',"(if (featurep 'xwidget-internal) (xwidget-webkit-browse-url url t) (eww url))")
    if name=='plugins/vim/default.nix':
        text=text.replace('(exec-path-from-shell-initialize)', "(when (memq window-system '(mac ns x pgtk)) (exec-path-from-shell-initialize) (work/setup-tool-path))")
        text=text.replace(' "NIX_PATH"','')
    if name=='plugins/files/browsing.nix':
        text=text.replace("'((\"~/Development\" . 3))",'nil')
    if name=='plugins/keybinds/default.nix':
        # Remove only key entries for omitted personal modules and personal config management.
        blocked={'k','m','N','i','$','R'}
        lines=[]
        for line in text.splitlines():
            m=re.match(r'\s*"([^" ]+)"\s+',line)
            if m and (m[1][0] in blocked or m[1] in {'ot','om'} or 'my/obsidian' in line):continue
            if m and m[1]=='n':line=line.replace('notes','markdown')
            # Replace the personal browser/capture helper with Emacs' ordinary browser.
            line=line
            lines.append(line)
        text='\n'.join(lines)
    if name=='plugins/ui/dashboard.nix':
        # Keep the dashboard and its entry navigation; drop vault/Nix-host sections.
        kept=[]
        for form in forms(text):
            if re.match(r'\((?:defun|defvar|defconst) my/dashboard-(?:config|todo|-todo|-tasks|-task-meta)',form): continue
            if form.startswith('(add-to-list') and re.search(r"my/dashboard-(config|todo)\b",form):continue
            if form.startswith('(defun dashboard-jump-to-config') or form.startswith('(defun dashboard-jump-to-todo'):continue
            form=form.replace("'((config   . 1)\n                        (todo     . 8)\n                        (recents  . 12)","'((recents . 12)")
            # Match formatting independent of Nix indentation.
            form=re.sub(r'\(config\s+\.\s+1\)\s*\(todo\s+\.\s+8\)\s*','',form)
            form=re.sub(r'\(config\s+"c"\s+"nix-config:"\)\s*','',form)
            form=re.sub(r'\(todo\s+"t"\s+"Todo:"\)\s*','',form)
            kept.append(form)
        text='\n\n'.join(kept)
    if name=='plugins/ui/statusline.nix':
        # Keep coding modeline, Claude status, and async infrastructure.
        kept=[]
        personal={'my/status-mail-count','my/status-music','my/status-update-mail','my/status-update-music','my/status-telega','my/status-matrix','my/status-matrix-count'}
        for form in forms(text):
            m=re.match(r'\((?:defun|defvar|defconst) ([^\s()]+)',form)
            if m and m[1] in personal:continue
            if re.match(r"\(with-eval-after-load '(mu4e|telega|ement)\b",form):continue
            if form.startswith('(defun my/status-string '):
                form='(defun my/status-string () "Work coding status." (my/status-claude))'
            if form.startswith('(unless my/status--timers'):
                form="(unless my/status--timers (setq my/status--timers (list (run-with-timer 12 120 #'my/status-update-claude))))"
            kept.append(form)
        text='\n\n'.join(kept)
    # Portable npm package locations are discovered once, without writing to the system.
    text=text.replace('"WORK_NPM_ROOT"','work/npm-root').replace('"WORK_VUE_PACKAGE"','work/vue-package')
    # An Angular command containing computed locations must be a backquoted list.
    text=text.replace("'(\"ngserver\"",'`("ngserver"').replace('"--tsProbeLocations" work/npm-root','"--tsProbeLocations" ,work/npm-root').replace('"--ngProbeLocations" work/npm-root','"--ngProbeLocations" ,work/npm-root')
    return strip_comments(text)

packages=sorted(({p for m in D['emacs'] for p in m['packages']} - {'treesit-grammars','claude-code-ide'}) | {'websocket','web-server','persist','with-editor','transient','tramp-container','corfu-terminal','json-mode','yaml-mode','lua-mode','go-mode','nix-mode','php-mode','lsp-java'})
header=''';;; init.el --- Full work editor export -*- lexical-binding: t; -*-
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
(defvar work/packages 'PACKAGES)
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
  "Load source module NAME if its PACKAGES are installed; report failures."
  (if (or (getenv "WORK_VDI_BOOTSTRAP") (seq-some (lambda (p) (not (package-installed-p p))) packages))
      (push (cons name "Packages missing; run M-x work/install-packages") work/module-errors)
    (condition-case err
        (with-temp-buffer
          (insert ";;; -*- lexical-binding: t; -*-\\n" text)
          (eval-buffer))
      (error (push (cons name (error-message-string err)) work/module-errors)))))
(defun work/doctor ()
  "Show work module startup failures and missing packages."
  (interactive)
  (with-output-to-temp-buffer "*Work setup*"
    (princ (format "Emacs %s\\n" emacs-version))
    (dolist (tool '("java" "jdtls" "php" "composer" "intelephense" "lemminx" "pyright-langserver" "ruff" "black" "prettier" "blade-formatter" "work-format"))
      (princ (format "%s: %s\\n" tool (or (executable-find tool) "MISSING"))))
    (dolist (entry (reverse work/module-errors))
      (princ (format "%s: %s\\n" (car entry) (cdr entry))))))
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
'''.replace('PACKAGES','('+' '.join(packages)+')')
fragments=[]
for m in D['emacs']:
    name=m['path'].split('/emacs/')[-1]
    for fragment in m['fragments']:
        text=clean_el(name,fragment['text'])
        dest=OUT/'export/modules'/name.replace('.nix',f'-{fragment["order"]}.el')
        dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(text+'\n')
        deps=[p for p in m['packages'] if p not in {'treesit-grammars','claude-code-ide'}]
        # The bootstrap package installer must also supply these upstream fork dependencies.
        fragments.append((fragment['order'],name,deps,text))
body=[]
for order,name,deps,text in sorted(fragments,key=lambda x:x[0]):
    item=f'(work/load-module {json.dumps(name)} \'({" ".join(deps)})\n  {json.dumps(text,ensure_ascii=False)})\n'
    if name=='keybinds.nix' and (order==90 or 'my/colemak-rotate-states' in text):item='(when work/colemak\n'+item+')\n'
    body.append(item)
portability=(OUT/'export/emacs-portability.el').read_text()
body.append('(work/load-module \"portability\" \'(lsp-mode) '+json.dumps(portability)+')\n')
(OUT/'init.el').write_text(header+'\n'.join(body)+'''\n(when (and work/module-errors (not (getenv "WORK_VDI_BOOTSTRAP")))
  (display-warning 'work-vdi "Some work modules need setup. Run M-x work/doctor for details." :warning))
''')
(OUT/'helpers').mkdir(exist_ok=True)
for name,text in HELPERS.items():
    (OUT/'helpers'/name).write_text('#!/usr/bin/env python3\n'+text)
    (OUT/'helpers'/name).chmod(0o755)
for filename,target in [('work-format.py','work-format'),('install-native-tools.py','install-native-tools.py'),('install-editors.py','install-editors.py')]:
    (OUT/'helpers'/target).write_text((OUT/'export'/filename).read_text())
    (OUT/'helpers'/target).chmod(0o755)
print('Rendered full Emacs export')

# Lua serializer also handles Nixvim's raw expressions and positional table keys.
def lua(x):
    if x is None:return 'nil'
    if isinstance(x,bool):return str(x).lower()
    if isinstance(x,(int,float)):return str(x)
    if isinstance(x,str):return json.dumps(x,ensure_ascii=False)
    if isinstance(x,list):return '{'+','.join(lua(v) for v in x)+'}'
    if '__raw' in x:return x['__raw']
    positional=sorted((int(k.split('-')[-1]),v) for k,v in x.items() if k.startswith('__unkeyed-'))
    return '{'+','.join([lua(v) for _,v in positional]+['['+lua(k)+']='+lua(v) for k,v in x.items() if not k.startswith('__unkeyed-')])+'}'
N=D['nvim'];P=N['plugins']
P['lsp']['servers'].update({'jdtls':{'enable':True},'intelephense':{'enable':True},'lemminx':{'enable':True},'ruff':{'enable':True}})
# Name -> upstream repository, Lua module (None = Vimscript or custom setup).
registry={
'aerial':('stevearc/aerial.nvim','aerial'), 'auto-session':('rmagatti/auto-session','auto-session'),
'cmp':('hrsh7th/nvim-cmp',None), 'cmp-emoji':('hrsh7th/cmp-emoji',None),
'cmp-git':('petertriho/cmp-git','cmp_git'), 'cmp-spell':('f3fora/cmp-spell',None),
'colorizer':('NvChad/nvim-colorizer.lua','colorizer'), 'comment':('numToStr/Comment.nvim','Comment'),
'conform-nvim':('stevearc/conform.nvim','conform'), 'dap':('mfussenegger/nvim-dap',None),
'dap-ui':('rcarriga/nvim-dap-ui','dapui'), 'dap-virtual-text':('theHamsta/nvim-dap-virtual-text','nvim-dap-virtual-text'),
'dashboard':('nvimdev/dashboard-nvim','dashboard'), 'emmet':('mattn/emmet-vim',None),
'firenvim':('glacambre/firenvim',None), 'fugitive':('tpope/vim-fugitive',None),
'gitsigns':('lewis6991/gitsigns.nvim','gitsigns'), 'grug-far':('MagicDuck/grug-far.nvim','grug-far'),
'hardtime':('m4xshen/hardtime.nvim','hardtime'), 'hop':('smoka7/hop.nvim','hop'),
'illuminate':('RRethy/vim-illuminate',None), 'indent-blankline':('lukas-reineke/indent-blankline.nvim','ibl'),
'intellitab':('pta2002/intellitab.nvim','intellitab'), 'lsp':('neovim/nvim-lspconfig',None),
'lsp-format':('lukas-reineke/lsp-format.nvim','lsp-format'), 'lspkind':('onsails/lspkind.nvim',None),
'lspsaga':('nvimdev/lspsaga.nvim','lspsaga'), 'lualine':('nvim-lualine/lualine.nvim',None),
'markview':('OXY2DEV/markview.nvim','markview'), 'multicursors':('smoka7/multicursors.nvim','multicursors'),
'navbuddy':('SmiteshP/nvim-navbuddy','nvim-navbuddy'), 'neotest':('nvim-neotest/neotest',None),
'none-ls':('nvimtools/none-ls.nvim',None), 'notify':('rcarriga/nvim-notify','notify'),
'numbertoggle':('jeffkreeftmeijer/vim-numbertoggle',None), 'nvim-autopairs':('windwp/nvim-autopairs','nvim-autopairs'),
'nvim-tree':('nvim-tree/nvim-tree.lua','nvim-tree'), 'nvim-ufo':('kevinhwang91/nvim-ufo','ufo'),
'precognition':('tris203/precognition.nvim','precognition'), 'project-nvim':('DrKJeff16/project.nvim','project'),
'rainbow-delimiters':('HiPhish/rainbow-delimiters.nvim',None), 'refactoring':('ThePrimeagen/refactoring.nvim','refactoring'),
'repeat':('tpope/vim-repeat',None), 'schemastore':('b0o/SchemaStore.nvim',None),
'scrollview':('dstein64/nvim-scrollview','scrollview'), 'telescope':('nvim-telescope/telescope.nvim',None),
'todo-comments':('folke/todo-comments.nvim','todo-comments'), 'toggleterm':('akinsho/toggleterm.nvim','toggleterm'),
'treesitter':('nvim-treesitter/nvim-treesitter',None), 'treesitter-textobjects':('nvim-treesitter/nvim-treesitter-textobjects',None),
'trouble':('folke/trouble.nvim','trouble'), 'ts-autotag':('windwp/nvim-ts-autotag','nvim-ts-autotag'),
'twilight':('folke/twilight.nvim','twilight'), 'vim-surround':('tpope/vim-surround',None),
'virt-column':('lukas-reineke/virt-column.nvim','virt-column'), 'web-devicons':('nvim-tree/nvim-web-devicons','nvim-web-devicons'),
'which-key':('folke/which-key.nvim','which-key'),
}
assert set(P)==set(registry),set(P)^set(registry)
# Explicit dependencies replace Nixvim's automatic dependency wiring.
deps={
'cmp':['hrsh7th/cmp-nvim-lsp','hrsh7th/cmp-buffer','hrsh7th/cmp-path','hrsh7th/cmp-cmdline',
'hrsh7th/cmp-nvim-lsp-signature-help','hrsh7th/cmp-nvim-lsp-document-symbol','ray-x/cmp-treesitter',
'saadparwaiz1/cmp_luasnip','L3MON4D3/LuaSnip','rafamadriz/friendly-snippets','lukas-reineke/cmp-rg',
'tamago324/cmp-zsh','hrsh7th/cmp-calc'],
'aerial':['nvim-tree/nvim-web-devicons'],
'dap-ui':['mfussenegger/nvim-dap','nvim-neotest/nvim-nio'],
'dap-virtual-text':['mfussenegger/nvim-dap'],
'gitsigns':['nvim-lua/plenary.nvim'], 'hardtime':['MunifTanjim/nui.nvim'],
'lsp':['hrsh7th/cmp-nvim-lsp','b0o/SchemaStore.nvim'],
'lspsaga':['nvim-tree/nvim-web-devicons'],
'multicursors':['nvimtools/hydra.nvim'],
'navbuddy':['SmiteshP/nvim-navic','MunifTanjim/nui.nvim'],
'neotest':['nvim-lua/plenary.nvim','nvim-neotest/nvim-nio','antoinemadec/FixCursorHold.nvim',
'nvim-treesitter/nvim-treesitter','nvim-neotest/neotest-jest','marilari88/neotest-vitest','thenbe/neotest-playwright'],
'none-ls':['nvim-lua/plenary.nvim','nvimtools/none-ls-extras.nvim'],
'nvim-ufo':['kevinhwang91/promise-async'],
'refactoring':['nvim-lua/plenary.nvim','nvim-treesitter/nvim-treesitter'],
'treesitter-textobjects':['nvim-treesitter/nvim-treesitter'],
'scrollview':[], 'telescope':['nvim-lua/plenary.nvim','nvim-telescope/telescope-file-browser.nvim',
'nvim-telescope/telescope-frecency.nvim','kkharji/sqlite.lua','nvim-telescope/telescope-project.nvim'],
'lualine':['nvim-tree/nvim-web-devicons'], 'todo-comments':['nvim-lua/plenary.nvim'],
'dashboard':['nvim-tree/nvim-web-devicons'], 'fugitive':['tpope/vim-rhubarb','junegunn/gv.vim','idanarye/vim-merginal'],
}
theme_settings=N['colorschemes']['tokyonight']['settings']
if 'on_highlights' in theme_settings.get('styles',{}):theme_settings['on_highlights']={'__raw':theme_settings['styles'].pop('on_highlights')}
custom={
'cmp': '''local cmp = require('cmp')
local ls = require('luasnip')
require('luasnip.loaders.from_vscode').lazy_load()
local opts = CMP_SETTINGS
opts['friendly-snippets'], opts.luasnip = nil, nil
opts.formatting = {format=require('lspkind').cmp_format({maxwidth=50,ellipsis_char='...'})}
cmp.setup(opts)
cmp.setup.cmdline({'/','?'}, {mapping=cmp.mapping.preset.cmdline(), sources={{name='buffer'}}})
cmp.setup.cmdline(':', {mapping=cmp.mapping.preset.cmdline(), sources=cmp.config.sources({{name='path'}},{{name='cmdline'}})})''',
'lsp': '''local capabilities = require('cmp_nvim_lsp').default_capabilities()
local servers = SERVER_SETTINGS
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
  for key, data in pairs(LSP_KEYS) do
    vim.keymap.set('n',key,vim.lsp.buf[data.action],{buffer=args.buf,desc=data.desc})
  end
  vim.keymap.set({'n','i'},'<C-k>',vim.lsp.buf.signature_help,{buffer=args.buf})
  local client=vim.lsp.get_client_by_id(args.data.client_id)
  if client and client.server_capabilities.inlayHintProvider then
    vim.lsp.inlay_hint.enable(true,{bufnr=args.buf})
  end
end})''',
'neotest': '''require('neotest').setup({adapters={require('neotest-jest')({}),require('neotest-vitest')({}),require('neotest-playwright').adapter({})}})''',
'none-ls': '''local null_ls=require('null-ls')
local sources={}
for _, kind in ipairs({'diagnostics','code_actions','formatting'}) do
  for name, opts in pairs((NULL_SOURCES)[kind] or {}) do
    if opts.enable and null_ls.builtins[kind] and null_ls.builtins[kind][name] then
      table.insert(sources,null_ls.builtins[kind][name])
    elseif opts.enable then
      local ok, source=pcall(require,'none-ls.'..kind..'.'..name)
      if ok then table.insert(sources,source) end
    end
  end
end
null_ls.setup({sources=sources,update_in_insert=false})''',
'conform-nvim': '''local formatters={}
for _,kind in ipairs({'php','xml','blade'}) do
  local format_kind=kind
  formatters['work_'..kind]={command='work-format',args={kind,'$FILENAME'},stdin=true,
    condition=function(_,ctx)
      if vim.fn.executable('work-format')~=1 then return false end
      vim.fn.system({'work-format','--available',format_kind,ctx.filename})
      return vim.v.shell_error==0
    end}
end
require('conform').setup({formatters_by_ft=FORMATTERS,formatters=formatters,
format_on_save={timeout_ms=3000,lsp_format='fallback'},notify_on_error=true})''',
'lualine': P['lualine']['luaConfig']['pre'],
'telescope': '''-- Keep the environment picker local: no extra repository or authentication.
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
end''',
'illuminate': '''require('illuminate').configure({})''',
'dap': '''local dap=require('dap')
if vim.fn.executable('node')==1 and vim.env.WORK_JS_DEBUG_SERVER then
  dap.adapters['pwa-node']={type='server',host='127.0.0.1',port='${port}',executable={command='node',args={vim.env.WORK_JS_DEBUG_SERVER,'${port}'}}}
  for _,ft in ipairs({'javascript','typescript','javascriptreact','typescriptreact'}) do
    dap.configurations[ft]={{type='pwa-node',request='launch',name='Launch file',program='${file}',cwd='${workspaceFolder}',sourceMaps=true}}
  end
end
local ui=require('dapui')
dap.listeners.after.event_initialized['work_ui']=function() ui.open() end
dap.listeners.before.event_terminated['work_ui']=function() ui.close() end
dap.listeners.before.event_exited['work_ui']=function() ui.close() end''',
}
custom['cmp']=custom['cmp'].replace('CMP_SETTINGS',lua(P['cmp']['settings']).replace('"cmp.', '"cmp.'))
# Nixvim serializes several cmp expressions as strings; turn those back into Lua.
cmp_settings=lua(P['cmp']['settings'])
for value in list(P['cmp']['settings']['mapping'].values())+[P['cmp']['settings']['preselect'],P['cmp']['settings']['snippet']['expand']]:
    cmp_settings=cmp_settings.replace(lua(value),value)
custom['cmp']=custom['cmp'][:custom['cmp'].index('local opts = ')]+custom['cmp'][custom['cmp'].index('local opts = '):].replace(lua(P['cmp']['settings']),cmp_settings,1)
custom['lsp']=custom['lsp'].replace('SERVER_SETTINGS',lua(P['lsp']['servers'])).replace('LSP_KEYS',lua(P['lsp']['keymaps']['lspBuf']))
custom['none-ls']=custom['none-ls'].replace('NULL_SOURCES',lua(P['none-ls']['sources']))
formatters={}
for ft,config in P['conform-nvim']['settings']['formattersByFt'].items():
    if ft=='yaml':config={'__unkeyed-1':'yamlfmt','__unkeyed-2':'prettierd','__unkeyed-3':'prettier','stop_after_first':True} # yamllint is a linter, not a formatter.
    formatters[ft]=config
formatters.update({'scss':{'__unkeyed-1':'prettierd','__unkeyed-2':'prettier','stop_after_first':True},
  'json':{'__unkeyed-1':'prettierd','__unkeyed-2':'prettier','stop_after_first':True},
  'jsonc':{'__unkeyed-1':'prettierd','__unkeyed-2':'prettier','stop_after_first':True},
  'php':['work_php'],'blade':['work_blade'],'xml':['work_xml']})
custom['conform-nvim']=custom['conform-nvim'].replace('FORMATTERS',lua(formatters))
# Full tree-sitter highlighting, indentation, textobjects and movement, on compatible master APIs.
custom['treesitter']="require('nvim-treesitter.configs').setup("+lua({**P['treesitter']['settings'],'ensure_installed':[], 'auto_install':False,'textobjects':P['treesitter-textobjects']['settings']})+")"
extras=["'nvim-lua/plenary.nvim'", "{'folke/tokyonight.nvim',priority=1000,config=function() require('tokyonight').setup("+lua(theme_settings)+"); vim.cmd.colorscheme('tokyonight') end}"]
modern_treesitter="""require('nvim-treesitter').setup({})
vim.api.nvim_create_autocmd('FileType',{callback=function(args)
  local ok=pcall(vim.treesitter.start,args.buf)
  if ok then
    vim.bo[args.buf].indentexpr="v:lua.require'nvim-treesitter'.indentexpr()"
    vim.wo.foldmethod='expr'
    vim.wo.foldexpr='v:lua.vim.treesitter.foldexpr()'
  end
end})"""
modern_textobjects="require('nvim-treesitter-textobjects').setup({select={lookahead=true}})\n"
for key,query in P['treesitter-textobjects']['settings']['select']['keymaps'].items():
    modern_textobjects+='vim.keymap.set({\"x\",\"o\"},'+lua(key)+',function() require(\"nvim-treesitter-textobjects.select\").select_textobject('+lua(query)+',\"textobjects\") end)\n'
for movement,bindings in P['treesitter-textobjects']['settings']['move'].items():
    if movement=='enable':continue
    for key,query in bindings.items():
        modern_textobjects+='vim.keymap.set({\"n\",\"x\",\"o\"},'+lua(key)+',function() require(\"nvim-treesitter-textobjects.move\").'+movement+'('+lua(query)+',\"textobjects\") end)\n'
specs=[]
for name,(repo,module) in registry.items():
    settings=P[name].get('settings',{})
    settings={k:v for k,v in settings.items() if k not in {'cmp'}} if name=='lspkind' else settings
    if name=='lspsaga':
        settings['hover'].pop('open_cmd',None) # Use the VDI's browser rather than personal floorp.
    if name=='which-key':
        settings['spec']=[s for s in settings['spec'] if s.get('__unkeyed-1')!='<leader>n']
    config=custom.get(name)
    if not config and module:config=f'require({lua(module)}).setup({lua(settings)})'
    fields=[lua(repo),'lazy=false']
    if name=='project-nvim':fields.append("enabled=vim.env.WORK_VDI_BOOTSTRAP~='1'")
    if name in deps:fields.append('dependencies='+lua(deps[name]))
    if repo in D.get('plugin_sources',{}):
        pin=D['plugin_sources'][repo]
        fields.append(('commit=' if 'rev' in pin else 'tag=')+lua(pin.get('rev',pin.get('tag'))))
    if name in {'treesitter','treesitter-textobjects'}:fields.append("branch='main'")
    if name=='telescope':fields.append("tag='v0.2.1'")
    if name=='treesitter':fields.append("build=function() if (vim.fn.executable('cc')==1 or vim.fn.executable('gcc')==1 or vim.fn.executable('clang')==1) and vim.fn.executable('tree-sitter')==1 then vim.cmd('TSUpdate') else vim.notify('Grammar builds skipped: install a C compiler and tree-sitter CLI, then rerun the installer.',vim.log.levels.WARN) end end")
    if name=='cmp':fields.append("dependencies="+lua(deps[name]+['onsails/lspkind.nvim']))
    if name=='nvim-ufo':config=P['nvim-ufo']['luaConfig']['pre']+'\n'+config
    if name=='treesitter':config=modern_treesitter
    if name=='treesitter-textobjects':config=modern_textobjects
    if name=='intellitab':config=None # exposes indent(), no setup() API
    if name=='neotest':fields.append("dependencies="+lua(deps[name]+['mfussenegger/nvim-dap']))
    if name=='lualine':config=custom['lualine']
    if config:fields.append('config=function()\n'+config+'\nend')
    specs.append('{'+','.join(fields)+'}')
# Freeze dependency revisions from the same source set where available.
for repo in sorted({r for values in deps.values() for r in values} - {v[0] for v in registry.values()}):
    if repo in D.get('plugin_sources',{}):
        pin=D['plugin_sources'][repo]
        specs.append('{'+lua(repo)+','+('commit=' if 'rev' in pin else 'tag=')+lua(pin.get('rev',pin.get('tag')))+'}')
# Extra completion sources enabled by autoEnableSources in Nixvim.
completion_extra=['hrsh7th/cmp-nvim-lsp','hrsh7th/cmp-buffer','hrsh7th/cmp-path','hrsh7th/cmp-cmdline','hrsh7th/cmp-nvim-lsp-signature-help','hrsh7th/cmp-nvim-lsp-document-symbol','ray-x/cmp-treesitter','saadparwaiz1/cmp_luasnip','lukas-reineke/cmp-rg','tamago324/cmp-zsh','hrsh7th/cmp-calc']
# Setup module import order is resolved through lazy.nvim dependencies.
head='''-- Full work export of the Nixvim coding modules. No Nix required on the VDI.
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
'''
# Correct __raw options, whitespace hooks and storage directories are exported directly.
head+="vim.filetype.add({pattern={['.*%.blade%.php']='blade'},extension={vue='vue',xml='xml',xsd='xml',xsl='xml',xslt='xml',wsdl='xml',fxml='xml'}})\n"
head+='for k,v in pairs('+lua(N['opts'])+') do vim.opt[k]=v end\n'
# Keep the source save-time whitespace cleanup, but centralize formatting in Conform.
option_lua=N['extraConfigLua']
option_lua=re.sub(r'    -- Format on save.*?    -- Undo, backup and swap','    -- Undo, backup and swap',option_lua,flags=re.S) if False else option_lua
option_lua=re.sub(r'-- Format on save\napi.nvim_create_autocmd\("BufWritePre", \{.*?\n\}\)\n','',option_lua,flags=re.S)
option_lua=option_lua.replace('if fn.has("nvim") then','if fn.has("nvim") == 1 then').replace('if fn.has("termguicolors") then','if fn.has("termguicolors") == 1 then').replace('if vim.fn.has("macunix") then','if vim.fn.has("macunix") == 1 then').replace('if vim.fn.has("win32") then','if vim.fn.has("win32") == 1 then')
option_lua=option_lua.replace('local prefix = env.XDG_CONFIG_HOME or fn.expand("~/.config")','local prefix = vim.fn.stdpath("state")')
# Create the source's state directories before writes; their names are retained.
head+='for _,dir in ipairs({".undo",".backup",".swp"}) do vim.fn.mkdir(vim.fn.stdpath("state").."/nvim/"..dir,"p",448) end\n'
head+=option_lua+'\n'
for autocmd in N.get('autoCmd',[]):
    head+='vim.api.nvim_create_autocmd('+lua(autocmd['event'])+','+lua({k:v for k,v in autocmd.items() if k!='event'})+')\n'
head+='''local lazypath=vim.fn.stdpath('data')..'/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  if colemak then for from,to in pairs({n='j',N='J',e='k',E='K',i='l',I='L',j='n',J='N',k='e',K='E',l='i',L='I'}) do vim.keymap.set('n',from,to) end end
  vim.keymap.set('n','<leader>fs','<cmd>write<cr>')
  vim.notify('Run the work installer to install coding plugins; core settings are active.',vim.log.levels.WARN)
  return
end
vim.opt.rtp:prepend(lazypath)
require('lazy').setup({\n'''
text=head+',\n'.join(extras+specs)+'''\n},{checker={enabled=false},change_detection={notify=false}})
'''
for i,keymap in enumerate(N['keymaps']):
    key=keymap['key'];action=keymap['action'];mode=keymap.get('mode','n')
    if key.startswith('<leader>n'):continue
    if key=='<Tab>' and isinstance(action,dict):
        action={'__raw':"function() require('intellitab').indent() end"}
    if isinstance(action,str):
        action=action.replace('Git giff','Git diff').replace('expand("%]")','expand("%:p")')
        if key=='<leader>rp':action="<cmd>lua require('grug-far').open()<CR>"
        if key=='<leader>dr':action='<cmd>Trouble lsp_references toggle<CR>'
        if key=='<leader>dt':action='<cmd>Trouble diagnostics toggle<CR>'
        if key=='<leader>go':action='<cmd>GBrowse<CR>'
    line='vim.keymap.set('+lua(mode)+','+lua(key)+','+lua(action)+','+lua({'silent':True,**keymap.get('options',{})})+')\n'
    if i<16:line='if colemak then '+line.rstrip()+' end\n'
    text+=line
text+='''
-- Debugging commands complement the source's DAP plugins.
vim.keymap.set('n','<leader>td',function() require('dap').continue() end,{desc='Debug / continue'})
vim.keymap.set('n','<leader>tb',function() require('dap').toggle_breakpoint() end,{desc='Breakpoint'})
vim.keymap.set('n','<leader>tu',function() require('dapui').toggle() end,{desc='Debug UI'})
vim.keymap.set('n','<leader>xf',function() require('conform').format({lsp_format='fallback'}) end,{desc='Format'})
if not colemak then
  for key,dir in pairs({h='h',j='j',k='k',l='l'}) do vim.keymap.set('n','<leader>w'..key,'<C-w>'..dir) end
end
'''
text=re.sub(r'/WORK_PACKAGES/([^/\" ]+)',lambda m:m[1],text)
(OUT/'init.lua').write_text(text)
print('Rendered full Neovim export: '+str(len(P))+' plugins, '+str(len(N['keymaps'])-4)+' source keymaps')
