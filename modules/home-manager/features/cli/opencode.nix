{ lib, pkgs, ... }:
{
  # opencode global config. Currently only registers the Pencil MCP server,
  # whose binary ships inside the macOS Pencil.app bundle (arm64), so this is
  # Darwin-only. force = true because opencode may rewrite this file at runtime;
  # declare new MCP servers here rather than via the opencode CLI.
  xdg.configFile."opencode/opencode.json" = lib.mkIf pkgs.stdenv.isDarwin {
    force = true;
    text = builtins.toJSON {
      mcp.pencil = {
        command = [
          "/Applications/Pencil.app/Contents/Resources/app.asar.unpacked/out/mcp-server-darwin-arm64"
          "--app"
          "desktop"
          "--agent"
          "openCodeCLI"
        ];
        enabled = true;
        type = "local";
      };
    };
  };
}
