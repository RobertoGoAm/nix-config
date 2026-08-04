{ pkgs, lib, osConfig ? { }, ... }:
let
  # Workstation-only: the vault lives in ~/Documents on the laptop. Skip it on the
  # headless vulcan server — the vault isn't there, and macOS TCC blocks writing to
  # ~/Documents over SSH anyway, which fails home-manager activation on rebuilds.
  onWorkstation = (osConfig.networking.hostName or "") != "vulcan";
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
lib.mkIf onWorkstation {
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
      # Obsidian Sync owns .obsidian config and plugin data.json — do not
      # manage them via home.file (read-only nix store symlinks break sync).
      # Baseline copies live in ./config and ./plugin-data for reference.
      "${vaultPath}/.obsidian.vimrc".source = ./vault-root/.obsidian.vimrc;
    };
}
