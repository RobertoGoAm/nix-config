{ pkgs, ... }:
let
  vaultPath = "Documents/robertogoam";
in
{
  home.packages = [ pkgs.obsidian ];

  home.file = {
    "${vaultPath}/.obsidian/app.json".text = builtins.toJSON {
      vimMode = true;
      promptDelete = false;
      pdfExportSettings = {
        pageSize = "Letter";
        landscape = false;
        margin = "0";
        downscalePercent = 100;
      };
      openBehavior = "daily";
    };

    "${vaultPath}/.obsidian/appearance.json".text = builtins.toJSON {
      cssTheme = "Catppuccin";
      baseFontSizeAction = true;
      theme = "obsidian";
      accentColor = "";
    };

    "${vaultPath}/.obsidian/core-plugins.json".text = builtins.toJSON {
      file-explorer = true;
      global-search = true;
      switcher = true;
      graph = true;
      backlink = true;
      canvas = true;
      outgoing-link = true;
      tag-pane = true;
      footnotes = false;
      properties = false;
      page-preview = true;
      daily-notes = true;
      templates = true;
      note-composer = true;
      command-palette = true;
      slash-command = false;
      editor-status = true;
      bookmarks = true;
      markdown-importer = false;
      zk-prefixer = false;
      random-note = false;
      outline = true;
      word-count = true;
      slides = false;
      audio-recorder = false;
      workspaces = false;
      file-recovery = true;
      publish = false;
      sync = true;
      bases = true;
      webviewer = false;
    };

    "${vaultPath}/.obsidian/community-plugins.json".text = builtins.toJSON [
      "better-recall"
      "terminal"
    ];
  };
}