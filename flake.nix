{
  description = "Access Homebrew casks from Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-compat.url = "github:nix-community/flake-compat";

    data = {
      url = "github:andre4ik3/brew2nix/data";
      flake = false;
    };
  };

  outputs = { nixpkgs, data, ... }:
  let
    systems = [ "aarch64-darwin" "x86_64-darwin" ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
    overlay = import ./overlay.nix data;
  in
  {
    lib.supportedSystems = [
      "aarch64-darwin"
      "x86_64-darwin"
    ];

    overlays = rec {
      brew2nix = overlay;
      default = brew2nix;
    };

    packages = forAllSystems (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        brew2nix = pkgs.callPackage ./packages/brew2nix { };
      } // (overlay pkgs pkgs).casks
    );
  };
}
