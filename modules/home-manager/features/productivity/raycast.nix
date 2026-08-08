{ config, ... }:
{
  # Raycast used to start from a Homebrew-managed login item pointing at
  # /Applications. The cask is gone and the nix copy lives under Home Manager
  # Apps, so that entry is dead — and Homebrew could not remove it on uninstall
  # because it lacked Automation access to System Events.
  #
  # A launchd agent replaces it: declarative, and it follows the bundle wherever
  # home-manager puts it instead of hardcoding a path that moves again.
  launchd.agents.raycast = {
    enable = true;
    config = {
      ProgramArguments = [
        "${config.home.homeDirectory}/Applications/Home Manager Apps/Raycast.app/Contents/MacOS/Raycast"
      ];
      RunAtLoad = true;
      ProcessType = "Interactive";
      KeepAlive = false;
    };
  };
}
