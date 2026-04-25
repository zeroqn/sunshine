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
        {
          services.sunshine = {
            enable = true;
            openFirewall = true;
          };
        })
      ];
    };
  };
}
```

After importing `sunshine-prebuilt.nixosModules.default`, anything in that
system using `pkgs.sunshine` will receive the prebuilt release from this repo.

The imported overlay makes the upstream `services.sunshine` NixOS module use
this repo's prebuilt `pkgs.sunshine`. Prefer that service module for a real
host setup because it also loads `uinput`, installs the udev rules used by
virtual gamepads, and enables Avahi publishing. For DRM/KMS capture on systems
that require it, add the privileged wrapper; this flake also grants
`CAP_SYS_NICE` to that wrapper so Sunshine can raise its worker thread
priority:

```nix
{
  services.sunshine.capSysAdmin = true;
}
```

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

If you install only the package, you may still need the matching runtime system
configuration yourself:

```nix
{
  boot.kernelModules = [ "uinput" ];
  services.udev.packages = [ sunshine-prebuilt.packages.${pkgs.system}.default ];
  services.avahi = {
    enable = true;
    publish = {
      enable = true;
      userServices = true;
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
