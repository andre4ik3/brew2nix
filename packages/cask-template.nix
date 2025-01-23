{
  # base dependencies
  stdenvNoCC,
  writeText,
  fetchurl,

  # cask data
  cask,

  # uncompressing stuff
  xar,
  libarchive,
  _7zz,
  glibcLocalesUtf8,

  # for dmg heuristics
  dmg2img,

  darwin,

  # extraction helper
  brew2nix
}:

let
  srcArch = if stdenvNoCC.targetPlatform.isAarch64 then cask.src.aarch64-darwin else cask.src.x86_64-darwin;
  src = if srcArch == null then throw "cask ${cask.name} is not available for ${stdenvNoCC.targetPlatform.system}" else srcArch;
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

  nativeBuildInputs = [
    brew2nix
    xar
    libarchive
    _7zz
    glibcLocalesUtf8
    dmg2img
    darwin.file_cmds
  ];

  unpackPhase = ''
    EXTRACT_DIR="$TMPDIR/extract"
    mkdir -p "$EXTRACT_DIR"
    cd "$EXTRACT_DIR"
    type="$(file -b "$src")"
    case "$type" in
      "bzip2 compressed data"*)
        # either it's a tar.bz2 or a dmg...
        if dmg2img -l "$src"; then
          echo "looks like a dmg"
          7zz x -snld "$src" || true # ignore "dangerous symlink" errors
        else
          echo "looks like a tar"
          bsdtar --xattrs -xjpf "$src" --preserve-permissions --xattrs
        fi
        ;;
      "zlib compressed data")
        #undmg "$src"
        7zz x -snld "$src" || true # ignore "dangerous symlink" errors
        ;;
      "xar archive compressed"*)
        # Terribly hacky BUT IT WORKS
        xar -xf "$src"
        find . -name "Payload" -type f -exec sh -c 'cat {} | gunzip -dc | bsdcpio -i' \;
        ;;
      "lzfse encoded, lzvn compressed")
        7zz x -snld "$src" || true # ignore "dangerous symlink" errors
        ;;
      "Zip archive data"* | "data") # backup/fallback in case `file` doesn't know what it is
        bsdunzip "$src"
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
    src="${caskJSON}" brew2nix

    # Clean up some oddities from some extraction methods
    xattr -cr "$out"
    find "$APP_DIR" -name "*:*" -type f -exec rm -f {} \; # this is how 7-zip does xattrs
  '';
}
