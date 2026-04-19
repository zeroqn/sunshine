{
  description = "Sunshine prebuilt release flake with source-build fallback";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      releaseMeta = builtins.fromJSON (builtins.readFile ./release-assets.json);
      supportedSystems = builtins.attrNames releaseMeta.assets;

      mkBinaryPackage = pkgs: system:
        pkgs.callPackage ./prebuilt-package.nix {
          releaseAsset =
            releaseMeta.assets.${system}
            // {
              inherit system;
              inherit (releaseMeta) owner repo;
              inherit (releaseMeta.release) tag version;
            };
        };

      mkSourceBuild = pkgs:
        pkgs.callPackage ./vulkan.nix {
          inherit pkgs;
        };

      overlay = final: prev:
        let
          system = prev.stdenv.hostPlatform.system;
          hasBinary = builtins.hasAttr system releaseMeta.assets;
        in
        {
          sunshine-release-build = mkSourceBuild prev;
        }
        // prev.lib.optionalAttrs hasBinary {
          sunshine = mkBinaryPackage prev system;
          sunshine-bin = final.sunshine;
        };
    in
    (flake-utils.lib.eachSystem supportedSystems (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
        updateReleaseAssets = pkgs.writeShellApplication {
          name = "update-release-assets";
          runtimeInputs = [
            pkgs.bash
            pkgs.curl
            pkgs.jq
            pkgs.nix
          ];
          text = ''
            exec ${./updater.sh} "$@"
          '';
        };
      in
      {
        packages = {
          default = pkgs.sunshine;
          sunshine = pkgs.sunshine;
          sunshine-bin = pkgs.sunshine-bin;
          releaseBuild = pkgs.sunshine-release-build;
        };

        apps.update-release-assets = {
          type = "app";
          program = "${updateReleaseAssets}/bin/update-release-assets";
        };
      }))
    // {
      overlays.default = overlay;

      nixosModules.default = { ... }: {
        nixpkgs.overlays = [ self.overlays.default ];
      };
    };
}
