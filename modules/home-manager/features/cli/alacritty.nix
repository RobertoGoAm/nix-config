{
  lib,
  pkgs,
  ...
}:
{
  programs.alacritty = {
    enable = true;

    settings = {
      colors = {
        bright = {
          black = "#444b6a";
          blue = "#7da6ff";
          cyan = "#0db9d7";
          green = "#b9f27c";
          magenta = "#bb9af7";
          red = "#ff7a93";
          white = "#acb0d0";
          yellow = "#ff9e64";
        };

        normal = {
          black = "#32344a";
          blue = "#7aa2f7";
          cyan = "#449dab";
          green = "#9ece6a";
          magenta = "#ad8ee6";
          red = "#f7768e";
          yellow = "#e0af68";
          white = "#9699a8";
        };

        primary = {
          background = "#24283b";
          foreground = "#a9b1d6";
        };
      };

      font = {
        normal = {
          family = "JetBrainsMono Nerd Font";
        };

        size = lib.mkMerge [
          (lib.mkIf pkgs.stdenv.hostPlatform.isLinux 10)
          (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin 12)
        ];
      };

      window = {
        padding = {
          x = 5;
          y = 5;
        };

        dynamic_padding = true;
      };
    };
  };
}
