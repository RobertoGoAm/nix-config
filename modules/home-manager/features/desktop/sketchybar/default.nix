{ config, lib, pkgs, ... }:
let
  cfg = config.features.desktop.sketchybar;
in
{
  options.features.desktop.sketchybar.enable = lib.mkEnableOption ''
    SketchyBar. Off by default: it is on trial, and the point of the flag is
    that abandoning it is one line rather than an unpick. It runs alongside the
    macOS menu bar and SwiftBar rather than replacing them, so turning it off
    leaves no gap
  '';

  config = lib.mkIf (cfg.enable && pkgs.stdenv.isDarwin) {
    # icon_map.sh maps an app name to its glyph, and the font has to be
    # installed for the glyph to render rather than showing a tofu box.
    home.packages = [ pkgs.sketchybar-app-font ];

    programs.sketchybar = {
      enable = true;
      configType = "bash";
      config = {
        source = ./.;
        recursive = true;
      };
    };

    # The bar only redraws workspaces when aerospace says something changed, so
    # the items carry no update_freq of their own.
    home.file.".config/sketchybar/plugins".source = ./plugins;
  };
}
