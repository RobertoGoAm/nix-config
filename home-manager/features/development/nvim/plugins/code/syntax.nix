{
  plugins = {
    treesitter = {
      enable = true;

      folding = true;
      nixvimInjections = true;

      settings = {
        highlight = {
          enable = true;
        };

        indent = {
          enable = true;
        };
      };
    };

    treesitter-textobjects = {
      enable = true;
      select = {
        enable = true;

        keymaps = {
          "aa" = "@parameter.outer";
          "ia" = "@parameter.inner";
          "af" = "@function.outer";
          "if" = "@function.inner";
          "ac" = "@class.outer";
          "ic" = "@class.inner";
          "ii" = "@conditional.inner";
          "ai" = "@conditional.outer";
          "il" = "@loop.inner";
          "al" = "@loop.outer";
          "at" = "@comment.outer";
        };

        lookahead = true;
      };
      move = {
        enable = true;

        gotoNextEnd = {
          "]M" = "@function.outer";
          "][" = "@class.outer";
        };

        gotoNextStart = {
          "]m" = "@function.outer";
          "]]" = "@class.outer";
        };

        gotoPreviousEnd = {
          "[M" = "@function.outer";
          "[]" = "@class.outer";
        };

        gotoPreviousStart = {
          "[m" = "@function.outer";
          "[[" = "@class.outer";
        };
      };
    };
  };
}
