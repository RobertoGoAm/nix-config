{
  nixpkgsSource,
  root ? ../../..,
  manifest ? import ./manifest.nix { inherit root; },
}:
let
  baseLib = import (nixpkgsSource + "/lib");
  spec =
    if builtins.isAttrs manifest then manifest else builtins.fromJSON (builtins.readFile manifest);
  lib = baseLib // {
    getExe =
      p: if builtins.isString p then p + "/bin/" + builtins.baseNameOf p else p.executable or p.pname;
    mkOrder = n: text: {
      order = n;
      inherit text;
    };
    mkBefore = text: {
      order = 500;
      inherit text;
    };
    mkAfter = text: {
      order = 1500;
      inherit text;
    };
    mkMerge = xs: xs;
  };
  package = name: rec {
    pname = name;
    executable = spec.executables.${name} or name;
    outPath = "/WORK_PACKAGES/${name}";
    __toString = self: self.outPath;
    overrideAttrs = _: package name;
  };
  writer =
    name: _: text:
    let
      source = builtins.toFile "${name}.work-helper" text;
    in
    {
      outPath = source;
      executable = "${source}/bin/${name}";
      __toString = self: self.outPath;
    };
  pkgs =
    (builtins.listToAttrs (
      map (name: {
        inherit name;
        value = package name;
      }) spec.names
    ))
    // {
      stdenv.hostPlatform.isDarwin = false;
      vimPlugins.promise-async = "promise-async";
      fetchFromGitHub = _: "";
      writeText = _: text: text;
      writers.writePython3Bin = writer;
      writeShellApplication = args: writer args.name { } args.text;
      writeShellScriptBin = name: text: writer name { } text;
    };
  epkgs = pkgs // {
    melpaBuild = args: package args.pname;
    treesit-grammars.with-grammars = _: package "treesit-grammars";
  };
  args = {
    inherit lib pkgs;
    user = "";
    config.features.productivity.keyboard.layout = "colemak";
    colemak = true;
  };
  load =
    path:
    let
      m = import (builtins.toPath path);
    in
    if builtins.isFunction m then m (builtins.intersectAttrs (builtins.functionArgs m) args) else m;
  flatten =
    value:
    if builtins.isList value then
      baseLib.concatMap flatten value
    else if builtins.isString value then
      [
        {
          order = 1000;
          text = value;
        }
      ]
    else
      [ value ];
  emacs = map (
    path:
    let
      m = load path;
      e = m.programs.emacs or { };
    in
    {
      inherit path;
      fragments = flatten (e.extraConfig or "");
      packages = map (p: p.pname) ((e.extraPackages or (_: [ ])) epkgs);
    }
  ) spec.emacs;
  merge =
    a: b:
    if builtins.isAttrs a && builtins.isAttrs b then
      baseLib.zipAttrsWith
        (_: values: builtins.foldl' merge (builtins.head values) (builtins.tail values))
        [
          a
          b
        ]
    else if builtins.isList a && builtins.isList b then
      a ++ b
    else if builtins.isString a && builtins.isString b then
      a + "\n" + b
    else
      b;
  nvim = builtins.foldl' merge { } (map load spec.nvim);
  clean =
    x:
    if builtins.isAttrs x && x ? outPath then
      x.outPath
    else if builtins.isAttrs x then
      builtins.mapAttrs (_: clean) x
    else if builtins.isList x then
      map clean x
    else
      x;
  helperContext = builtins.getContext (
    builtins.concatStringsSep "\n" (
      baseLib.concatMap (entry: map (fragment: fragment.text) entry.fragments) emacs
    )
  );
  helperPaths = builtins.filter (path: baseLib.hasSuffix ".work-helper" path) (
    builtins.attrNames helperContext
  );
  helpers = map (path: {
    inherit path;
    name = builtins.head (builtins.match "[a-z0-9]+-(.*)\\.work-helper" (builtins.baseNameOf path));
    text = builtins.readFile path;
  }) helperPaths;
in
{
  inherit emacs helpers;
  nvim = clean nvim;
}
