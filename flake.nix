{
  description = "Access Homebrew casks from Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-25.05";
    flake-compat.url = "github:nix-community/flake-compat";

    data = {
      url = "github:andre4ik3/brew2nix/data";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, data, ... }: let
    inherit (nixpkgs) lib;
    systems = [ "aarch64-darwin" "x86_64-darwin" ];
  in
  {
    lib.supportedSystems = systems;

    overlays = rec {
      homebrew-casks = import ./overlay.nix data;
      brew2nix = homebrew-casks;
      default = homebrew-casks;
    };

    packages = lib.genAttrs systems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in (self.overlays.homebrew-casks pkgs pkgs).casks);

    devShells = lib.genAttrs systems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        packages = [ pkgs.python3 ];
      };
    });
  };
}
