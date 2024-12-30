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
          ];
        };

        virtcolumn = "80,120,140";
      };
    };
  };
}
