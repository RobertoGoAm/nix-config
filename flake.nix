{
  description = "RobertoGoAm's nix configuration";

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-unstable";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mac-app-util = {
      url = "github:hraban/mac-app-util";
    };
  };

  outputs = { self, nixpkgs, home-manager, nix-darwin, mac-app-util, ... } @ inputs: {
    darwinConfigurations = {
      # Desktop Mac (Apple Silicon)
      vulcan = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";

        modules = [
          mac-app-util.darwinModules.default
          home-manager.darwinModules.home-manager
          {
            users.users.robertogoam = {
              home = "/Users/robertogoam";
              packages = with nixpkgs.legacyPackages.aarch64-darwin; [
                git
              ];
            };
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.robertogoam = {
              imports = [
                mac-app-util.homeManagerModules.default
                ./hosts/vulcan/home.nix
              ];
            };

            imports = [
              ./hosts/vulcan/configuration.nix
              ./hosts/vulcan/software.nix
            ];

            _module.args.self = self;
          }
        ];
      };
    };
  };
}
