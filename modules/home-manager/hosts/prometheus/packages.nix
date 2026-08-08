{
  pkgs,
  ...
}:
let
  # Employer-revealing nixpkgs derivations live in the gitignored private file
  # (work-extras.nix) so the public repo doesn't reveal corporate tooling.
  # Read only under --impure.
  privatePath = "/Users/robertogoam/.config/nix-secrets/work-extras.nix";
  private =
    if builtins.pathExists privatePath then
      import privatePath { inherit pkgs; }
    else
      { macPackages = [ ]; };
in
{

  home.packages =
    with pkgs;
    [
      # Development
      cabal-install
      claude-code
      chatgpt
      codex-acp
      ghc
      gemini-cli
      glab
      haskell-language-server
      ngrok
      nixd
      nixfmt
      postman
      stack
      uv

      # DevOps
      actionlint
      age
      ansible
      argocd
      bitwarden-cli
      checkov
      cilium-cli
      cosign
      devcontainer
      docker
      docker-buildx
      docker-compose
      dive
      gitleaks
      grype
      hadolint
      hcloud
      httpie
      jq
      k6
      kind
      kubeconform
      kube-linter
      kubectl
      kubectx
      kubernetes-helm
      kustomize
      pre-commit
      semgrep
      sops
      step-cli
      stern
      syft
      terraform
      testssl
      tflint
      trivy
      vault
      velero
      yamllint
      yq-go
      yubikey-manager

      # Productivity
      anki-bin
      raycast

      # Social
      telegram-desktop

      # Media
      ffmpeg
      iina
      spotify

      # Tool
      coreutils
      cyberduck
      graphviz
      mdfried
      mozjpeg
      nerd-fonts.jetbrains-mono
      oxipng
      poppler-utils
      procps
      qbittorrent
      syncthing
      the-unarchiver
      tree
      vlc-bin
      yubikey-manager

      # Work
      git-credential-manager
    ]
    ++ private.macPackages;
}
