module.exports = async (params, settings) => {
  const { app, obsidian, abort } = params;
  const activeFile = app.workspace.getActiveFile();
  const status = settings?.status;
  const label = settings?.label ?? status;

  if (!activeFile) abort("No active note to promote.");
  if (!status) abort("Missing target status.");
  if (!activeFile.path.startsWith("Knowledge/")) {
    abort(`Promote to ${label} only works on notes in Knowledge/.`);
  }

  await app.fileManager.processFrontMatter(activeFile, (fm) => {
    fm.type = "permanent";
    fm.status = status;
    fm.lastUpdated = window.moment().format("YYYY-MM-DD");
  });

  new obsidian.Notice(`Status updated to ${label}.`);
};
