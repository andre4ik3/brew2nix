{ stdenv, deno, lib }:

stdenv.mkDerivation {
  name = "brew2nix";
  src = ./src;

  buildInputs = [ deno ];

  buildPhase = ''
    mkdir -p $out
    deno install --global --allow-all --root $out --name brew2nix $src/main.ts
    sed -i "s# deno # ${lib.getExe deno} #g" "$out/bin/brew2nix"
  '';

  meta.mainProgram = "brew2nix";
}

