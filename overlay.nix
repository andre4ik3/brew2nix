# from flake.nix:
data:

# from nixpkgs/when used as an overlay:
final: prev:

let
  inherit (final) lib;

  mkPackage = name: let
    prefix = lib.substring 0 2 (builtins.trace "evaluating ${name}" name);
    package = lib.importJSON "${data}/packages/${prefix}/${name}.json";
  in final.callPackage ./cask-template.nix { inherit package; };

  # A map of each package name/alias to the canonical package name.
  packageNameMap = lib.importJSON "${data}/package-names.json";

  # A list of only canonical package names.
  packageNames = lib.attrValues packageNameMap;

  # A map of canonical package names to packages.
  packages = lib.listToAttrs (lib.map (name: lib.nameValuePair name (mkPackage name)) packageNames);

  # A map of alias names to packages.
  packagesWithAliases = lib.mapAttrs (alias: name: packages.${name}) packageNameMap;
in

{
  casks = packagesWithAliases;
}
