# development nvim plugins notes obsidian

{
  plugins.obsidian = {
    enable = true;

    settings = {
      dir = "~/Documents/robertogoam";
      legacy_commands = false;
    };
  };

  # Notes for the project in front of you

  # =<leader>nn= asks for a title and starts a note in the notes folder of the
  # project being worked on, the one =notes dir= (=cli/notes.org=) names for the
  # current file's folder, or for the working folder when the buffer is no file:
  # =<area>/Projects/<repository>/notes= in the vault. The note opens with the
  # title as its heading and the cursor in insert mode under it; a title that is
  # already a note opens that note. A slash or colon in the title becomes a dash,
  # as neither can be in a file name. =<leader>nf= finds a note in that folder
  # and =<leader>nb= opens it in the file tree; =<leader>no= still switches to
  # any note in the vault.

  extraConfigLua = ''
    local function project_notes()
      local name = vim.api.nvim_buf_get_name(0)
      local from = (name ~= "" and vim.fn.filereadable(name) == 1) and vim.fn.fnamemodify(name, ":p:h") or vim.fn.getcwd()
      local out = vim.fn.systemlist({ "notes", "dir", from })
      if vim.v.shell_error ~= 0 or not out[1] or out[1] == "" then
        vim.notify("notes: no notes folder for " .. from, vim.log.levels.ERROR)
        return nil
      end
      return out[1]
    end

    function _G.notes_new()
      local dir = project_notes()
      if not dir then return end
      vim.ui.input({ prompt = "Note title: " }, function(title)
        title = title and vim.trim(title) or ""
        if title == "" then return end
        vim.fn.mkdir(dir, "p")
        local path = dir .. "/" .. title:gsub("[/\\:]", "-") .. ".md"
        local fresh = vim.fn.filereadable(path) == 0
        vim.cmd.edit(vim.fn.fnameescape(path))
        if fresh then
          vim.api.nvim_buf_set_lines(0, 0, -1, false, { "# " .. title, "", "" })
          vim.api.nvim_win_set_cursor(0, { 3, 0 })
        else
          vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(0), 0 })
        end
        vim.cmd("startinsert!")
      end)
    end

    function _G.notes_find()
      local dir = project_notes()
      if not dir then return end
      vim.fn.mkdir(dir, "p")
      require("telescope.builtin").find_files({ cwd = dir, prompt_title = "Project notes" })
    end

    function _G.notes_browse()
      local dir = project_notes()
      if not dir then return end
      vim.fn.mkdir(dir, "p")
      require("nvim-tree.api").tree.open({ path = dir })
    end
  '';
}
