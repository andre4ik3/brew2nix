{ lib, stdenvNoCC, fetchurl, unzip, glibcLocalesUtf8, undmg, cask }:

stdenvNoCC.mkDerivation {
  pname = cask.token;
  version = cask.version;
  desktopName = builtins.elemAt cask.name 0;

  src = fetchurl {
    url = cask.url;
    sha256 = cask.sha256;
  };

  nativeBuildInputs = [ unzip glibcLocalesUtf8 undmg ];
  unpackPhase = ''
    EXTRACT_DIR="$TMPDIR/extract"
    mkdir -p "$EXTRACT_DIR"
    cd "$EXTRACT_DIR"
    case "$src" in
      *.zip)
        unzip "$src"
        ;;
      *.dmg)
        undmg "$src"
        ;;
      *)
        echo "Unsupported file type: $extension"
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
  '';
}
