# home-manager hosts prometheus packages

{
  pkgs,
  ...
}:
let

  # Employer-revealing nixpkgs derivations live in the gitignored...

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
      chatgpt
      codex-acp
      dbeaver-bin
      ghc
      glab
      haskell-language-server
      ngrok
      nixd
      nixfmt
      postman
      stack

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
      notion-app
      raycast

      # Media

      ffmpeg
      iina

      # The Jellyfin desktop client, not the browser

      # The courses on vulcan are half MPEG-TS -- 122 of The Joy of React's 222 files
      # -- and no browser plays that container, so every one of those episodes makes
      # vulcan transcode with ffmpeg while you watch. This client is mpv underneath
      # and plays them as they are, which turns the server's job back into serving
      # bytes. The browser is still the right answer from an office, where installing
      # nothing is the point.

      jellyfin-media-player
      spotify

      # Tool

      coreutils
      cyberduck
      graphviz
      julia-mono
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
