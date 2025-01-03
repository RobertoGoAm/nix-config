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

        dockerls = {
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

      beacon = {
        enable = true;
      };

      codeAction = {
        extendGitSigns = false;
        numShortcut = true;
        onlyInCursor = true;
        showServerName = true;

        keys = {
          exec = "<CR>";

          quit = [
            "<Esc>"
            "q"
          ];
        };
      };

      diagnostic = {
        borderFollow = true;
        diagnosticOnlyCurrent = false;
        showCodeAction = true;
      };

      hover = {
        openCmd = "!floorp";
        openLink = "<localleader>gx";
      };

      implement = {
        enable = false;
      };

      lightbulb = {
        enable = false;
        sign = false;
        virtualText = true;
      };

      outline = {
        autoClose = true;
        autoPreview = true;
        closeAfterJump = true;
        layout = "normal";
        winPosition = "right";

        keys = {
          jump = "e";
          quit = "q";
          toggleOrJump = "o";
        };
      };

      rename = {
        autoSave = false;

        keys = {
          exec = "<CR>";

          quit = [
            "<C-k>"
            "<Esc>"
          ];

          select = "x";
        };
      };

      scrollPreview = {
        scrollDown = "<C-t>";
        scrollUp = "<C-b>";
      };

      symbolInWinbar = {
        enable = true;
      };

      ui = {
        border = "rounded";
        codeAction = "💡";
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
