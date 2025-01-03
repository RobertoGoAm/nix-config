{
  globals.mapleader = " ";
  globals.maplocalleader = ",";

  keymaps = [
    # COLEMAK REMAPS
    {
      key = "n";
      action = "j";
    }
    {
      key = "N";
      action = "J";
    }
    {
      key = "e";
      action = "k";
    }
    {
      key = "E";
      action = "K";
    }
    {
      key = "i";
      action = "l";
    }
    {
      key = "I";
      action = "L";
    }
    {
      key = "j";
      action = "n";
    }
    {
      key = "J";
      action = "N";
    }
    {
      key = "k";
      action = "e";
    }
    {
      key = "K";
      action = "E";
    }
    {
      key = "l";
      action = "i";
    }
    {
      key = "L";
      action = "I";
    }
    {
      key = "<C-p>";
      action = "<C-e>";
    }
    {
      key = "<C-e>";
      action = "<C-p>";
    }
    {
      key = "<C-P>";
      action = "<C-E>";
    }
    {
      key = "<C-E>";
      action = "<C-P>";
    }

    # Delete without copying text
    {
      key = "x";
      action = "\"_x";
    }
    {
      key = "X";
      action = "\"_X";
    }
    {
      key = "<Del>";
      action = "\"_x";
    }

    # Escape term with ESC
    {
      mode = "t";
      key = "<Esc>";
      action = "<C-\\><C-n>";
    }

    # Increment and decrement stuff
    {
      key = "+";
      action = "<C-x>";
    }
    {
      key = "-";
      action = "<C-a>";
    }
    {
      key = "<Tab>";
      action.__raw = ''
        function(fallback) if cmp.visible() then
            cmp.select_next_item() -- or whatever else you want nvim-cmp to do when you press tab
          else
            require("intellitab").indent()
          end
        end
      '';
    }
  ];
}
