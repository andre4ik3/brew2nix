{
  description = "Access Homebrew casks from Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-compat.url = "github:nix-community/flake-compat";
  };

  outputs = { self, nixpkgs, ... }:
  let
    systems = [ "aarch64-darwin" "x86_64-darwin" ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in
  {
    lib.supportedSystems = [
      "aarch64-darwin"
      "x86_64-darwin"
    ];

    overlays = rec {
      brew2nix = default;
      default = ./overlay.nix;
    };

    packages = forAllSystems (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      (import ./overlay.nix pkgs pkgs).casks
    );
  };
}
