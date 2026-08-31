# Imports e-reader highlights into the Obsidian vault, one note per...

# Imports e-reader highlights into the Obsidian vault, one note per book.

# The Xteink X4 (CrossInk firmware) appends to a Kindle-style My Clippings.txt.
# Kindle's own export uses a different metadata line, so both are parsed and
# anything unrecognised is reported rather than dropped -- a highlight silently
# missing from a note is worse than a loud parse failure.

# Idempotent: each highlight carries a short content hash, so re-running after
# every sync only appends what is new, and prose written around the quotes
# survives.

{
  lib,
  writeShellApplication,
  python3,
}:
writeShellApplication {
  name = "clippings-import";

  runtimeInputs = [ python3 ];

  # Every argument through: the script takes the clippings path plus

  # --vault/--folder/--dry-run.

  text = ''
    exec python3 "${./clippings-import.py}" "$@"
  '';

  meta = {
    description = "Import e-reader clippings into an Obsidian vault";
    mainProgram = "clippings-import";
    platforms = lib.platforms.all;
  };
}
