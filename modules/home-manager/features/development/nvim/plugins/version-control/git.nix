{
  plugins = {
    fugitive.enable = true;

    gitsigns = {
      enable = true;

      settings = {
        current_line_blame = true;
        current_line_blame_formatter = "   <author>, <committer_time:%R> • <summary>";

        current_line_blame_opts = {
          delay = 100;
          virt_text = true;
          virt_text_pos = "eol";
        };

        signcolumn = true;

        signs = {
          add = {
            text = "│";
          };

          change = {
            text = "│";
          };

          changedelete = {
            text = "~";
          };

          delete = {
            text = "_";
          };

          topdelete = {
            text = "‾";
          };

          untracked = {
            text = "┆";
          };
        };

        trouble = true;
        update_debounce = 100;
      };
    };
  };
}
