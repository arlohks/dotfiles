{
  description = "My NixOS + Home Manager Flake";

  inputs = {
    nixpkgs.url     = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager = {
      url                   = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
    in {
      # Expose a NixOS configuration
      nixosConfigurations.myHost = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./configuration.nix
          # Import Home Manager as a NixOS module
          ({ config, pkgs, ... }: {
            imports = [ home-manager.nixosModules.home-manager ];
            home-manager.users.myUser = home-manager.lib.homeManagerConfiguration {
              inherit system;
              modules = [ ./home.nix ];
            };
          })
        ];
      };

      # Optionally expose Home Manager standalone
      homeConfigurations.myUser = home-manager.lib.homeManagerConfiguration {
        inherit system;
        modules = [ ./home.nix ];
      };
    };
}

