{
  plugins = {
    lualine = {
      enable = true;

      settings = {
        options = {
          disabled_filetypes = {
            __unkeyed-1 = "help";
            __unkeyed-2 = "NvimTree";
            __unkeyed-3 = "toggleterm";
          };
        };
      };

      luaConfig.pre = ''
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
      '';
    };
  };
}
