module.exports = async (params) => {
  const { app, obsidian, abort } = params;
  const activeFile = app.workspace.getActiveFile();

  class FolderSuggestModal extends obsidian.FuzzySuggestModal {
    constructor(items) {
      super(app);
      this.items = items;
      this.setPlaceholder("Choose a Knowledge folder");
      this.result = new Promise((resolve, reject) => {
        this._resolve = resolve;
        this._reject = reject;
      });
      this.open();
    }

    getItems() {
      return this.items;
    }

    getItemText(item) {
      return item;
    }

    onChooseItem(item) {
      this._resolve(item);
    }

    onClose() {
      super.onClose();
      this._reject?.("No folder selected.");
    }
  }

  if (!activeFile) abort("No active note to process.");
  if (!activeFile.path.startsWith("Inbox/")) {
    abort("Process to Knowledge only works on notes in Inbox/.");
  }

  const cache = app.metadataCache.getFileCache(activeFile) ?? {};
  const frontmatter = cache.frontmatter ?? {};
  const tags = Array.isArray(frontmatter.tags) ? frontmatter.tags : [];

  const defaultFolder = (() => {
    if (tags.includes("language") || tags.includes("german")) return "Languages/German";
    if (frontmatter.type === "book") return "Books";
    if (frontmatter.type === "article" || frontmatter.type === "video" || frontmatter.type === "course") return "Programming";
    return "Languages/German";
  })();

  const listKnowledgeFolders = () => {
    const folders = app.vault.getAllLoadedFiles()
      .filter((file) => file instanceof obsidian.TFolder)
      .map((folder) => folder.path)
      .filter((path) => path === "Knowledge" || path.startsWith("Knowledge/"))
      .map((path) => path.replace(/^Knowledge\/?/, ""))
      .filter((path) => path.length > 0)
      .filter((path) => !path.startsWith("Sources"))
      .filter((path) => path.split("/").length <= 2);

    const options = Array.from(new Set([defaultFolder, ...folders]));
    options.sort((a, b) => a.localeCompare(b));
    return options;
  };

  const ensureFolder = async (folderPath) => {
    const segments = folderPath.split("/");
    for (let index = 0; index < segments.length; index += 1) {
      const partial = segments.slice(0, index + 1).join("/");
      if (!app.vault.getAbstractFileByPath(partial)) {
        await app.vault.createFolder(partial);
      }
    }
  };

  let selectedFolder;
  try {
    selectedFolder = await new FolderSuggestModal(listKnowledgeFolders()).result;
  } catch {
    abort("Processing cancelled.");
  }

  const targetFolder = `Knowledge/${selectedFolder}`;
  const targetPath = obsidian.normalizePath(`${targetFolder}/${activeFile.name}`);

  if (app.vault.getAbstractFileByPath(targetPath)) {
    abort(`Target already exists: ${targetPath}`);
  }

  await ensureFolder(targetFolder);
  await app.fileManager.processFrontMatter(activeFile, (fm) => {
    fm.type = "permanent";
    fm.status = "seedling";
    fm.lastUpdated = window.moment().format("YYYY-MM-DD");
  });
  await app.fileManager.renameFile(activeFile, targetPath);

  new obsidian.Notice(`Moved to ${targetFolder} as a seedling.`);
};
