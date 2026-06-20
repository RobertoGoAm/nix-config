let
  privatePath = "/Users/robertogoam/.config/nix-secrets/work-extras.nix";
  private =
    if builtins.pathExists privatePath then
      import privatePath { }
    else
      {
        macCasks = [ ];
      };
in
{
  homebrew = {
    enable = true;
    casks = [
      # Development
      "dbeaver-community"
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
