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
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
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
      nixvim,
      ...
    }@inputs:
    let
      inherit (self) outputs;
      user = "robertogoam";
    in
    {
      overlays = import ./overlays { inherit inputs; };

      # MacOS configuration entrypoint
      # Available through nix run nix-darwin -- switch --flake .
      darwinConfigurations = {
        # Desktop mac (Apple Silicon)
        vulcan = nix-darwin.lib.darwinSystem {
          specialArgs = { inherit inputs outputs user; };

          modules = [
            ./modules/macos/vulcan/vulcan.nix
          ];
        };
      };

      # Standalone home-manager configuration entrypoint
      # Available through 'home-manager switch --flake .#your-username@your-hostname'
      homeConfigurations = {
        # Desktop mac (Apple Silicon)
        "${user}@vulcan" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
          extraSpecialArgs = { inherit inputs outputs user; };

          modules = [
            ./modules/home-manager/hosts/vulcan/vulcan.nix
          ];
        };

        # Work laptop
        "${user}@perseus" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit inputs outputs user; };

          modules = [
            ./modules/home-manager/hosts/perseus/perseus.nix
          ];
        };
      };
    };
}
