# Which tiling window manager runs

# One option rather than two enable flags, because the two cannot both run: they
# would each move the same windows, and the result is windows that jump as one
# manager undoes what the other just did. An enum makes that impossible to
# misconfigure -- picking one turns the other off by construction.

# Declared in its own file for the reason =keyboard-layout.nix= is: the readers
# are in different trees. The OmniWM half is home-manager
# (=programs.omniwm=, upstream), the aerospace half is a nix-darwin module that
# reaches into =config.home-manager.users.<user>= to read it -- the same route
# that module already takes to find the keyboard layout.

{ lib, ... }:
{
  options.features.desktop.windowManager = lib.mkOption {
    type = lib.types.enum [
      "aerospace"
      "omniwm"
    ];
    default = "aerospace";
    description = ''
      The tiling window manager to run on this host.

      "aerospace" is the long-standing one: a workspace model, no SIP changes,
      configured entirely from the TOML in modules/macos/services/aerospace.

      "omniwm" is the newer one -- Niri-style scrolling columns and Hyprland
      Dwindle BSP, signed and notarized, and also no SIP changes. It wants
      Apple Silicon, macOS 26 or later, and Accessibility plus Input
      Monitoring granted by hand on first launch.

      Whichever is not chosen is not installed and has no launchd agent, so
      switching is this one word and a rebuild.
    '';
  };
}
