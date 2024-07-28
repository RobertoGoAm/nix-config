{pkgs, ...}: {
  imports = [
    ./starship

    ./bash.nix
    ./direnv.nix
    ./gh.nix
    ./git.nix
    ./pfetch.nix
    ./fzf.nix
    ./jira.nix
  ];
}
