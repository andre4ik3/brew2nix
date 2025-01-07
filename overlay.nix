# from flake.nix:
data:

# from nixpkgs/when used as an overlay:
final: prev:

let
  lib = prev.lib;
  brew2nix = prev.callPackage ./packages/brew2nix.nix { };
  casks = lib.trivial.importJSON "${data}/cask.json";
in

{
  casks = lib.trivial.pipe casks [
    (builtins.map (cask:
      let
        intelVariation = if cask?variations?sequoia?sha256 && builtins.stringLength cask.variations.sequoia.sha256 == 64 then cask.variations.sequoia else null;
        armVariation = if cask?variations?arm64_sequoia?sha256 && builtins.stringLength cask.variations.arm64_sequoia.sha256 == 64 then cask.variations.arm64_sequoia else null;
        normalVariation = if cask?sha256 && builtins.stringLength cask.sha256 == 64 then { inherit (cask) url sha256; } else null;
      in
      {
        name = cask.token;
        version = cask.version;
        desktopName = builtins.elemAt cask.name 0;
        src = {
          x86_64-darwin = if intelVariation != null then intelVariation
            else if normalVariation != null then normalVariation
              else throw "Cask ${cask.token} is not available for x86_64-darwin";

          aarch64-darwin = if armVariation != null then armVariation
            else if normalVariation != null then normalVariation
              else throw "Cask ${cask.token} is not available for aarch64-darwin";
        };
      }
    ))

    # Convert cask data to actual packages, in the format for listToAttrs
    (builtins.map (cask: {
      name = cask.name;
      value = prev.callPackage ./packages/cask-template.nix { inherit cask brew2nix; };
    }))

    # Convert list of { name = "...", value = "..." } to attrset ("object")
    builtins.listToAttrs
  ];
}
