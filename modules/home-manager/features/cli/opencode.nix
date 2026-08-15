{ lib, pkgs, ... }:
{
  # opencode global config. Darwin-only: it registers the OpenPencil MCP server,
  # which reads and writes the document — open/save .fig, create and modify
  # nodes, components and instances, and bind design variables.
  #
  # Run over npx rather than a global `npm install -g @open-pencil/mcp`, so
  # nothing has to be installed outside nix for this file to work. The tradeoff
  # is that the version is not pinned; pin it here if that ever matters.
  #
  # force = true because opencode may rewrite this file at runtime; declare new
  # MCP servers here rather than via the opencode CLI.
  xdg.configFile."opencode/opencode.json" = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    force = true;
    text = builtins.toJSON {
      mcp.openpencil = {
        # -p names the package, then the binary: the package is
        # @open-pencil/mcp but the executable is openpencil-mcp, and plain
        # `npx -y @open-pencil/mcp` fails with "could not determine executable".
        command = [
          "npx"
          "-y"
          "-p"
          "@open-pencil/mcp"
          "openpencil-mcp"
        ];
        enabled = true;
        type = "local";
      };
    };
  };
}
