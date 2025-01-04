{ stdenvNoCC, writeText, fetchurl, undmg, xar, libarchive, _7zz, glibcLocalesUtf8, cask, brew2nix }:

let
  src = if stdenvNoCC.targetPlatform.isAarch64 then cask.src.aarch64-darwin else cask.src.x86_64-darwin;
  caskJSON = writeText "${cask.name}.json" (builtins.toJSON cask);
in

stdenvNoCC.mkDerivation {
  pname = cask.name;
  version = cask.version;
  desktopName = cask.desktopName;

  src = fetchurl {
    name = cask.name;
    inherit (src) url sha256;
  };

  buildInputs = [ brew2nix ];

  nativeBuildInputs = [ undmg xar libarchive _7zz glibcLocalesUtf8 ];
  unpackPhase = ''
    EXTRACT_DIR="$TMPDIR/extract"
    mkdir -p "$EXTRACT_DIR"
    cd "$EXTRACT_DIR"
    type="$(file -b "$src")"
    case "$type" in
      "Zip archive data"*)
        bsdunzip "$src"
        ;;
      "bzip2 compressed data"*)
        bsdtar --xattrs -xjpf "$src" --preserve-permissions --xattrs
        ;;
      "zlib compressed data")
        undmg "$src"
        ;;
      "xar archive compressed"*)
        # Terribly hacky BUT IT WORKS
        xar -xf "$src"
        find . -name "Payload" -type f -exec sh -c 'cat {} | gunzip -dc | bsdcpio -i' \;
        ;;
      "lzfse encoded, lzvn compressed")
        7zz x -snld "$src"
        ;;
      *)
        echo "Unsupported file type: $type"
        exit 1
        ;;
    esac
  '';

  dontPatch = true;
  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;
  noDumpEnvVars = true;

  installPhase = ''
    EXTRACT_DIR="$TMPDIR/extract"
    APP_DIR="$out/Applications"

    mkdir -p "$APP_DIR"
    find "$EXTRACT_DIR" -name "*.app" -type d -prune -exec mv {} "$APP_DIR" \;
    src="${caskJSON}" brew2nix extract
  '';
}
