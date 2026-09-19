# cli nix-preflight

{
  config,
  lib,
  pkgs,
  ...
}:
let
  report = "${config.home.homeDirectory}/.cache/nix-preflight/report.json";
in
lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  home.packages = [ pkgs.nix-preflight ];

  # Six hours, in the background, because the answer ages slowly

  # The inputs this watches are channels and GitHub branches: nixpkgs moves a few
  # times a day, the rest less often. A tighter interval would re-evaluate a whole
  # darwin system to learn nothing, and the run is minutes of CPU, not seconds --
  # hence ~ProcessType = "Background"~ and ~LowPriorityIO~, so it never competes
  # with whatever is being typed into.

  # ~RunAtLoad~ covers the case the interval cannot: a laptop that was asleep
  # through its slot still has a fresh answer shortly after it wakes into a login.

  # The host is not passed in. The script defaults to this machine's short
  # hostname, which is exactly how the hosts are named in the flake, so the same
  # agent is correct on every mac without plumbing a name through.

  launchd.agents.nix-preflight = {
    enable = true;
    config = {
      ProgramArguments = [
        (lib.getExe pkgs.nix-preflight)
        "--repo"
        "${config.home.homeDirectory}/nix-config"
        "--out"
        report
      ];
      RunAtLoad = true;
      StartInterval = 21600;
      ProcessType = "Background";
      LowPriorityIO = true;
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/nix-preflight.out.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/nix-preflight.err.log";
    };
  };
}
