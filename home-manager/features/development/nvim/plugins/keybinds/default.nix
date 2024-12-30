{
  plugins = {
    toggleterm = {
      enable = true;
    };

    which-key = {
      enable = true;

      settings = {
        icons = {
          breadcrumb = "»";
          separator = "➜";
          group = "+";

          mappings = false;
        };

        layout = {
          width = {
            min = 20;
            max = 50;
          };

          spacing = 3;
        };

        plugins = {
          marks = true;

          presets = {
            operatos = true;
            motions = true;
            text_objects = true;
            windows = true;
            nav = true;
            z = true;
            g = true;
          };

          registers = true;
        };

        replace = {
          desc = [
            [
              "<space>"
              "SPC"
            ]
            [
              "<[cC][rR]>"
              "RETURN"
            ]
            [
              "<[tT][aA][bB]>"
              "TAB"
            ]
          ];
        };

        show_help = true;
        show_keys = true;

        spec = [
          {
            __unkeyed-1 = "<leader>b";
            group = "buffers";
            icon = "";
          }
          {
            __unkeyed-1 = "<leader>d";
            group = "diagnostics";
            icon = "";
          }
          {
            __unkeyed-1 = "<leader>e";
            group = "errors";
            icon = "";
          }
          {
            __unkeyed-1 = "<leader>f";
            group = "files";
            icon = "";
          }
          {
            __unkeyed-1 = "<leader>g";
            group = "git";
            icon = "";
          }
          {
            __unkeyed-1 = "<leader>j";
            group = "jump";
            icon = "";
          }
          {
            __unkeyed-1 = "<leader>l";
            group = "lsp";
            icon = "";
          }
          {
            __unkeyed-1 = "<leader>p";
            group = "projects";
            icon = "";
          }
          {
            __unkeyed-1 = "<leader>q";
            group = "quit";
            icon = "";
          }
          {
            __unkeyed-1 = "<leader>r";
            group = "replace";
            icon = "";
          }
          {
            __unkeyed-1 = "<leader>s";
            group = "search";
            icon = "";
          }
          {
            __unkeyed-1 = "<leader>t";
            group = "test";
            icon = "";
          }
          {
            __unkeyed-1 = "<leader>T";
            group = "toggles";
            icon = "";
          }
          {
            __unkeyed-1 = "<leader>w";
            group = "windows";
            icon = "";
          }
          {
            __unkeyed-1 = "<leader>x";
            group = "text";
            icon = "";
          }
          {
            __unkeyed-1 = "<localleader>g";
            group = "go to";
            icon = "";
          }
          {
            __unkeyed-1 = "<localleader>c";
            group = "code";
            icon = "";
          }
          {
            __unkeyed-1 = "<localleader>ce";
            group = "extract";
            icon = "";
          }
          {
            __unkeyed-1 = "<localleader>ci";
            group = "inline";
            icon = "";
          }
        ];

        win = {
          border = "none";

          padding = [
            2
            2
          ];

          wo = {
            winblend = 0;
          };
        };
      };
    };
  };

  keymaps = [
    # Leader
    {
      key = "<leader><leader>";
      action = ":";
      options.desc = "run command";
    }
    {
      key = "<leader><Tab>";
      action = ":e#<CR>";
      options.desc = "last buffer";
    }
    {
      key = "<leader>'";
      action = "<cmd>ToggleTerm size=10 direction=horizontal<CR>";
      options.desc = "toggle terminal";
    }
    {
      key = "<leader>c";
      action = "<cmd>MCstart<CR>";
      options.desc = "add cursor";
    }

    # Buffers
    {
      key = "<leader>bb";
      action = "<cmd>Telescope buffers<CR>";
      options.desc = "find buffer";
    }
    {
      key = "<leader>bd";
      action = "<cmd>bd<CR>";
      options.desc = "destroy buffer";
    }
    {
      key = "<leader>bk";
      action = "<cmd>q!<CR>";
      options.desc = "kill buffer";
    }

    # Diagnostics
    {
      key = "<leader>db";
      action = "<cmd>Lspsaga show_buf_diagnostics<CR>";
      options.desc = "buffer diagnostics";
    }
    {
      key = "<leader>dl";
      action = "<cmd>Trouble loclist<CR>";
      options.desc = "loclist";
    }
    {
      key = "<leader>dq";
      action = "<cmd>Trouble quickfix<CR>";
      options.desc = "quickfixes";
    }
    {
      key = "<leader>dr";
      action = "<cmd>Trouble lsp_references<CR>";
      options.desc = "references";
    }
    {
      key = "<leader>dt";
      action = "<cmd>Trouble<CR>";
      options.desc = "toggle trouble";
    }

    # Errors
    {
      key = "<leader>ed";
      action = "<cmd>Lspsaga show_cursor_diagnostics<CR>";
      options.desc = "show diagnostics for cursor";
    }
    {
      key = "<leader>eD";
      action = "<cmd>Lspsaga show_line_diagnostics<CR>";
      options.desc = "show diagnostics for line";
    }
    {
      key = "<leader>ee";
      action = "<cmd>Lspsaga diagnostic_jump_prev<CR>";
      options.desc = "prev";
    }
    {
      key = "<leader>en";
      action = "<cmd>Lspsaga diagnostic_jump_next<CR>";
      options.desc = "next";
    }

    # Files
    {
      key = "<leader>fd";
      action = "<cmd>Telescope file_browser path=%:p:h<CR>";
      options.desc = "find files in dir";
    }
    {
      key = "<leader>ff";
      action = "<cmd>Telescope find_files hidden=true<CR>";
      options.desc = "find files";
    }
    {
      key = "<leader>fr";
      action = "<cmd>Telescope frecency<CR>";
      options.desc = "recent files";
    }
    {
      key = "<leader>fR";
      action = "<cmd>so $MYVIMRC<CR>";
      options.desc = "reload configuration";
    }
    {
      key = "<leader>fs";
      action = "<cmd>w!<CR>";
      options.desc = "save files";
    }
    {
      key = "<leader>ft";
      action = "<cmd>NvimTreeFindFileToggle<CR>";
      options.desc = "toggle filetree";
    }

    # Git
    {
      key = "<leader>ga";
      action = "<cmd>git add .<CR>";
      options.desc = "add .";
    }
    {
      key = "<leader>gb";
      action = "<cmd>Telescope git_branches<CR>";
      options.desc = "branches";
    }
    {
      key = "<leader>gB";
      action = "<cmd>GBrowse<CR>";
      options.desc = "git browse";
    }
    {
      key = "<leader>gc";
      action = "<cmd>Git commit<CR>";
      options.desc = "commit";
    }
    {
      key = "<leader>gd";
      action = "<cmd>Git giff<CR>";
      options.desc = "diff";
    }
    {
      key = "<leader>gD";
      action = "<cmd>Gdiffsplit<CR>";
      options.desc = "diff split";
    }
    {
      key = "<leader>ge";
      action = "<cmd>Gitsigns prev_hunk<CR>";
      options.desc = "prev hunk";
    }
    {
      key = "<leader>gg";
      action = "<cmd>Git<CR>";
      options.desc = "status";
    }
    {
      key = "<leader>gh";
      action = "<cmd>Gitsigns toggle_linehl<CR>";
      options.desc = "highlight hunks";
    }
    {
      key = "<leader>gH";
      action = "<cmd>Gitsigns preview_hunk<CR>";
      options.desc = "preview hunk";
    }
    {
      key = "<leader>gl";
      action = "<cmd>Git log<CR>";
      options.desc = "log";
    }
    {
      key = "<leader>gm";
      action = "<cmd>MerginalToggle<CR>";
      options.desc = "toggle merginal";
    }
    {
      key = "<leader>gn";
      action = "<cmd>Gitsigns next_hunk<CR>";
      options.desc = "next hunk";
    }
    {
      key = "<leader>go";
      action = "<cmd>GO<CR>";
      options.desc = "open repo";
    }
    {
      key = "<leader>gp";
      action = "<cmd>Git push<CR>";
      options.desc = "push";
    }
    {
      key = "<leader>gP";
      action = "<cmd>Git pull<CR>";
      options.desc = "pull";
    }
    {
      key = "<leader>gr";
      action = "<cmd>GRemove<CR>";
      options.desc = "rm";
    }
    {
      key = "<leader>gs";
      action = "<cmd>Gitsigns stage_hunk<CR>";
      options.desc = "stage hunk";
    }
    {
      key = "<leader>gt";
      action = "<cmd>Gitsigns toggle_signs<CR>";
      options.desc = "toggle gutter signs";
    }
    {
      key = "<leader>gu";
      action = "<cmd>Gitsigns reset_hunk<CR>";
      options.desc = "undo hunk";
    }
    {
      key = "<leader>gv";
      action = "<cmd>GV<CR>";
      options.desc = "view commits";
    }
    {
      key = "<leader>gV";
      action = "<cmd>GV!<CR>";
      options.desc = "view buffer commits";
    }

    # Jump
    {
      key = "<leader>jb";
      action = "<cmd>HopWordBC<CR>";
      options.desc = "word backwards";
    }
    {
      key = "<leader>jf";
      action = "<cmd>HopWordAC<CR>";
      options.desc = "word forward";
    }
    {
      key = "<leader>jj";
      action = "<cmd>HopChar1<CR>";
      options.desc = "char";
    }
    {
      key = "<leader>jJ";
      action = "<cmd>HopChar2<CR>";
      options.desc = "2 chars";
    }
    {
      key = "<leader>jl";
      action = "<cmd>HopLine<CR>";
      options.desc = "line bidirectional";
    }
    {
      key = "<leader>jw";
      action = "<cmd>HopWord<CR>";
      options.desc = "word bidirectional";
    }

    # Lsp
    {
      key = "<leader>lb";
      action = "<cmd>Telescope diagnostics bufnr=0 theme=get_ivy<CR>";
      options.desc = "buffer diagnostics";
    }
    {
      key = "<leader>lc";
      action = "<cmd>lua vim.lsp.buf.code_action()<CR>";
      options.desc = "code action";
    }
    {
      key = "<leader>ld";
      action = "<cmd>Telescope diagnostics<CR>";
      options.desc = "diagnostics";
    }
    {
      key = "<leader>le";
      action = "<cmd>lua vim.diagnostic.goto_prev()<CR>";
      options.desc = "prev diagnostic";
    }
    {
      key = "<leader>li";
      action = "<cmd>LspInfo<CR>";
      options.desc = "info";
    }
    {
      key = "<leader>ln";
      action = "<cmd>lua vim.diagnostic.goto_next()<CR>";
      options.desc = "next diagnostic";
    }
    {
      key = "<leader>lq";
      action = "<cmd>lua vim.diagnostic.setloclist()<CR>";
      options.desc = "quickfix";
    }
    {
      key = "<leader>ls";
      action = "<cmd>Telescope lsp_document_symbols<CR>";
      options.desc = "document symbols";
    }
    {
      key = "<leader>lS";
      action = "<cmd>Telescope lsp_dynamic_workspace_symbols<CR>";
      options.desc = "workspace symbols";
    }

    # Project
    {
      key = "<leader>pe";
      action = "<cmd>Telescope env<CR>";
      options.desc = "environment variables";
    }
    {
      key = "<leader>pf";
      action = "<cmd>Telescope git_files<CR>";
      options.desc = "find files";
    }
    {
      key = "<leader>pp";
      action = "<cmd>Telescope projects<CR>";
      options.desc = "switch";
    }
    {
      key = "<leader>ps";
      action = "<cmd>lua require('telescope.builtin').live_grep({ additional_args = { '--fixed-strings' }})<CR>";
      options.desc = "search";
    }
    {
      key = "<leader>pS";
      action = "<cmd>Telescope live_grep<CR>";
      options.desc = "search regex";
    }
    {
      key = "<leader>pt";
      action = "<cmd>TodoTelescope<CR>";
      options.desc = "TODOs";
    }

    # Quit
    {
      key = "<leader>qq";
      action = "<cmd>qa<CR>";
      options.desc = "quit";
    }
    {
      key = "<leader>qQ";
      action = "<cmd>qa!<CR>";
      options.desc = "quit without saving";
    }

    # Replace
    {
      key = "<leader>rb";
      action = "<cmd>lua require('grug-far').open({ prefills = { paths = vim.fn.expand(\"%]\") } })<CR>";
      options.desc = "buffer";
    }
    {
      key = "<leader>rp";
      action = "<cmd><CR>";
      options.desc = "project";
    }
    {
      key = "<leader>rw";
      action = "<cmd> lua require('grug-far').open({ prefills = { paths = vim.fn.expand(\"%]\"), search = vim.fn.expand(\"<cword>\") } })<CR>";
      options.desc = "word in buffer";
    }
    {
      key = "<leader>rW";
      action = "<cmd> lua require('grug-far').open({ prefills = { search = vim.fn.expand(\"<cword>\") } })<CR>";
      options.desc = "word in project";
    }

    # Search
    {
      key = "<leader>sp";
      action = "<cmd>lua require('telescope.builtin').live_grep({ additional_args = { '--fixed-strings' }})<CR>";
      options.desc = "project";
    }
    {
      key = "<leader>sP";
      action = "<cmd>Telescope live_grep<CR>";
      options.desc = "project regex";
    }
    {
      key = "<leader>ss";
      action = "<cmd>Telescope current_buffer_fuzzy_find<CR>";
      options.desc = "buffer";
    }
    {
      key = "<leader>sS";
      action = "<cmd>lua require(\"telescope.builtin\").live_grep({search_dirs={vim.fn.expand(\"%:p\")}})<CR>";
      options.desc = "buffer regex";
    }
    {
      key = "<leader>st";
      action = "<cmd>Telescope current_buffer_tags<CR>";
      options.desc = "buffer tags";
    }
    {
      key = "<leader>sT";
      action = "<cmd>Telescope tags<CR>";
      options.desc = "project tags";
    }

    # Tests
    {
      key = "<leader>tf";
      action = "<cmd>lua require(\"neotest\").run.run(vim.fn.expand(\"%\"))<CR>";
      options.desc = "file";
    }
    {
      key = "<leader>tl";
      action = "<cmd>lua require(\"neotest\").run.run_last()<CR>";
      options.desc = "last";
    }
    {
      key = "<leader>tn";
      action = "<cmd>lua require(\"neotest\").run.run()<CR>";
      options.desc = "nearest";
    }
    {
      key = "<leader>to";
      action = "<cmd>lua require(\"neotest\").output.open()<CR>";
      options.desc = "output";
    }
    {
      key = "<leader>ts";
      action = "<cmd>lua require(\"neotest\").summary.toggle()<CR>";
      options.desc = "toggle summary";
    }

    # Toggles
    {
      key = "<leader>Ts";
      action = "<cmd>noh<CR>";
      options.desc = "search highlight";
    }
    {
      key = "<leader>Tt";
      action = "<cmd>Twilight<CR>";
      options.desc = "twilight";
    }
    {
      key = "<leader>Tp";
      action = "<cmd>Precognition toggle<CR>";
      options.desc = "precognition";
    }

    # Windows
    {
      key = "<leader>wd";
      action = "<C-W>c";
      options.desc = "close";
    }
    {
      key = "<leader>we";
      action = "<C-W>k";
      options.desc = "up";
    }
    {
      key = "<leader>wE";
      action = "<cmd>resize -5<CR>";
      options.desc = "expand up";
    }
    {
      key = "<leader>wh";
      action = "<C-W>h";
      options.desc = "left";
    }
    {
      key = "<leader>wH";
      action = "<C-W>5<";
      options.desc = "expand left";
    }
    {
      key = "<leader>wi";
      action = "<C-W>l";
      options.desc = "right";
    }
    {
      key = "<leader>wI";
      action = "<C-W>5>";
      options.desc = "expand right";
    }
    {
      key = "<leader>wn";
      action = "<C-W>j";
      options.desc = "down";
    }
    {
      key = "<leader>wN";
      action = "<cmd>resize +5<CR>";
      options.desc = "expand down";
    }
    {
      key = "<leader>wo";
      action = "<cmd>only<CR>";
      options.desc = "close others";
    }
    {
      key = "<leader>wr";
      action = "<C-W>r";
      options.desc = "rotate";
    }
    {
      key = "<leader>ws";
      action = "<C-W>s<C-W>j";
      options.desc = "split down";
    }
    {
      key = "<leader>wv";
      action = "<C-W>v<C-W>l";
      options.desc = "split right";
    }
    {
      key = "<leader>w=";
      action = "<C-W>=";
      options.desc = "balance";
    }

    # Text
    {
      key = "<leader>xd";
      action = "<cmd>%s/\\s\\+$//e<CR>";
      options.desc = "delete trailing whitespace";
    }

    # Code
    {
      key = "<localleader>ca";
      action = "<cmd>lua vim.lsp.buf.code_action()<CR>";
      options.desc = "code action";
    }
    {
      key = "<localleader>cd";
      action = "<cmd>lua vim.diagnostic.open_float()<CR>";
      options.desc = "diagnostics";
    }
    {
      key = "<localleader>cn";
      action = "<cmd>Navbuddy<CR>";
      options.desc = "navigate";
    }
    {
      key = "<localleader>ceb";
      action = "<cmd>Refactor extract_block<CR>";
      options.desc = "block";
    }
    {
      key = "<localleader>ceB";
      action = "<cmd>Refactor extract_block_to_file<CR>";
      options.desc = "block to file";
    }
    {
      key = "<localleader>cef";
      action = ":Refactor extract ";
      options.desc = "function";
    }
    {
      key = "<localleader>ceF";
      action = ":Refactor extract_to_file ";
      options.desc = "function to file";
    }
    {
      key = "<localleader>cev";
      action = ":Refactor extract_var ";
      options.desc = "variable";
    }
    {
      key = "<localleader>civ";
      action = "<cmd>Refactor inline_var<CR>";
      options.desc = "variable";
    }
    {
      key = "<localleader>cif";
      action = "<cmd>Refactor inline_func<CR>";
      options.desc = "function";
    }
  ];
}
