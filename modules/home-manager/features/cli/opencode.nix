{ lib, pkgs, ... }:
{
  # opencode global config. Darwin-only: it registers the OpenPencil MCP
  # server, which the macOS app exposes.
  #
  # OpenPencil serves MCP over HTTP rather than shipping a stdio binary — the
  # old Pencil.app bundled one at Contents/Resources/..., but that app is gone
  # (homebrew deprecated it for failing Gatekeeper) and OpenPencil has no
  # equivalent inside its bundle. The editor must be running for this to
  # resolve: `op start`, or launch the app.
  #
  # force = true because opencode may rewrite this file at runtime; declare new
  # MCP servers here rather than via the opencode CLI.
  xdg.configFile."opencode/opencode.json" = lib.mkIf pkgs.stdenv.isDarwin {
    force = true;
    text = builtins.toJSON {
      mcp.openpencil = {
        url = "http://127.0.0.1:3100/mcp";
        enabled = true;
        type = "remote";
      };
    };
  };
}
