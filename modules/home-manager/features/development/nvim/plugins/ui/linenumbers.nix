{
  plugins = {
    numbertoggle = {
      enable = true;
    };
  };

  # Prose reads cleaner without the gutter — drop line numbers for markdown, plain
  # text, and git commit messages. numbertoggle only flips relativenumber when
  # 'number' is set, so turning 'number' off here keeps it from re-adding the column.
  autoCmd = [
    {
      event = "FileType";
      pattern = [
        "markdown"
        "text"
        "gitcommit"
      ];
      command = "setlocal nonumber norelativenumber";
    }
  ];
}
