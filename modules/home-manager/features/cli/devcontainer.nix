{ lib, pkgs, ... }:
let
  # Run a command where the project says it belongs: inside the devcontainer when
  # there is one and we are outside it, on the host otherwise.
  #
  # The point is native modules. pnpm install on macOS builds darwin/arm64
  # binaries into a tree the container then mounts over with its own volume, so
  # installing from the host is at best wasted and at worst produces a lockfile
  # resolved against the wrong platform. CI builds in Linux; the container is the
  # copy that matches it.
  dcRun = pkgs.writeShellScriptBin "dc-run" ''
    set -euo pipefail

    # Escape hatch for the times the wrapper is the problem.
    if [ -n "''${DC_OFF:-}" ]; then exec "$@"; fi

    # Already inside a container? Then the command is already in the right place.
    # /.dockerenv is the reliable signal -- it exists for `docker exec` too, where
    # VS Code's REMOTE_CONTAINERS never gets set. The env vars catch Codespaces
    # and a devcontainer feature that exports one.
    if [ -f /.dockerenv ] || [ -f /run/.containerenv ] \
       || [ -n "''${REMOTE_CONTAINERS:-}" ] || [ -n "''${CODESPACES:-}" ] \
       || [ -n "''${DEVCONTAINER:-}" ]; then
      exec "$@"
    fi

    # Walk up for a devcontainer definition. No definition -> nothing to do.
    root=""
    dir="$PWD"
    while [ "$dir" != "/" ]; do
      if [ -f "$dir/.devcontainer/devcontainer.json" ] || [ -f "$dir/.devcontainer.json" ]; then
        root="$dir"; break
      fi
      dir="$(dirname "$dir")"
    done
    [ -n "$root" ] || exec "$@"

    command -v docker >/dev/null 2>&1 || {
      echo "dc: $1 wants the devcontainer but docker is not on PATH; running on the host" >&2
      exec "$@"
    }
    docker info >/dev/null 2>&1 || {
      echo "dc: $1 wants the devcontainer but the docker daemon is not running; running on the host" >&2
      exec "$@"
    }

    # The devcontainer CLI labels what it starts with the folder it started from,
    # which is a real project -> container mapping rather than a guess at names.
    container="$(docker ps --filter "label=devcontainer.local_folder=$root" --format '{{.Names}}' | head -1)"

    if [ -z "$container" ]; then
      command -v devcontainer >/dev/null 2>&1 || {
        echo "dc: no container for $root and no devcontainer CLI; running on the host" >&2
        exec "$@"
      }
      echo "dc: starting the devcontainer for $(basename "$root")..." >&2
      devcontainer up --workspace-folder "$root" >/dev/null || {
        echo "dc: devcontainer up failed; running on the host" >&2
        exec "$@"
      }
      container="$(docker ps --filter "label=devcontainer.local_folder=$root" --format '{{.Names}}' | head -1)"
      [ -n "$container" ] || exec "$@"
    fi

    # Translate the current directory. The workspace is a bind mount, so the same
    # relative path exists on both sides -- but the destination is whatever the
    # devcontainer chose (/app here, /workspaces/<name> by default), so it has to
    # be read rather than assumed.
    dest="$(docker inspect "$container" \
      --format '{{range .Mounts}}{{if eq .Source "'"$root"'"}}{{.Destination}}{{end}}{{end}}' 2>/dev/null)"
    [ -n "$dest" ] || dest=/workspaces/"$(basename "$root")"
    rel="''${PWD#"$root"}"
    workdir="$dest$rel"

    tty_flag=""
    [ -t 0 ] && tty_flag="-it"

    echo "dc: $1 -> $container:$workdir" >&2
    # shellcheck disable=SC2086
    exec docker exec $tty_flag -w "$workdir" "$container" "$@"
  '';
in
{
  home.packages = [ dcRun ];

  # Functions, not aliases: aliases do not take arguments the way this needs, and
  # a function is skipped entirely by anything that execs the binary directly --
  # so MCP servers, opencode and emacs subprocesses keep the real pnpm.
  #
  # Only the package managers are wrapped. node and npx are deliberately left
  # alone: npx is how the OpenPencil MCP server starts, and redirecting that into
  # a project's container because of the current directory would be baffling.
  programs.zsh.initContent = lib.mkAfter ''
    pnpm() { dc-run pnpm "$@"; }
    npm()  { dc-run npm  "$@"; }
    yarn() { dc-run yarn "$@"; }

    # Arbitrary commands in the project's container: dc pnpm build, dc sh, dc ls.
    dc() { dc-run "$@"; }
  '';
}
