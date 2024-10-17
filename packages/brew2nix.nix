{ lib, rustPlatform }:

rustPlatform.buildRustPackage {
  pname = "brew2nix";
  version = "0.1.0";

  src = ../brew2nix;

  cargoHash = "sha256-XupYZY7JIT9cpxaaOF/wFs7tWT41OppqFdKh3EPYLUQ=";
}
