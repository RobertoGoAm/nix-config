{
  extraConfigLua = ''
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

    -- Format on save
    api.nvim_create_autocmd("BufWritePre", {
      callback = function()
        vim.lsp.buf.format()
      end,
    })

    -- Undo, backup and swap
    local prefix = env.XDG_CONFIG_HOME or fn.expand("~/.config")
    o.undofile = true
    o.undodir = { prefix .. "/nvim/.undo//" }
    o.backupdir = { prefix .. "/nvim/.backup//" }
    o.directory = { prefix .. "/nvim/.swp//" }

    -- True colors
    if fn.has("nvim") then
      cmd([[let $NVIM_TUI_ENABLE_TRUE_COLOR=1]])
    end

    if fn.has("termguicolors") then
      o.termguicolors = true
    end

    cmd([[let &t_ZH='\e[3m']])
    cmd([[let &t_ZR='\e[23m']])


    -- Clipboard configuration
    if vim.fn.has("macunix") then
      o.clipboard:append { 'unnamedplus' }
    end

    if vim.fn.has("win32") then
      o.clipboard:prepend { 'unnamed', 'unnamedplus' }
    end
  '';

  opts = {
    # Set encoding to UTF-8
    encoding = "utf-8";
    fileencoding = "utf-8";

    # Don't close unsaved files on switch, hide instead
    hidden = true;

    # Relative line numbers
    number = true;
    relativenumber = true;

    # Show commands while awaiting input
    showcmd = true;

    # Always show sign column
    signcolumn = "yes";

    # Highlight cursor line
    cursorline = true;

    # Taller command section
    cmdheight = 1;

    # Time before writting to swap file
    updatetime = 300;

    # Ask before closing buffers
    confirm = true;

    # Disable wrap
    wrap = false;

    # Limit popup suggestion
    pumheight = 10;

    # Folding based on indentation
    foldmethod = "indent";
    foldenable = false;

    # Search as characters are entered
    incsearch = true;

    # Highlight search matches
    hlsearch = true;

    # Autocomplete for command menu
    wildmenu = true;

    # Ignore case unless uppercase character is introduced
    ignorecase = true;
    smartcase = true;

    # New splits should appear down in the vertical axis
    splitbelow = true;

    # New splits should appear right in the horizontal axis
    splitright = true;

    # Typical backspace behavior
    backspace = "indent,eol,start";

    # Convert tabs to spaces
    expandtab = true;

    # Change tab to 2 spaces
    tabstop = 2;
    softtabstop = 2;

    # Automatic indent to 2 spaces
    shiftwidth = 2;

    # Colors
    background = "dark";

    # Leader timeout
    timeoutlen = 500;
  };
}
