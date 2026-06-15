{ ... }:
{
  programs.k9s = {
    enable = true;

    # config.yaml is intentionally left for k9s to own — it rewrites
    # currentContext/currentCluster at runtime, so a read-only symlink there
    # would fight the app. Only the static aliases are declared here; add UI
    # overrides under programs.k9s.settings.k9s if ever needed.
    aliases = {
      dp = "deployments";
      sec = "v1/secrets";
      jo = "jobs";
      cr = "clusterroles";
      crb = "clusterrolebindings";
      ro = "roles";
      rb = "rolebindings";
      np = "networkpolicies";
    };
  };
}
