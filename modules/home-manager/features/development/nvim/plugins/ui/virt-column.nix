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
            "markdown" # prose: no column guides (markdown / plain text / git messages)
            "text"
            "gitcommit"
          ];
        };

        virtcolumn = "80,120,140";
      };
    };
  };
}
