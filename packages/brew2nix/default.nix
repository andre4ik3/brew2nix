{ stdenv, deno, lib }:

stdenv.mkDerivation {
  name = "brew2nix";
  src = ./src;

  buildInputs = [ deno ];

  buildPhase = ''
    mkdir -p $out
    deno install --global --allow-all --root $out --name brew2nix $src/main.ts
  '';

  meta.mainProgram = "brew2nix";
}

