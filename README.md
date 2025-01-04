brew2nix
========

> [!CAUTION]
> **‼️ VERY EXPERIMENTAL ‼️**

A very experimental way of installing Homebrew casks via Nix, in a reproducible
way, and **without needing to have Homebrew installed.** It pulls its data from
[Homebrew's API][1] and transforms that into Nix packages.

The goal for this project is simple: if Homebrew is just being used to install
casks (either imperatively or via `nix-darwin`), this aims to replace it. This
makes updates and installations much easier and faster, since there's no need to
shell out to Homebrew, which is super slow due to Ruby and whatnot. Plus, the
casks become fully (mostly) reproducible, since they are versioned and locked
through the existing `flake.lock` system.

**Not all packages work:** only some `.zip` and `.dmg` packages will work. In
general, you can just try to build it using a command like the following and
see if it works (the app should be under `result/Applications`):

```bash
nix build github:andre4ik3/brew2nix#packages.aarch64-darwin.casks.<APP_NAME> -L
```

Non-exhaustive list of verified packages that work (tested personally):

- `arc`
- `iterm2`
- `firefox`
- `sketch`
- `zen-browser`
- `eloston-chromium`
- `orion`
- `proxyman`
- `hoppscotch`
- `iina`
- `whisky`
- `nova`
- `ia-presenter`
- `crystalfetch`
- `utm`
- `transmission`
- `transmit`
- `betterdisplay`
- `raycast`
- `syncthing`
- `cleanshot`
- `ghostty`
  - It will say that it's damaged, but you can allow it in Privacy & Security. TODO: figure out why it says it's damaged (codesigning seems ok?)
- `microsoft-word`, `microsoft-excel`, `microsoft-powerpoint` (`.pkg`'s!!)
- ...probably most `.zip` and `.dmg` packages. Again, check using command above. (no need to install to check, just need Nix installed)

List of stuff that DOESN'T work:

- `apparency`, `suspicious-package`, `istat-menus@6` (No sha256 on the top-level download)
- `bettertouchtool` (resources get modified for some reason)
- `.pkg` files that need to run scripts
- Anything that hard-requires to be in `/Applications` (e.g. `little-snitch` or `secretive`)

Usage
-----

Add it as an input in your flake:

```nix
{
  inputs = {
    # ... other stuff ...
    brew2nix = {
      url = "github:andre4ik3/brew2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # ... other stuff ...
  };

  outputs = { ... }: {
    # ...
  };
}
```

Then add it as an overlay:

```nix
# assuming brew2nix is this exact flake, passed via specialArgs or something

{ brew2nix, pkgs }:

{
  nixpkgs.overlays = [ brew2nix.overlays.default ];

  # then, simply:
  environment.systemPackages = with pkgs.casks; [
    arc
    sketch
    iterm2
    proxyman
    # etc...
  ];

  # or, in home manager:
  home.packages = with pkgs.casks; [
    firefox
    iina
    utm
    transmit
    # etc...
  ];
}
```

Caveats
-------

- Apps trying to update themselves will fail. This is intentional, of course -- updates are exclusively managed via Nix.

To-Do
-----

- Currently the extraction is just a very simple script that uses unzip or undmg depending on the file extension.

- Almost no information from Homebrew is used. The script (see `package.nix`) simply finds `.app` files and moves them to an `Applications` directory.

- To make this "proper", essentially a small Homebrew re-implementation needs to be created. This re-implementation can then parse the cask JSON file, like Homebrew would, and move things to the correct places from data supplied from Homebrew, instead of just guessing.

- Instead of using `undmg`, it should use built-in macOS utilities (aka `hdiutil`).

- Some packages have separate `aarch64` and `x86_64` versions. Currently this isn't handled at all. I think `aarch64` is the default in most cases. I think.

- Quarantine maybe? Would it break reproducibility?

[1]: https://formulae.brew.sh/api/cask.json
