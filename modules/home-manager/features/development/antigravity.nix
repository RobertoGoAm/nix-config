{ config, lib, pkgs, ... }:
let
  cfg = config.features.development.antigravity;
  binDir = "${cfg.appPath}/Contents/Resources/app/bin";
  ideCli =
    if builtins.pathExists "${binDir}/antigravity-ide" then
      "${binDir}/antigravity-ide"
    else if builtins.pathExists "${binDir}/antigravity" then
      "${binDir}/antigravity"
    else
      "${binDir}/antigravity-ide";
in
{
  options.features.development.antigravity = {
    appPath = lib.mkOption {
      type = lib.types.str;
      default = "/Applications/Antigravity IDE.app";
      description = "Path to Antigravity IDE.app (must contain Contents/Resources/app/bin/antigravity-ide).";
    };
  };

  config = {
    home.packages = [
      pkgs.antigravity

      # Gemini /ide install looks for agy-ide; the IDE ships antigravity-ide.
      (pkgs.writeShellScriptBin "agy-ide" ''
        exec "${ideCli}" "$@"
      '')
      (pkgs.writeShellScriptBin "agy" ''
        exec "${ideCli}" "$@"
      '')
    ];

    programs.zsh.initContent = lib.mkAfter ''
      export ANTIGRAVITY_CLI_ALIAS=agy-ide
    '';

    # Antigravity is a VS Code fork; share the HM-managed VS Code extensions.
    home.file.".antigravity-ide/extensions" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.vscode/extensions";
      force = true;
    };
  };
}
