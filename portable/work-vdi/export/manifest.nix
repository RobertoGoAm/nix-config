# Source selection shared by manual exports and rebuild-time generation.
{ root }:
let
  base = root + "/modules/home-manager/features/development";
  children = path: builtins.attrNames (builtins.readDir path);
  nixFiles = path: builtins.filter (name: builtins.match ".*\\.nix" name != null) (children path);
  emacsFolders = [
    "code"
    "files"
    "lsp"
    "devops"
    "data"
    "ai"
    "ui"
    "version-control"
  ];
  emacs =
    map (name: base + "/emacs/" + name) [
      "options.nix"
      "keybinds.nix"
      "colorscheme.nix"
      "plugins/vim/default.nix"
    ]
    ++ builtins.concatLists (
      map (
        folder:
        map (name: base + "/emacs/plugins/" + folder + "/" + name) (
          builtins.filter (
            name:
            name != "default.nix"
            || builtins.elem folder [
              "devops"
              "data"
              "ai"
            ]
          ) (nixFiles (base + "/emacs/plugins/" + folder))
        )
      ) emacsFolders
    )
    ++ map (name: base + "/emacs/plugins/" + name) [
      "completion/corfu.nix"
      "completion/icons.nix"
      "keybinds/default.nix"
      "notes/markview.nix"
      "apps/browser.nix"
    ];
  walk =
    path:
    builtins.concatLists (
      map (
        name:
        let
          item = path + "/" + name;
          kind = (builtins.readDir path).${name};
        in
        if kind == "directory" then
          walk item
        else if builtins.match ".*\\.nix" name != null then
          [ item ]
        else
          [ ]
      ) (children path)
    );
  nvim =
    map (name: base + "/nvim/" + name) [
      "options.nix"
      "keybinds.nix"
      "colorscheme.nix"
    ]
    ++ builtins.filter (
      path:
      let
        name = builtins.baseNameOf path;
        parent = builtins.baseNameOf (builtins.dirOf path);
      in
      name != "obsidian.nix"
      && (
        name != "default.nix"
        || builtins.elem parent [
          "keybinds"
          "vim"
        ]
      )
    ) (walk (base + "/nvim/plugins"));
  text = builtins.concatStringsSep "\n" (map builtins.readFile (emacs ++ nvim));
  names = builtins.filter (
    part: builtins.isString part && builtins.match "[A-Za-z][A-Za-z0-9_-]*" part != null
  ) (builtins.split "[^A-Za-z0-9_-]+" text);
in
{
  inherit emacs nvim names;
  executables = {
    pyright = "pyright-langserver";
    angular-language-server = "ngserver";
    haskell-language-server = "haskell-language-server-wrapper";
  };
}
