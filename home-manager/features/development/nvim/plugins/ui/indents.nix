{
  plugins = {
    indent-blankline = {
      enable = true;

      settings = {
        exclude = {
          buftypes = [
            "terminal"
            "quickfix"
          ];

          filetypes = [
            ""
            "checkhealth"
            "dashboard"
            "help"
            "lspinfo"
            "packer"
            "TelescopePrompt"
            "TelescopeResults"
            "yaml"
          ];
        };
      };
    };
  };
}
