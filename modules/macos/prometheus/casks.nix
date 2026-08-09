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
      # Tap-qualified deliberately: homebrew-cask has an unrelated project
      # under the same token (net.dannote.open-pencil). This is the
      # AI-native vector editor that the op CLI drives.
      "zseven-w/openpencil/openpencil"
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
    # masApps stays empty: mas cannot drive these installs on this machine.
    #
    # `mas install` exits non-zero on "Already installed", so brew bundle counts
    # every app already present as a failure — which is all of them — and the
    # whole rebuild reports failure. Apple's bundled iWork IDs are worse: mas
    # cannot resolve 409183694 / 409201541 / 409203825 at all ("No apps found in
    # the App Store for ADAM ID"), so even a clean machine could not install
    # them. Declaring them bought a broken rebuild and nothing else.
    #
    # For ad-hoc lookups: nix shell nixpkgs#mas, then `mas list` / `mas search`.
    masApps = { };
  };
}
