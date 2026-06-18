{
  pkgs,
  ...
}:
let
  privatePath = "/Users/robertogoam/.config/nix-secrets/work-extras.nix";
  private =
    if builtins.pathExists privatePath then
      import privatePath { inherit pkgs; }
    else
      {
        linuxPackages = [ ];
      };
in
{
  # Aligned with the prometheus base for everything that builds on linux; the
  # darwin-only apps (raycast, iina, cyberduck, the-unarchiver, vlc-bin, chatgpt)
  # are dropped, and the GNOME/X11/linux-native bits below are perseus-specific.
  home.packages =
    (with pkgs; [
      # Desktop (linux)
      gnomeExtensions.forge
      gnomeExtensions.space-bar

      # Development
      cabal-install
      claude-code
      codex-acp
      gcc
      gemini-cli
      ghc
      glab
      gnumake
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

      # Internet (linux)
      google-chrome

      # Media
      ffmpeg
      spotify
      vlc

      # Productivity
      anki-bin
      gnome-calendar
      obsidian
      remnote

      # Security
      bitwarden-desktop
      libsecret

      # Social
      discord
      telegram-desktop

      # Tool
      coreutils
      fasd
      gnutar
      graphviz
      mdfried
      mozjpeg
      nanum
      nerd-fonts.jetbrains-mono
      oxipng
      poppler-utils
      procps
      qbittorrent
      syncthing
      tree
      xclip

      # Work
      git-credential-manager

      # Machine-local extras (see ~/.config/nix-secrets/work-extras.nix)
    ])
    ++ private.linuxPackages;
}
