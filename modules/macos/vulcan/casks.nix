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
      "dbeaver-community"
      "docker"
      "imageoptim"
      "orbstack"

      # Internet
      "google-chrome"

      # Media
      "macmediakeyforwarder"

      # Office
      "pdf-expert"

      # Productivity
      "alt-tab" # cmd-tab replacement that also restores minimized/hidden windows
      "claude"
      "hammerspoon" # drives the Alacritty quake terminal (Cmd+`); needs an Accessibility grant
      "notion"
      "remnote"

      # Security
      "bitwarden"
      "blockblock"
      "gpg-suite"
      "oversight"
      "ransomwhere"

      # Tool
      "calibre"
      "filen"
      "multipass"
      "omnidisksweeper"
      "qmk-toolbox"
      "utm" # local Linux VMs (Apple Virtualization / QEMU); hosts the bridged Omada controller VM
      "via"

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
    masApps = { };
  };
}
