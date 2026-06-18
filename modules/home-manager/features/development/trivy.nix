{
  # Local Trivy config (devops guide, Phase 0). Keeps `trivy fs .` fast during
  # the dev loop by flagging only HIGH/CRITICAL; CI can scan wider.
  xdg.configFile."trivy/trivy.yaml".text = ''
    severity: HIGH,CRITICAL
    ignore-unfixed: false
    timeout: 5m
    db:
      no-progress: true
  '';
}
