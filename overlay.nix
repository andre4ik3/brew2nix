# from flake.nix:
data:

# from nixpkgs/when used as an overlay:
final: prev:

let
  lib = prev.lib;
  brew2nix = prev.callPackage ./packages/brew2nix.nix { };
  casks = lib.trivial.importJSON (prev.runCommand "converted-data" {
    src = "${data}/cask.json";
  } "${brew2nix}/bin/brew2nix convert");
in

{
  casks = lib.trivial.pipe casks [
    # Convert cask data to actual packages, in the format for listToAttrs
    (builtins.map (cask: {
      name = cask.name;
      value = prev.callPackage ./packages/cask-template.nix { inherit cask brew2nix; };
    }))

    # Convert list of { name = "...", value = "..." } to attrset ("object")
    builtins.listToAttrs
  ];
}
