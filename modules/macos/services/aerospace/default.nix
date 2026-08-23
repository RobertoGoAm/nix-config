{ config, lib, pkgs, user, ... }:
let
  # Read through the home-manager user: the option is declared in the HM tree
  # (features/productivity/keyboard-layout.nix) and this is a nix-darwin module,
  # so there is no shared namespace to reach it from directly.
  colemak = config.home-manager.users.${user}.features.productivity.keyboard.layout == "colemak";

  # aerospace defines no directional bindings of its own, so unlike vim or warpd
  # the QWERTY case has to be spelled out rather than simply omitted. Left stays
  # h under both layouts, since Colemak leaves h in place.
  nav =
    if colemak then
      { down = "n"; up = "e"; right = "i"; }
    else
      { down = "j"; up = "k"; right = "l"; };

  base = pkgs.lib.importTOML ./config.toml;

  # The TOML keeps its Colemak bindings as the committed default; only the eight
  # directional entries are rewritten, and only when the layout says so.
  directional = {
    "alt-h" = "focus left";
    "alt-${nav.down}" = "focus down";
    "alt-${nav.up}" = "focus up";
    "alt-${nav.right}" = "focus right";
    "alt-shift-h" = "move left";
    "alt-shift-${nav.down}" = "move down";
    "alt-shift-${nav.up}" = "move up";
    "alt-shift-${nav.right}" = "move right";
  };

  # Drop the Colemak directional keys before merging, or a QWERTY build would
  # keep alt-n/e/i alongside the new alt-j/k/l and bind eight keys instead of four.
  stripped = lib.filterAttrs (
    k: _: !(builtins.elem k [ "alt-e" "alt-i" "alt-n" "alt-shift-e" "alt-shift-i" "alt-shift-n" ])
  ) base.mode.main.binding;
in
{
  services.aerospace = {
    enable = true;
    settings = base // {
      mode = base.mode // {
        main = base.mode.main // { binding = stripped // directional; };
      };
    };
  };
}
