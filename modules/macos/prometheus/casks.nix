let
  privatePath = "/Users/robertogoam/.config/nix-secrets/work-extras.nix";
  private =
    if builtins.pathExists privatePath then
      import privatePath { }
    else
      {
        macCasks = [ ];
      };
  # `brew bundle --upgrade` skips any cask that declares auto_updates upstream,
  # which is most of this list, so rebuilds would install-then-never-touch them.
  # Marking every entry greedy makes rebuilds upgrade them too; it is a no-op for
  # casks that don't self-update.
  greedy = map (name: {
    inherit name;
    greedy = true;
  });
in
{
  homebrew = {
    enable = true;
    casks = greedy [
      # Development
      "cate"
      "codex"
      "imageoptim"
      "orbstack"

      # Internet
      "google-chrome"
      # The standalone client: runs its own tailscaled and ships a CLI at
      # /usr/local/bin/tailscale that matches it. Replaced the App Store
      # build, which was stuck at 1.98.9 against a 1.102.x CLI.
      "tailscale-app"

      # Media
      "macmediakeyforwarder"

      # Office
      "pdf-expert"

      # Productivity
      "claude"
      "kimi"
      "pencil"
      "hammerspoon" # drives the Alacritty quake terminal (Cmd+`); needs an Accessibility grant

      # Security
      "bitwarden"
      "blockblock"
      "gpg-suite"
      "oversight"
      "ransomwhere"

      # Social
      # Telegram for macOS, the AppKit client. nixpkgs has no package for it
      # (telegram-macos/telegram-mac are both absent) and only ships the Qt
      # telegram-desktop, which is the lighter-on-resources loser of the two and
      # whose updates make a rebuild noticeably slower. Revisit only if the
      # AppKit client ever lands in nixpkgs.
      "telegram"

      # Tool
      "calibre" # nixpkgs marks calibre broken on darwin
      "filen" # nixpkgs filen-desktop is Electron, Linux-only
      "multipass"
      "omnidisksweeper"
      "qmk-toolbox"
      "via"
      "vorssaint" # cask for vorssaint-utils: keep-awake, volume mixer, system monitor

      # Machine-local extras (see ~/.config/nix-secrets/work-extras.nix)
    ]
    ++ private.macCasks;

    # These app IDs are from using the mas CLI app
    # mas = mac app store
    # https://github.com/mas-cli/mas
    #
    # $ nix shell nixpkgs#mas
    # $ mas search <app name>
    #
    # App Store apps, by ID from `mas list`. Everything here is App Store only
    # — Apple's own apps and Safari extensions have no cask or nixpkgs
    # equivalent, and the Raycast/TaskForge companions ship the same way.
    #
    masApps = {
      "Hush" = 1544743900;
      "Keynote" = 409183694;
      "Numbers" = 409203825;
      "Pages" = 409201541;
      "Raycast Companion" = 6738274497;
      "TaskForge" = 6744716215;
      "The Camelizer" = 1532579087;
      "uBlock Origin Lite" = 6745342698;
    };
  };
}
