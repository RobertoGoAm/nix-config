# development nvim plugins notes markview

# Markdown is drawn rendered the way Obsidian's live preview draws it: the
# whole buffer stays rendered while typing too, and only the line under the
# cursor shows its markdown as written, so a heading being edited shows its
# =#= and goes back to a heading when the cursor leaves it. Markview's own
# default renders in normal mode only and shows the whole buffer raw in insert
# mode.

{
  plugins.markview = {
    enable = true;

    settings.preview = {
      modes = [
        "n"
        "no"
        "c"
        "i"
      ];
      hybrid_modes = [
        "n"
        "i"
      ];
      linewise_hybrid_mode = true;
    };

    # A terminal draws every line at one size, so a heading cannot be bigger than
    # the text under it (the kitty protocol's text sizing, which could, is read and
    # then not drawn by Herdr's terminal). Headings are told apart by a rule
    # instead, as glow and zigdown draw them: the title in its level's colour and
    # bold, between a rule that starts the line and one that runs to the window's
    # edge, doubled (=═=) for the first level and single (=─=) below it. Markview
    # draws the start, its label style with the =#= marks hidden and no sign in
    # the gutter; its labels end where the text ends, so the rest of the rule is
    # drawn below.

    settings.markdown.headings =
      let
        level = n: {
          style = "label";
          icon = "";
          padding_left = if n == 1 then "══ " else "── ";
          padding_right = "";
          sign = false;
          hl = "NotesHeading${toString n}";
        };
      in
      {
        enable = true;
        shift_width = 0;
        heading_1 = level 1;
        heading_2 = level 2;
        heading_3 = level 3;
        heading_4 = level 4;
        heading_5 = level 5;
        heading_6 = level 6;
      };
  };

  # The colours are markview's own per level (the ones it gives its heading
  # signs, foreground only), made bold, and made again when the colour scheme
  # changes. The rest of the rule is text at the end of the heading's line,
  # which Neovim cuts at the window's edge rather than wrapping, so one long rule
  # fills any width; it is redrawn whenever the buffer changes, skipping lines
  # inside code fences.

  extraConfigLua = ''
    do
      local function heading_colours()
        for n = 1, 6 do
          local fg
          for _, name in ipairs({ "MarkviewHeading" .. n .. "Sign", "@markup.heading." .. n .. ".markdown", "Title" }) do
            fg = vim.api.nvim_get_hl(0, { name = name, link = false }).fg
            if fg then break end
          end
          vim.api.nvim_set_hl(0, "NotesHeading" .. n, { fg = fg, bold = true })
        end
      end
      heading_colours()
      vim.api.nvim_create_autocmd("ColorScheme", { callback = heading_colours })

      local ns = vim.api.nvim_create_namespace("notes_heading_rules")
      local rule = { string.rep("═", 400), string.rep("─", 400) }
      local function rules(buf)
        vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
        local fence = false
        for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
          if line:match("^%s*```") or line:match("^%s*~~~") then
            fence = not fence
          elseif not fence then
            local marks = line:match("^(#+)%s")
            if marks and #marks <= 6 then
              vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
                virt_text = { { rule[#marks == 1 and 1 or 2], "NotesHeading" .. #marks } },
                virt_text_pos = "eol",
              })
            end
          end
        end
      end
      vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI" }, {
        callback = function(ev)
          if vim.bo[ev.buf].filetype == "markdown" then rules(ev.buf) end
        end,
      })
    end
  '';
}
