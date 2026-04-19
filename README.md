# Sunshine prebuilt Nix flake

This repo publishes a Nix flake that installs Sunshine from this repo's pinned
GitHub release assets instead of rebuilding Sunshine from source in downstream
NixOS systems.

The default package output is the prebuilt binary bundle:

- `packages.<system>.default`
- `packages.<system>.sunshine`
- `packages.<system>.sunshine-bin`

The source build is still available as:

- `packages.<system>.releaseBuild`

## Downstream NixOS flake usage

### Option 1: use the provided NixOS module/overlay

This is the easiest option if you want `pkgs.sunshine` in your system to point
at the prebuilt package from this repo.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    sunshine-prebuilt.url = "github:zeroqn/sunshine";
  };

  outputs = { self, nixpkgs, sunshine-prebuilt, ... }: {
    nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        sunshine-prebuilt.nixosModules.default
        ({ pkgs, ... }: {
          environment.systemPackages = [
            pkgs.sunshine
          ];
        })
      ];
    };
  };
}
```

After importing `sunshine-prebuilt.nixosModules.default`, anything in that
system using `pkgs.sunshine` will receive the prebuilt release from this repo.

### Option 2: use the package directly without the overlay

If you only want to install the package and do not want to override
`pkgs.sunshine` globally:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    sunshine-prebuilt.url = "github:zeroqn/sunshine";
  };

  outputs = { self, nixpkgs, sunshine-prebuilt, ... }: {
    nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [
            sunshine-prebuilt.packages.${pkgs.system}.default
          ];
        })
      ];
    };
  };
}
```

## Updating the pinned release assets

This repo stores pinned release metadata in `release-assets.json`.

To refresh it against the current GitHub release:

```bash
./updater.sh
```

or through the flake app:

```bash
nix run .#update-release-assets
```

If the GitHub release is private, provide a token:

```bash
GITHUB_TOKEN=... ./updater.sh
```

## Notes

- Supported systems are whatever is currently listed in `release-assets.json`.
- The release-consuming outputs are intended for downstream installs.
- `releaseBuild` exists so CI in this repo can still build and publish new
  release artifacts from source.
