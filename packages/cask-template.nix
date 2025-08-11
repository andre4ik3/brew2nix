{
  # base dependencies
  stdenvNoCC,
  writeText,
  fetchurl,

  # package data
  package,

  # uncompressing stuff
  xar,
  libarchive,
  _7zz,
  glibcLocalesUtf8,

  # for dmg heuristics
  dmg2img,

  darwin,
}:

let
  inherit (stdenvNoCC.targetPlatform) system;
  srcArch = package.files.${system};
  src = if srcArch == null then throw "cask ${package.name} is not available for ${system}" else srcArch;
in

stdenvNoCC.mkDerivation {
  pname = package.name;
  inherit (src) version;
  inherit (package) desktopName;

  src = fetchurl {
    pname = package.name;
    inherit (src) version url hash;
  };

  nativeBuildInputs = [
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
  dontUpdateAutotoolsGnuConfigScripts = true;
  noDumpEnvVars = true;

  installPhase = ''
    EXTRACT_DIR="$TMPDIR/extract"
    APPDIR="$out/Applications"

    mkdir -p "$APPDIR"
    find "$EXTRACT_DIR" -name "*.app" -type d -prune -exec cp -R {} "$APPDIR"/ \;

    # Clean up some oddities from some extraction methods
    xattr -cr "$out"
    find "$APPDIR" -name "*:*" -type f -exec rm -f {} \; # this is how 7-zip does xattrs
  '';
}
