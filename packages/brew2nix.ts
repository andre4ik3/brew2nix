// Get the `src` and `out` paths from Nix.
// The `src` path in this case is the full JSON cask data.
// The `out` path is expected to be parsed cask data.

const srcPath = Deno.env.get("src")!;
const outPath = Deno.env.get("out")!;

const operation = Deno.args[0];

// Filters and transforms array of casks
async function convert() {
  // TODO: typing
  const caskData = JSON.parse(await Deno.readTextFile(srcPath));

  const convertedData = caskData.map(cask => {
    // Try to get an arm64 URL, falling back to the default one.
    // Only get those that have a sha256 hash.
    const hasCaskVariation = cask.variations != undefined;
    const hasSequoiaIntel = hasCaskVariation && cask.variations.sequoia != undefined && cask.variations.sequoia.sha256 != undefined && cask.variations.sequoia.sha256.length == 64;
    const hasSequoiaSilicon = hasCaskVariation && cask.variations.arm64_sequoia != undefined && cask.variations.arm64_sequoia.sha256 != undefined && cask.variations.arm64_sequoia.sha256.length == 64;
    const hasNormal = cask.url != undefined && cask.sha256 != undefined && cask.sha256.length == 64;

    const intelDownloadData = hasSequoiaIntel
      ? { url: cask.variations.sequoia.url, sha256: cask.variations.sequoia.sha256 }
      : hasNormal ? { url: cask.url, sha256: cask.sha256 } : null;

    const siliconDownloadData = hasSequoiaSilicon
      ? { url: cask.variations.arm64_sequoia.url, sha256: cask.variations.arm64_sequoia.sha256 }
      : hasNormal ? { url: cask.url, sha256: cask.sha256 } : null;

    return {
      name: cask.token,
      version: cask.version,
      desktopName: cask.name[0],
      src: {
        "x86_64-darwin": intelDownloadData,
        "aarch64-darwin": siliconDownloadData,
      },
      _passthru: cask,
    };
  });

  // Write back converted data.
  await Deno.writeTextFile(outPath, JSON.stringify(convertedData));
}

// helper (yoinked from DenoScript)
async function $(strings, ...values) {
  const cmdline = strings
    .map((str, i) => str + (values[i] || ''))
    .join("");

  const shell = Deno.env.get("SHELL");
  const command = new Deno.Command(shell, {
    args: ["-c", cmdline],
    stdin: "inherit",
    stdout: "inherit",
    stderr: "inherit",
    env: {
      APPDIR: outPath + "/Applications",
      HOMEBREW_PREFIX: outPath,
    },
  });

  console.log(`executing: ${cmdline}`);

  return await command.output();
}

// Extracts data and moves it to the right place according to cask data
async function extract() {
  // TODO: typing
  const caskData = JSON.parse(await Deno.readTextFile(srcPath))._passthru;
  await Deno.mkdir(outPath, { recursive: true });

  for (const artifact of caskData.artifacts) {
    console.log(artifact);
    if ("app" in artifact) {
      // Currently handled by script
    } else if ("binary" in artifact) {
      const [path, opts] = artifact.binary;
      const target = opts != undefined && opts.target ? opts.target : `$HOMEBREW_PREFIX/bin/${path.split("/").at(-1)}`;

      const relativePath = path.replace("$APPDIR", outPath + "/Applications");
      const relativeTarget = target.replace("$HOMEBREW_PREFIX", outPath);

      const finalTarget = relativeTarget.includes("/") ? relativeTarget : `${outPath}/bin/${relativeTarget}`;

      if (relativePath.includes("$")) continue;

      await Deno.mkdir(finalTarget.split("/").slice(0, -1).join("/"), { recursive: true });
      await Deno.symlink(relativePath, finalTarget);
    } else if ("manpage" in artifact) {
      const [path] = artifact.manpage;
      const relativePath = path.replace("$APPDIR", outPath + "/Applications").split("/").slice(-3);
      if (relativePath.includes("$")) continue;
    }
  }
}

switch (operation) {
  case "convert": Deno.exit(await convert());
  case "extract": Deno.exit(await extract());
  default:
    console.error(`Unknown operation ${operation}`);
    Deno.exit(1);
}
