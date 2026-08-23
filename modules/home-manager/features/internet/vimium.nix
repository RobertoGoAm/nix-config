{ config, lib, ... }:
let
  colemak = config.features.productivity.keyboard.layout == "colemak";
in
{
  imports = [ ../productivity/keyboard-layout.nix ];

  # Colemak-only. The file's keyMappings block rebinds n/e/i to scrolling and
  # pushes find onto j/J; under layout = "qwerty" that would cost the QWERTY
  # user their find and insert keys and buy nothing, and Vimium's stock
  # bindings are already the vim ones.
  home.file.".config/vimium-config.json" = lib.mkIf colemak {
    source = ./vimium-config.json;
  };
}
