<%*
// Process to Knowledge — moves current note from Inbox to a Knowledge subfolder
// and updates its frontmatter to permanent note status

const folders = ["Books", "Languages", "Maps of Content", "Personal Development", "Programming"];
const domain = await tp.system.suggester(folders, folders, false, "Choose domain:");

if (domain) {
  const targetFolder = `Knowledge/${domain}`;

  // Update frontmatter
  const file = tp.config.target_file;
  await app.fileManager.processFrontMatter(file, (fm) => {
    fm.type = "permanent";
    fm.status = "seedling";
    fm.lastUpdated = tp.date.now("YYYY-MM-DD");
  });

  // Move file
  const newPath = `${targetFolder}/${file.name}`;
  await app.fileManager.renameFile(file, newPath);

  new Notice(`Moved to ${targetFolder} ✓`);
} else {
  new Notice("Processing cancelled");
}
%>
