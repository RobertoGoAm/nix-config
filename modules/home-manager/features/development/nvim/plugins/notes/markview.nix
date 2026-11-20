# development nvim plugins notes markview

# Markdown is drawn rendered the way Obsidian's live preview draws it: the
# whole buffer stays rendered while typing too, and only the line under the
# cursor shows its markdown as written, so a heading being edited shows its
# =#= and goes back to a heading when the cursor leaves it. Markview's own
# default renders in normal mode only and shows the whole buffer raw in insert
# mode.

{
  plugins.markview = {
    enable = true;

    settings.preview = {
      modes = [
        "n"
        "no"
        "c"
        "i"
      ];
      hybrid_modes = [
        "n"
        "i"
      ];
      linewise_hybrid_mode = true;
    };
  };
}
