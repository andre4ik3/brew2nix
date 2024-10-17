# from flake.nix:
data:

# from nixpkgs/when used as an overlay:
final: prev:

let
  lib = prev.lib;
  casks = lib.trivial.importJSON "${data}/cask.json";
  brew2nix = final.callPackage ./packages/brew2nix.nix { };
in

lib.trivial.pipe casks [
  # Only get packages that have a sha256 hash
  (builtins.filter (x: (builtins.stringLength x.sha256) == 64))

  # Convert cask data to actual packages, in the format for listToAttrs
  (builtins.map (cask: {
    name = cask.token;
    value = final.callPackage ./packages/cask-template.nix { inherit brew2nix cask; };
  }))

  # Convert list of { name = "...", value = "..." } to attrset ("object")
  builtins.listToAttrs

  # Put all casks neatly under pkgs.casks, and the helper brew2nix package
  (allCasks: {
    casks = allCasks;
    brew2nix = brew2nix;
  })
]
