{
  plugins = {
    aerial = {
      enable = true;

      settings = {
        close_on_select = true;
      };
    };

    hop = {
      enable = true;
    };

    illuminate = {
      enable = true;
    };

    navbuddy = {
      enable = true;

      settings = {
        lsp = {
          auto_attach = true;
        };

        mappings = {
          "0" = "root";
          "<C-s>" = "hsplit";
          "<C-v>" = "vsplit";
          "<enter>" = "select";
          "<esc>" = "close";
          A = "append_scope";
          F = "fold_delete";
          L = "insert_scope";
          N = "move_down";
          E = "move_up";
          V = "visual_scope";
          Y = "yank_scope";
          a = "append_name";
          c = "comment";
          d = "delete";
          f = "fold_create";
          h = "parent";
          l = "insert_name";
          n = "next_sibling";
          e = "previous_sibling";
          i = "children";
          o = "select";
          q = "close";
          r = "rename";
          s = "toggle_preview";
          v = "visual_name";
          y = "yank_name";
        };
      };
    };

    nvim-ufo = {
      enable = true;
    };

    precognition = {
      enable = true;

      settings = {
        hints = {
          B = {
            prio = 6;

            text = "B";
          };

          Caret = {
            prio = 2;
            text = "^";
          };

          Dollar = {
            prio = 1;
            text = "$";
          };

          E = {
            prio = 5;
            text = "K";
          };

          MatchingPair = {
            prio = 5;
            text = "%";
          };

          W = {
            prio = 7;
            text = "W";
          };

          Zero = {
            prio = 1;
            text = "0";
          };

          b = {
            prio = 9;
            text = "b";
          };

          e = {
            prio = 8;
            text = "k";
          };

          w = {
            prio = 10;
            text = "w";
          };
        };

        startVisible = false;
      };
    };

    scrollview = {
      enable = true;
    };
  };
}
