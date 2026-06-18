{
  description = "Your new nix config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };

    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };

    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };

    mac-app-util = {
      url = "github:hraban/mac-app-util";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
    };

    nixgl = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
    };

    paneru = {
      url = "github:karinushka/paneru";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      homebrew-bundle,
      homebrew-cask,
      homebrew-core,
      mac-app-util,
      nix-darwin,
      nix-homebrew,
      nixgl,
      nixvim,
      sops-nix,
      ...
    }@inputs:
    let
      inherit (self) outputs;
      inherit (nixpkgs) lib;
      user = "robertogoam";

      # Per-machine platform. Hosts whose system ends in "darwin" get a nix-darwin
      # system (built from modules/macos/<host>/<host>.nix); every host also gets a
      # standalone home-manager config "<user>@<host>" (built from
      # modules/home-manager/hosts/<host>/<host>.nix). To add a machine, add a line
      # here and copy an existing host's module dir(s) — bootstrap.sh's "create a
      # new host" does both. Keep the marker line; the script inserts new hosts
      # directly above it.
      hosts = {
        prometheus = "aarch64-darwin";
        vulcan = "aarch64-darwin";
        perseus = "x86_64-linux";
        # bootstrap-hosts-marker (do not remove)
      };

      mkDarwin =
        host: system:
        nix-darwin.lib.darwinSystem {
          specialArgs = { inherit inputs outputs user system; };
          modules = [ ./modules/macos/${host}/${host}.nix ];
        };

      mkHome =
        host: system:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = { inherit inputs nixgl outputs user; };
          modules = [ ./modules/home-manager/hosts/${host}/${host}.nix ];
        };
    in
    {
      overlays = import ./overlays { inherit inputs; };

      # MacOS configuration entrypoint
      # Available through nix run nix-darwin -- switch --flake .
      darwinConfigurations = lib.mapAttrs mkDarwin (
        lib.filterAttrs (_: system: lib.hasSuffix "darwin" system) hosts
      );

      # Standalone home-manager configuration entrypoint
      # Available through 'home-manager switch --flake .#your-username@your-hostname'
      homeConfigurations = lib.mapAttrs' (
        host: system: lib.nameValuePair "${user}@${host}" (mkHome host system)
      ) hosts;
    };
}
