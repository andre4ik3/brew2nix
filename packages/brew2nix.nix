{ writeShellScriptBin, deno, lib }:

writeShellScriptBin "brew2nix" ''
exec ${lib.getExe deno} run --allow-all --no-config '${./brew2nix.ts}' "$@"
''

