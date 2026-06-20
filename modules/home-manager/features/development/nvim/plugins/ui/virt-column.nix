{
  plugins = {
    virt-column = {
      enable = true;

      settings = {
        exclude = {
          buftypes = [
            "nofile"
            "quickfix"
            "terminal"
            "prompt"
          ];

          filetypes = [
            "dashboard"
            "lspinfo"
            "packer"
            "checkhealth"
            "help"
            "man"
            "TelescopePrompt"
            "TelescopeResults"
            "markdown" # no column guides while reading/rendering markdown
          ];
        };

        virtcolumn = "80,120,140";
      };
    };
  };
}
