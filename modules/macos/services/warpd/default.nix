{ pkgs, ... }:
{
  # warpd CLI available system-wide (the overlay builds it from source on darwin).
  environment.systemPackages = [ pkgs.warpd ];

  # Run the warpd daemon as a per-user launchd agent so its global activation
  # hotkeys are live (config: ~/.config/warpd/config, deployed by the
  # features/desktop/warpd home-manager module).
  #
  # warpd needs Accessibility permission: System Settings → Privacy & Security →
  # Accessibility. Because the binary lives in the nix store, its path changes
  # whenever the warpd derivation does — you may need to re-grant after such a
  # rebuild.
  launchd.user.agents.warpd = {
    command = "${pkgs.warpd}/bin/warpd --foreground";
    serviceConfig = {
      RunAtLoad = true;
      KeepAlive = true;
    };
  };
}
