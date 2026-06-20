{
  plugins = {
    numbertoggle = {
      enable = true;
    };
  };

  # Prose reads cleaner without the gutter — drop line numbers AND the fold column
  # for markdown, plain text, and git commit messages. (numbertoggle only flips
  # relativenumber when 'number' is set, so turning 'number' off keeps it away too.)
  autoCmd = [
    {
      event = "FileType";
      pattern = [
        "markdown"
        "text"
        "gitcommit"
      ];
      command = "setlocal nonumber norelativenumber foldcolumn=0";
    }
  ];
}
