nix-homebrew-casks
==================

Exposes Homebrew casks as Nix packages, in a reproducible way, and **without
needing to have Homebrew installed.** It pulls its data from [Homebrew's
API][1] and transforms that into Nix packages.

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
nix build github:andre4ik3/nix-homebrew-casks#<APP_NAME> -L
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
- `bettertouchtool`
- `microsoft-word`, `microsoft-excel`, `microsoft-powerpoint` (`.pkg`'s!!)
- `visual-studio-code`, `vscodium`, `cursor`
- ...probably most `.zip` and `.dmg` packages. Again, check using command above. (no need to install to check, just need Nix installed)

List of stuff that DOESN'T work:

- `apparency`, `suspicious-package`, `istat-menus@6` (No sha256 on the top-level download)
- `.pkg` files that need to run scripts
- Anything that hard-requires to be in `/Applications` (e.g. `little-snitch` or `secretive`)

Usage
-----

The cask data files are stored in a separate branch from the code (to allow
pinning the cask versions separately from the code):

```nix
{
  inputs = {
    # ... other stuff ...

    # auto daily-updated cask data from Homebrew servers
    homebrew-casks = {
      url = "github:andre4ik3/nix-homebrew-casks/data";
      flake = false;
    };

    nix-homebrew-casks = {
      url = "github:andre4ik3/nix-homebrew-casks";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.data.follows = "homebrew-casks";
    };

    # ... other stuff ...
  };

  outputs = { nix-homebrew-casks, nixpkgs, ... }: {
    nixosConfigurations.exampleSystem = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./some-module.nix
        # ... other stuff ...
        {
          nixpkgs.overlays = [ nix-homebrew-casks.overlays.default ];
        }
        # ... other stuff ...
      ];
    };
  };
}
```

Caveats
-------

- Apps trying to update themselves will fail. This is intentional, of course --
  updates are exclusively managed via Nix.
- Garbage collection won't work for apps downloaded by `nix-homebrew-casks`
  until you grant `nix` Full Disk Access in Privacy & Security, as the apps are
  protected by macOS under the new "app data protection". (The first time it
  fails, just go to Privacy & Security, and `nix` will show up there. Grant it
  access and you should be good to go.)
- Spotlight and Launchpad won't work with the installed apps properly. Raycast
  works perfectly though.
- Might have two instances of apps open when rebuilding (or more if
  frequently!). Solution is to `darwin-rebuild switch`, then fully reboot (to
  clean up all running apps), then run GC.

To-Do
-----

- Quarantine maybe? Would it break reproducibility?

[1]: https://formulae.brew.sh/api/cask.json
