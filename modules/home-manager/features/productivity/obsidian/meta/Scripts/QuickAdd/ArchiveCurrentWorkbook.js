module.exports = async (params) => {
  const { app, obsidian, abort } = params;
  const activeFile = app.workspace.getActiveFile();

  if (!activeFile) {
    abort("No active note to archive.");
  }

  if (!activeFile.path.startsWith("Inbox/")) {
    abort("Archive Current Workbook only works on notes in Inbox/.");
  }

  const cache = app.metadataCache.getFileCache(activeFile) ?? {};
  const frontmatterTags = Array.isArray(cache.frontmatter?.tags) ? cache.frontmatter.tags : [];

  if (!frontmatterTags.includes("language")) {
    abort("Archive Current Workbook only works on language workbook/class notes.");
  }

  const archiveFolder = "Archive/Language Workbook";
  const queuePath = "IW-Queues/IW-Queue.md";
  const destinationPath = obsidian.normalizePath(`${archiveFolder}/${activeFile.name}`);

  const ensureFolder = async (folderPath) => {
    const existing = app.vault.getAbstractFileByPath(folderPath);
    if (existing) return;

    const segments = folderPath.split("/");
    for (let index = 0; index < segments.length; index += 1) {
      const partial = segments.slice(0, index + 1).join("/");
      if (!app.vault.getAbstractFileByPath(partial)) {
        await app.vault.createFolder(partial);
      }
    }
  };

  const removeFromQueue = async () => {
    const queueFile = app.vault.getAbstractFileByPath(queuePath);
    if (!(queueFile instanceof obsidian.TFile)) return false;

    const linkTargets = new Set([
      activeFile.basename,
      app.metadataCache.fileToLinktext(activeFile, "", false),
      app.metadataCache.fileToLinktext(activeFile, "", true),
      activeFile.path.replace(/\.md$/, "")
    ].filter(Boolean));

    const original = await app.vault.read(queueFile);
    const filtered = original
      .split(/\r?\n/)
      .filter((line) => ![...linkTargets].some((target) => line.includes(`[[${target}]]`)));

    if (filtered.join("\n") !== original) {
      await app.vault.modify(queueFile, filtered.join("\n"));
      return true;
    }

    return false;
  };

  if (app.vault.getAbstractFileByPath(destinationPath)) {
    abort(`Archive target already exists: ${destinationPath}`);
  }

  await ensureFolder(archiveFolder);
  const removedFromQueue = await removeFromQueue();
  await app.fileManager.renameFile(activeFile, destinationPath);

  new obsidian.Notice(
    removedFromQueue
      ? `Archived to ${destinationPath} and removed from IW queue.`
      : `Archived to ${destinationPath}.`
  );
};
