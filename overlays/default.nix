# This file defines overlays

{ inputs, ... }:
{

  # pin-prefs: regenerates the macOS defaults modules from live prefs

  pin-prefs = import ./pin-prefs.nix;

  # check-pins: drift report for the hand-maintained version pins

  check-pins = import ./check-pins.nix;

  # warpd: nixpkgs ships it Linux-only; build it from source on darwin

  warpd = import ./warpd.nix;

  # bc-detect-secrets: skip the diff tests unidiff 1.0 turns down

  bc-detect-secrets = import ./bc-detect-secrets.nix;

  # python-ldap: skip one test darwin cannot fail the way it expects

  python-ldap = import ./python-ldap.nix;

  # jellyfin-ffmpeg: ffmpeg's VERSION file shadows libc++'s <version> on macOS

  jellyfin-ffmpeg = import ./jellyfin-ffmpeg.nix;

  # lit-tangle: regenerates this repo's .nix from the literate org...

  # lit-tangle: regenerates this repo's .nix from the literate org sources.

  lit-tangle = import ./lit-tangle.nix;

  # spotify-ctl: Web API now-playing and controls for the menu bar

  spotify-ctl = import ./spotify-ctl.nix;

  # nix-preflight: prices the next nix-update before it is run

  nix-preflight = import ./nix-preflight.nix;

  # tab-suspender: discards tabs by container on a schedule

  tab-suspender = import ./tab-suspender.nix;

  # browser-gt-extension: the browser half of the Emacs bridge

  browser-gt-extension = import ./browser-gt-extension.nix;

  # container-picker: asks which jar an external link opens in

  container-picker = import ./container-picker.nix;

  # posthog: nixpkgs marks it broken over a test dependency

  posthog = import ./posthog.nix;

  # mcp-v1: the consumers nixpkgs has not ported to mcp 2.x

  mcp-v1 = import ./mcp-v1.nix;

  # When applied, the unstable nixpkgs set (declared in the flake...

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  # unstable-packages = final: _prev: {
  #   unstable = import inputs.nixpkgs-unstable {
  #     system = final.system;
  #     config.allowUnfree = true;
  #   };
  # };

}
