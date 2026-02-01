{
  config,
  inputs,
  lib,
  outputs,
  pkgs,
  system,
  user,

  ...
}:
{
  nixpkgs = {
    overlays = [
      outputs.overlays.apple-silicon
    ];

    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };

  home = {
    homeDirectory = "/Users/${user}";
    stateVersion = "24.11";
    username = user;
  };

  home.file.".claude/settings.json".text = builtins.toJSON {
    hooks = {
      Notification = [
        {
          matcher = "*";
          hooks = [
            {
              type = "command";
              command = "curl -d \"Claude needs your attention\" ntfy.sh/$NTFY_TOPIC_ID";
            }
          ];
        }
      ];
      Stop = [
        {
          matcher = "*";
          hooks = [
            {
              type = "command";
              command = "curl -d \"Claude is done!\" ntfy.sh/$NTFY_TOPIC_ID";
            }
          ];
        }
      ];
    };
  };

  programs.home-manager = {
    enable = true;
  };

  imports = [
    inputs.nixvim.homeModules.nixvim
    inputs.nix-doom-emacs-unstraightened.homeModule
    ../../modules/iterm2.nix
    ./packages.nix
    ../../features/cli
    ../../features/cli/iterm2.nix
    ../../features/development
    ../../features/development/emacs-mac.nix
    ../../features/internet/chromium.nix
    ../../features/internet/firefox.nix
    ../../features/media/yt-dlp.nix
  ];
}
