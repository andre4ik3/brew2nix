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
  - Caveat: the CLI wrapper script doesn't work (yet)
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
- `lagrange`
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
      inputs.data.url = "github:andre4ik3/brew2nix/data"; # keeps cask versions up-to-date
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
- `nix-collect-garbage` won't work for packages downloaded by `brew2nix` until you grant `nix` Full Disk Access in Privacy & Security. (The first time it fails, just go to Privacy & Security, and `nix` will show up there. Grant it access and you should be good to go.)
- Some apps say that they are damaged, but you can allow them to run in Privacy & Security. TODO: figure out why they say they're damaged (codesigning seems ok?)

To-Do
-----

- Quarantine maybe? Would it break reproducibility?

[1]: https://formulae.brew.sh/api/cask.json
