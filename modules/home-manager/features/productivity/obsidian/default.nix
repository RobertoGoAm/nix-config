{ pkgs, lib, ... }:
let
  vaultPath = "Documents/robertogoam";
  obsidianPath = "${vaultPath}/.obsidian";
  metaPath = "${vaultPath}/000 Meta";

  mkMetaFiles = subdir: sourceDir:
    let
      files = builtins.attrNames (builtins.readDir sourceDir);
      mdFiles = builtins.filter (f: lib.hasSuffix ".md" f) files;
    in
    lib.listToAttrs (map (f: {
      name = "${metaPath}/${subdir}/${f}";
      value = { source = sourceDir + "/${f}"; };
    }) mdFiles);

in
{
  home.packages = [ pkgs.obsidian ];

  home.file =
    (mkMetaFiles "Templates" ./meta/Templates)
    // (mkMetaFiles "How To" ./meta/how-to)
    // (mkMetaFiles "Dashboards" ./meta/Dashboards)
    // {
      "${metaPath}/Scripts/QuickAdd/Archive Current Workbook.js".source =
        ./meta/Scripts/QuickAdd/ArchiveCurrentWorkbook.js;
      "${metaPath}/Scripts/QuickAdd/Process to Knowledge.js".source =
        ./meta/Scripts/QuickAdd/ProcessToKnowledge.js;
      "${metaPath}/Scripts/QuickAdd/Promote Status.js".source =
        ./meta/Scripts/QuickAdd/PromoteStatus.js;
    }
    // {
      "${obsidianPath}/snippets/dashboard.css".source = ./snippets/dashboard.css;
    }
    // {
      "${vaultPath}/.obsidian.vimrc".source = ./vault-root/.obsidian.vimrc;

      "${obsidianPath}/app.json".text = builtins.readFile ./config/app.json;
      "${obsidianPath}/appearance.json".text = builtins.readFile ./config/appearance.json;
      "${obsidianPath}/community-plugins.json".text = builtins.readFile ./config/community-plugins.json;
      "${obsidianPath}/core-plugins.json".text = builtins.readFile ./config/core-plugins.json;
      "${obsidianPath}/daily-notes.json".text = builtins.readFile ./config/daily-notes.json;
      "${obsidianPath}/graph.json".text = builtins.readFile ./config/graph.json;
      "${obsidianPath}/hotkeys.json".text = builtins.readFile ./config/hotkeys.json;
      "${obsidianPath}/templates.json".text = builtins.readFile ./config/templates.json;
      "${obsidianPath}/types.json".text = builtins.readFile ./config/types.json;
    }
    // {
      "${obsidianPath}/plugins/agent-client/data.json".source =
        ./plugin-data/agent-client/data.json;
      "${obsidianPath}/plugins/calendar/data.json".source =
        ./plugin-data/calendar/data.json;
      "${obsidianPath}/plugins/dataview/data.json".source =
        ./plugin-data/dataview/data.json;
      "${obsidianPath}/plugins/homepage/data.json".source =
        ./plugin-data/homepage/data.json;
      "${obsidianPath}/plugins/new-tab-default-page/data.json".source =
        ./plugin-data/new-tab-default-page/data.json;
      "${obsidianPath}/plugins/obsidian-advanced-slides/data.json".source =
        ./plugin-data/obsidian-advanced-slides/data.json;
      "${obsidianPath}/plugins/obsidian-spaced-repetition/data.json".source =
        ./plugin-data/obsidian-spaced-repetition/data.json;
      "${obsidianPath}/plugins/obsidian-style-settings/data.json".source =
        ./plugin-data/obsidian-style-settings/data.json;
      "${obsidianPath}/plugins/obsidian-tasks-plugin/data.json".source =
        ./plugin-data/obsidian-tasks-plugin/data.json;
      "${obsidianPath}/plugins/obsidian42-brat/data.json".source =
        ./plugin-data/obsidian42-brat/data.json;
      "${obsidianPath}/plugins/omnisearch/data.json".source =
        ./plugin-data/omnisearch/data.json;
      "${obsidianPath}/plugins/pdf-plus/data.json".source =
        ./plugin-data/pdf-plus/data.json;
      "${obsidianPath}/plugins/quickadd/data.json".source =
        ./plugin-data/quickadd/data.json;
      "${obsidianPath}/plugins/table-editor-obsidian/data.json".source =
        ./plugin-data/table-editor-obsidian/data.json;
      "${obsidianPath}/plugins/templater-obsidian/data.json".source =
        ./plugin-data/templater-obsidian/data.json;
      "${obsidianPath}/plugins/terminal/data.json".source =
        ./plugin-data/terminal/data.json;
      "${obsidianPath}/plugins/statusbar-organizer/data.json".source =
        ./plugin-data/statusbar-organizer/data.json;
    };
}
