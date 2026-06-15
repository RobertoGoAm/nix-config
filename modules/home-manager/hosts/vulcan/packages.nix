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

  home.packages = with pkgs; [
    # Development
    cabal-install
    claude-code
    chatgpt
    ghc
    gemini-cli
    glab
    haskell-language-server
    ngrok
    nixd
    nixfmt
    postman
    stack

    # Productivity
    anki-bin
    raycast

    # Social
    telegram-desktop

    # Media
    iina
    spotify

    # Tool
    ansible
    coreutils
    cyberduck
    nerd-fonts.jetbrains-mono
    procps
    qbittorrent
    ripgrep
    the-unarchiver
    vlc-bin

    # Work
    git-credential-manager
  ]
  ++ private.macPackages;
}
