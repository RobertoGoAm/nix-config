{
  lib,
  pkgs,
  ...
}:
{
  plugins = {
    lsp = {
      enable = true;
      inlayHints = true;

      servers = {
        bashls = {
          enable = true;
        };

        cssls = {
          enable = true;
        };

        eslint = {
          enable = true;
        };

        gopls = {
          enable = true;
        };

        hls = {
          enable = true;

          installGhc = true;
        };

        html = {
          enable = true;
        };

        htmx = {
          enable = true;
        };

        jsonls = {
          enable = true;
        };

        lua_ls = {
          enable = true;
        };

        nixd = {
          enable = true;

          settings = {
            formatting = {
              command = [ "${lib.getExe pkgs.nixfmt-rfc-style}" ];
            };
          };
        };

        pyright = {
          enable = true;
        };

        tailwindcss = {
          enable = true;
        };

        ts_ls = {
          enable = true;
          autostart = true;
          filetypes = [
            "javascript"
            "javascriptreact"
            "javascript.jsx"
            "typescript"
            "typescriptreact"
            "typescript.tsx"
          ];
          extraOptions = {
            settings = {
              javascript = {
                inlayHints = {
                  includeInlayEnumMemberValueHints = true;
                  includeInlayFunctionLikeReturnTypeHints = true;
                  includeInlayFunctionParameterTypeHints = true;
                  includeInlayParameterNameHints = "all";
                  includeInlayParameterNameHintsWhenArgumentMatchesName = true;
                  includeInlayPropertyDeclarationTypeHints = true;
                  includeInlayVariableTypeHints = true;
                  includeInlayVariableTypeHintsWhenTypeMatchesName = true;
                };
              };
              typescript = {
                inlayHints = {
                  includeInlayEnumMemberValueHints = true;
                  includeInlayFunctionLikeReturnTypeHints = true;
                  includeInlayFunctionParameterTypeHints = true;
                  includeInlayParameterNameHints = "all";
                  includeInlayParameterNameHintsWhenArgumentMatchesName = true;
                  includeInlayPropertyDeclarationTypeHints = true;
                  includeInlayVariableTypeHints = true;
                  includeInlayVariableTypeHintsWhenTypeMatchesName = true;
                };
              };
            };
          };
        };

        volar = {
          enable = true;
        };

        yamlls = {
          enable = true;
        };
      };

      keymaps = {
        silent = true;

        lspBuf = {
          "<localleader>gd" = {
            action = "definition";
            desc = "definition";
          };

          "<localleader>gD" = {
            action = "declaration";
            desc = "declaration";
          };

          "<localleader>gI" = {
            action = "implementation";
            desc = "implementation";
          };

          "<localleader>gr" = {
            action = "references";
            desc = "references";
          };

          "<localleader>gT" = {
            action = "type_definition";
            desc = "type definition";
          };

          "<localleader>cr" = {
            action = "rename";
            desc = "rename";
          };
        };
      };
    };

    lspsaga = {
      enable = true;

      settings = {
        beacon = {
          enable = true;
        };

        code_action = {
          extend_git_signs = false;
          num_shortcut = true;
          only_in_cursor = true;
          show_server_name = true;

          keys = {
            exec = "<CR>";

            quit = [
              "<Esc>"
              "q"
            ];
          };
        };

        diagnostic = {
          border_follow = true;
          diagnostic_only_current = false;
          show_code_action = true;
        };

        hover = {
          open_cmd = "!floorp";
          open_link = "<localleader>gx";
        };

        implement = {
          enable = false;
        };

        lightbulb = {
          enable = false;
          sign = false;
          virtual_text = true;
        };

        outline = {
          auto_close = true;
          auto_preview = true;
          close_after_jump = true;
          layout = "normal";
          win_position = "right";

          keys = {
            jump = "e";
            quit = "q";
            toggle_or_jump = "o";
          };
        };

        rename = {
          auto_save = false;

          keys = {
            exec = "<CR>";

            quit = [
              "<C-k>"
              "<Esc>"
            ];

            select = "x";
          };
        };

        scroll_preview = {
          scroll_down = "<C-t>";
          scroll_up = "<C-b>";
        };

        symbol_in_winbar = {
          enable = true;
        };

        ui = {
          border = "rounded";
          code_action = "💡";
        };
      };
    };

    none-ls = {
      enable = true;
      enableLspFormat = true;

      settings = {
        updateInInsert = false;
      };

      sources = {
        code_actions = {
          statix.enable = true;
        };

        diagnostics = {
          statix.enable = true;
          yamllint.enable = true;
        };

        formatting = {
          black = {
            enable = true;
          };

          hclfmt = {
            enable = true;
          };

          nixfmt = {
            enable = true;
            package = pkgs.nixfmt-rfc-style;
          };

          prettier = {
            enable = true;
            disableTsServerFormatter = true;
          };

          stylua = {
            enable = true;
          };

          yamlfmt = {
            enable = true;
          };
        };
      };
    };
  };

  extraConfigLua = ''
    local _border = "rounded"

    vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
      vim.lsp.handlers.hover, {
        border = _border
      }
    )

    vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(
      vim.lsp.handlers.signature_help, {
        border = _border
      }
    )

    vim.diagnostic.config{
      float={border=_border}
    };

    require('lspconfig.ui.windows').default_options = {
      border = _border
    }
  '';
}
