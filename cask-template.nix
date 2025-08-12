{
  # base dependencies
  stdenvNoCC,
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
  lib,
}:

let
  inherit (stdenvNoCC.targetPlatform) system;

  src = let
    srcArch = package.files.${system};
    src = if srcArch == null then throw "cask ${package.name} has no fixed-output source available for ${system}" else srcArch;
    differentVersions = package.version != src.version;
  in lib.warnIf differentVersions ''
    cask ${package.name} has version ${package.version} but source file has version ${src.version} (most likely the latest version does not have a hash)
  '' src;

  artifacts = let
    needsNoPrefix = artifact: artifact ? target -> !(lib.strings.hasInfix "$HOMEBREW_PREFIX") artifact.target;
  in lib.mapAttrs (name: lib.filter needsNoPrefix) package.artifacts;
in

stdenvNoCC.mkDerivation {
  pname = package.name;
  inherit (src) version;
  inherit (package) desktopName;

  src = fetchurl {
    pname = package.name;
    inherit (src) version url hash;
  };

  meta = package.meta // lib.optionalAttrs (lib.length artifacts.binaries != 0) {
    mainProgram = lib.last (lib.splitString "/" (lib.elemAt artifacts.binaries 0).source);
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
      "zlib compressed data" | "lzfse encoded, lzvn compressed")
        #undmg "$src"
        7zz x -snld "$src" || true # ignore "dangerous symlink" errors
        ;;
      "xar archive compressed"*)
        # Terribly hacky BUT IT WORKS
        xar -xf "$src"
        find . -name "Payload" -type f -exec sh -c 'cat {} | gunzip -dc | bsdcpio -i' \;
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

    # Fixup nested extraction directory
    contents=("$EXTRACT_DIR"/*)
    if [ ''${#contents[@]} -eq 1 ] && [ -d "''${contents[0]}" ] && [[ "$(basename "''${contents[0]}")" != *.app ]]; then
      EXTRACT_DIR="''${contents[0]}"
    fi

    ${lib.concatMapStringsSep "\n" ({ source, target ? "$APPDIR/", ... }: ''
      echo "${source}"
      cp -R "$EXTRACT_DIR"/"${source}" "${target}"
    '') artifacts.apps}

    ${lib.concatMapStringsSep "\n" ({ source, target ? "$out/bin/", ... }: ''
      mkdir -p "$out/bin"
      ln -s "${source}" "${target}"
    '') artifacts.binaries}

    ${lib.optionalString (lib.length artifacts.apps == 0) ''
      # Yep... this is how we handle pkg's...
      # Avoid copying extra apps that aren't the main app, if possible (cough MSAU cough)
      if [ -d "$EXTRACT_DIR/${package.desktopName}.app" ]; then
        cp -R "$EXTRACT_DIR/${package.desktopName}.app" "$APPDIR"/
      else
        find "$EXTRACT_DIR" -name "*.app" -type d -prune -exec cp -R {} "$APPDIR"/ \;
      fi
    ''}

    # Clean up some oddities from some extraction methods
    find "$APPDIR" -name "*:*" -type f -exec rm -f {} \; # this is how 7-zip does xattrs

    # Safeguard in case no output was produced
    if ! find "$out" -type f -print -quit | grep -q .; then
      ls -hal "$EXTRACT_DIR"
      echo "error: no files in output"
      exit 1
    fi

    # Remove extended attributes (e.g. quarantine or provenance)
    xattr -cr "$out"
  '';
}
