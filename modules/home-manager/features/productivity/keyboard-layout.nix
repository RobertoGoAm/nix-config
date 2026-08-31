{ lib, ... }:
{
  # Which base letter layout the software remappers should produce.
  #
  # Declared in its own file because the surfaces that read it are imported
  # independently by different hosts — karabiner.nix and keyboard/ come in
  # directly on the macs, keyd/ and kanata/ through features/productivity on
  # Linux. Importing this from each of them keeps the option defined wherever it
  # is consulted; the module system deduplicates by path, so the repeated import
  # costs nothing.
  #
  # This governs the SOFTWARE layers only — Karabiner on macOS, keyd on Linux.
  # The Bridge75 does Colemak in its own firmware and is deliberately excluded
  # from both remappers, so flipping this does not change what that keyboard
  # sends. That only matters to someone who owns one; on any other board this
  # option is the whole story.
  options.features.productivity.keyboard.layout = lib.mkOption {
    type = lib.types.enum [
      "colemak"
      "qwerty"
    ];
    default = "colemak";
    description = ''
      Base letter layout for the software remappers. "colemak" applies the
      QWERTY-to-Colemak letter mapping in Karabiner and keyd; "qwerty" leaves
      letters alone.

      The nav and symbol layers are unaffected either way: both are keyed to
      physical positions rather than letters, so Caps+hjkl stays on the same
      four keys under both layouts. Only the base letter remap is toggled.
    '';
  };
}
