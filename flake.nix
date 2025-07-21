{
  description = "Arlo’s NixOS + Home Manager flake";

  inputs = {
    nixpkgs.url     = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager = {
      url                   = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    # 1. System configuration for `sudo nixos-rebuild --flake .#arlo`
    nixosConfigurations.arlo = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./configuration.nix
        ./hardware-configuration.nix

        # (Optional) Home Manager NixOS module
        ({ config, pkgs, ... }: {
          imports = [ home-manager.nixosModules.home-manager ];
          home-manager.users.arlo = {
            home.stateVersion = "25.05";
            imports = [ ./home.nix ];
          };
        })
      ];
    };

    # 2. Standalone Home Manager profile
    homeConfigurations.arlo = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [ ./home.nix ];
    };
  };
}
