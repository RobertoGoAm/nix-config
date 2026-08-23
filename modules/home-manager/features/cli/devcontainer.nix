{ lib, pkgs, ... }:
let
  # Add --ignore-scripts to a host install when the project has a devcontainer.
  #
  # In that setup the container owns the real install: its node_modules is a
  # named volume, built for Linux, matching CI. The host copy exists only so the
  # editor's TypeScript server can resolve types, and for that the packages need
  # to be present, not built -- so running lifecycle scripts on the host is at
  # best wasted time and at worst a native module that fails to compile on
  # darwin and takes the whole install down with it.
  #
  # The flag is only ever right in that one case, which is exactly the kind of
  # thing that gets forgotten. This adds it there and nowhere else, so the
  # command you type is the same everywhere.
  pmRun = pkgs.writeShellScriptBin "pm-run" ''
    set -euo pipefail

    pm="$1"; shift

    if [ -n "''${PM_NO_GUARD:-}" ]; then exec "$pm" "$@"; fi

    # Only the install subcommands. Anything else -- run, build, test, exec --
    # has no business being rewritten.
    sub="''${1:-}"
    case "$sub" in
      i|install) ;;
      *) exec "$pm" "$@" ;;
    esac

    # Already asked for it explicitly? Leave the command alone.
    for a in "$@"; do
      case "$a" in
        --ignore-scripts|--no-optional) exec "$pm" "$@" ;;
      esac
    done

    # Inside a container the install IS the real one: it must run its scripts.
    # /.dockerenv is the dependable signal -- it is there for a plain `docker
    # exec` shell, where VS Code's REMOTE_CONTAINERS is never set.
    if [ -f /.dockerenv ] || [ -f /run/.containerenv ] \
       || [ -n "''${REMOTE_CONTAINERS:-}" ] || [ -n "''${CODESPACES:-}" ] \
       || [ -n "''${DEVCONTAINER:-}" ]; then
      exec "$pm" "$@"
    fi

    # No devcontainer means the host copy is the only copy, and it has to be a
    # real install.
    dir="$PWD"
    root=""
    while [ "$dir" != "/" ]; do
      if [ -f "$dir/.devcontainer/devcontainer.json" ] || [ -f "$dir/.devcontainer.json" ]; then
        root="$dir"; break
      fi
      dir="$(dirname "$dir")"
    done
    [ -n "$root" ] || exec "$pm" "$@"

    echo "pm: $(basename "$root") has a devcontainer -- host install is for types only, adding --ignore-scripts" >&2
    exec "$pm" "$@" --ignore-scripts
  '';

  # Unrelated to the guard above, and never automatic: run something in the
  # project's devcontainer on purpose. Kept because the container is where
  # builds and tests belong even though installs are the only thing rewritten.
  dcRun = pkgs.writeShellScriptBin "dc" ''
    set -euo pipefail

    dir="$PWD"; root=""
    while [ "$dir" != "/" ]; do
      if [ -f "$dir/.devcontainer/devcontainer.json" ] || [ -f "$dir/.devcontainer.json" ]; then
        root="$dir"; break
      fi
      dir="$(dirname "$dir")"
    done
    [ -n "$root" ] || { echo "dc: no devcontainer above $PWD" >&2; exit 1; }

    container="$(docker ps --filter "label=devcontainer.local_folder=$root" --format '{{.Names}}' | head -1)"
    [ -n "$container" ] || { echo "dc: no running container for $root (devcontainer up --workspace-folder \"$root\")" >&2; exit 1; }

    # The mount destination varies -- /app here, /workspaces/<name> by default --
    # so it is read rather than assumed, and the relative path appended.
    dest="$(docker inspect "$container" \
      --format '{{range .Mounts}}{{if eq .Source "'"$root"'"}}{{.Destination}}{{end}}{{end}}' 2>/dev/null)"
    [ -n "$dest" ] || dest=/workspaces/"$(basename "$root")"
    rel="''${PWD#"$root"}"

    tty_flag=""
    [ -t 0 ] && tty_flag="-it"
    # shellcheck disable=SC2086
    exec docker exec $tty_flag -w "$dest$rel" "$container" "$@"
  '';
in
{
  home.packages = [ pmRun dcRun ];

  # Functions rather than aliases or PATH shims: anything that execs a binary
  # directly is unaffected, so MCP servers, opencode and emacs subprocesses keep
  # the real pnpm.
  programs.zsh.initContent = lib.mkAfter ''
    pnpm() { pm-run pnpm "$@"; }
    npm()  { pm-run npm  "$@"; }
  '';
}
