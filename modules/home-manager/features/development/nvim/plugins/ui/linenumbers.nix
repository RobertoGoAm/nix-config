{
  plugins = {
    numbertoggle = {
      enable = true;
    };
  };

  # Prose-filetype tweaks (markdown / plain text / git messages): no gutter — drop
  # line numbers and the fold column — and soft-wrap long lines at word boundaries
  # with a hanging indent. (numbertoggle only flips relativenumber when 'number' is
  # set, so turning 'number' off keeps it away too.)
  autoCmd = [
    {
      event = "FileType";
      pattern = [
        "markdown"
        "text"
        "gitcommit"
      ];
      command = "setlocal nonumber norelativenumber foldcolumn=0 wrap linebreak breakindent";
    }
  ];
}
