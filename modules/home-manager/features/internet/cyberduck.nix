{
  # Cyberduck comes from nixpkgs, so its bundle lives in ~/Applications/Home
  # Manager Apps and is rebuilt by home-manager's copyApps rsync. It also ships
  # Sparkle. If it ever updates itself in place the bundle picks up its own
  # Developer ID signature, macOS starts protecting it under App Management, and
  # every later rebuild fails with "Operation not permitted" — the same failure
  # VS Code caused. Holding the updater off keeps nix the only writer.
  #
  # Only the updater keys are pinned; the rest of the domain stays writable.
  targets.darwin.defaults."ch.sudo.cyberduck" = {
    SUAutomaticallyUpdate = false;
    SUEnableAutomaticChecks = false;
    SUSendProfileInfo = false;
  };
}
