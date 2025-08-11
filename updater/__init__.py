import json
from os import makedirs
from base64 import b64encode
from urllib3 import request
from platform import system

USER_AGENT = f"NixHomebrewCasks/1.0 ({system()}; +https://github.com/andre4ik3/nix-homebrew-casks)"

# The URL where cask data is retrieved from.
CASK_DATA_URL = "https://formulae.brew.sh/api/cask.json"

# A list of OS release names in descending chronological order, to attempt to get packages from.
OS_RELEASES = ["sequoia", "sonoma", "ventura", "monterey", "big_sur"]

ARTIFACT_TYPES = {
    "app": "apps",
    "binary": "binaries",
    "manpage": "manPages",
    "artifact": "files",
    "bash_completion": "shellCompletionsBash",
    "fish_completion": "shellCompletionsFish",
    "zsh_completion": "shellCompletionsZsh",
}

IGNORED_ARTIFACT_TYPES = [
    "zap",
    "uninstall",
    "preflight",
    "postflight",
    "uninstall_preflight",
    "uninstall_postflight",
    "installer",

    # handled somewhat poorly, but it is, indeed, handled
    "pkg",
]


def fixup_name(name: str) -> str:
    """Fixes up a package name to be easier to work with in Nix."""
    if name[0].isdigit():
        name = f"_{name}"
    return name


def to_sri_hash(algorithm: str, data: str) -> str:
    """Converts a hash from an algorithm and hex string to an SRI hash."""
    data = bytes.fromhex(data)
    data = b64encode(data)
    data = data.decode("ascii")
    return f"{algorithm}-{data}".strip()


def get_casks() -> list[dict]:
    """Retrieves the latest cask data from Homebrew."""
    resp = request("GET", CASK_DATA_URL, headers={"User-Agent": USER_AGENT})
    return resp.json()


def get_file(data: dict) -> dict | None:
    """Try to extract a downloadable file from a data type."""
    if "url" in data and "sha256" in data and len(data["sha256"]) == 64:
        return {
            "url": data["url"],
            "version": data["version"].split(",")[0],
            "hash": to_sri_hash("sha256", data["sha256"]),
        }
    else:
        return None


def get_cask_file(cask: dict, arm: bool) -> dict | None:
    """Returns file download details for an architecture variant."""
    file = get_file(cask)
    if file is not None:
        return file

    if "variations" not in cask:
        return None  # nothing else if no variants and the base one failed

    prefix = "arm64_" if arm else ""
    variants = [f"{prefix}{name}" for name in OS_RELEASES]

    for name in variants:
        if name in cask["variations"]:
            file = get_file(cask["variations"][name])
            if file is not None:
                return file

    return None


def cask_to_package(cask: dict) -> dict:
    """Converts a Homebrew cask into package metadata."""
    aliases = list({cask["token"], cask["full_token"], *cask["old_tokens"]})

    # Convert artifacts to a friendlier form.
    artifacts = {value: [] for value in ARTIFACT_TYPES.values()}
    for artifact in cask["artifacts"]:
        for key, parameters in artifact.items():
            if key in ARTIFACT_TYPES.keys():
                assert 2 >= len(parameters) > 0
                artifacts[ARTIFACT_TYPES[key]].append({
                    "source": parameters[0],
                    **(parameters[1] if len(parameters) > 1 else {})
                })
            elif key not in IGNORED_ARTIFACT_TYPES:
                # print(f"?? Unknown artifact type {key} in cask {cask["token"]}: {parameters}")
                pass

    return {
        "name": fixup_name(cask["token"]),
        "desktopName": cask["name"][0],
        # "desktopName": cask["name"][0] if "name" in cask and len(cask["name"]) > 0 else cask["token"],
        "version": cask["version"].split(",")[0],
        "aliases": [fixup_name(alias) for alias in aliases],
        "artifacts": artifacts,
        "files": {
            "aarch64-darwin": get_cask_file(cask, True),
            "x86_64-darwin": get_cask_file(cask, False),
        },
        "meta": {
            "description": cask["desc"],
            "homepage": cask["homepage"],
        },
        "passthru": {
            # "cask": cask
        }
    }


def write_package(package: dict):
    """Writes a package metadata file to disk."""
    # pkgs/by-name style
    prefix = f"packages/{package["name"][0:2]}"
    makedirs(prefix, exist_ok=True)
    with open(f"{prefix}/{package["name"]}.json", "w") as fp:
        json.dump(package, fp)


def main():
    packages = []

    for cask in get_casks():
        try:
            packages.append(cask_to_package(cask))
        except Exception as err:
            print(f"!! Failed to convert cask {cask["token"]} to a package: {err}")

    # A map of each package name/alias to the canonical package name.
    package_names = {alias: package["name"] for package in packages for alias in package["aliases"]}

    for package in packages:
        if package["name"][0] in ["a"]:
            write_package(package)

    with open("package-names.json", "w") as fp:
        json.dump(package_names, fp)


if __name__ == "__main__":
    main()
