final: prev:

let
  lib = final.lib;
  casks = lib.trivial.importJSON ./cask.json;
in

lib.trivial.pipe casks [
  # Only get packages that have a sha256 hash
  (builtins.filter (x: (builtins.stringLength x.sha256) == 64))

  # Convert cask data to actual packages, in the format for listToAttrs
  (builtins.map (cask: {
    name = cask.token;
    value = final.callPackage ./package.nix { inherit cask; };
  }))

  # Convert list of { name = "...", value = "..." } to attrset ("object")
  builtins.listToAttrs

  # Put all casks neatly under pkgs.casks
  (allCasks: { casks = allCasks; })
]
