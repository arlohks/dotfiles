{
  description = "My NixOS + Home Manager Flake";

  inputs = {
    nixpkgs.url     = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager = {
      url                   = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dotfiles = {
      url = "path:.";
    };
  };

  outputs = { self, nixpkgs, home-manager, dotfiles, ... }:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
    in {
      # Expose a NixOS configuration
      nixosConfigurations.arlo = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
	  # Resolve to /etc/nixos/configuration.nix
          dotfiles./configuration.nix
	  dotfiles./hardware-configuration.nix

          # Import Home Manager as a NixOS module
          ({ config, pkgs, ... }: {
            imports = [ home-manager.nixosModules.home-manager ];

            home-manager.users.arlo = home-manager.lib.homeManagerConfiguration {
              inherit system;
              modules = [ dotfiles./home.nix ];
            };
          })
        ];
      };

      # Optionally expose Home Manager standalone
      homeConfigurations.arlo = home-manager.lib.homeManagerConfiguration {
        inherit system;
        modules = [ dotfiles./home.nix ];
      };
    };
}

