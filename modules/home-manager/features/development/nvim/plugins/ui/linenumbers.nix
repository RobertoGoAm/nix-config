{
  plugins = {
    numbertoggle = {
      enable = true;
    };
  };

  # Markdown reads cleaner without the gutter — drop line numbers for it. numbertoggle
  # only flips relativenumber when 'number' is set, so turning 'number' off here keeps
  # it from re-adding the column.
  autoCmd = [
    {
      event = "FileType";
      pattern = "markdown";
      command = "setlocal nonumber norelativenumber";
    }
  ];
}
