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

      mkRuntimeDeps = pkgs:
        with pkgs;
        [
          at-spi2-core
          avahi
          boost
          cairo
          curl
          gdk-pixbuf
          glib
          gtk3
          harfbuzz
          libappindicator-gtk3
          libcap
          libdbusmenu-gtk3
          libdrm
          libevdev
          libglvnd
          libgbm
          libICE
          libnotify
          libopus
          libpulseaudio
          libSM
          libva
          libvdpau
          miniupnpc
          numactl
          openssl
          pango
          pipewire
          vulkan-loader
          wayland
          libx11
          libxcb
          libxext
          libxfixes
          libxi
          libxkbcommon
          libxrandr
          libxtst
          zlib
        ];

      mkBinaryPackage = pkgs: system:
        pkgs.callPackage ./prebuilt-package.nix {
          runtimeDeps = mkRuntimeDeps pkgs;
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

      nixosModules.default = { config, lib, ... }: {
        nixpkgs.overlays = [ self.overlays.default ];

        # Upstream's RPM grants both capabilities. The nixpkgs module uses the
        # same wrapper for DRM/KMS capture; include CAP_SYS_NICE there too so
        # Sunshine can raise its capture/encoder thread priority when users opt
        # into the privileged wrapper.
        security.wrappers.sunshine.capabilities =
          lib.mkIf (config.services.sunshine.enable && config.services.sunshine.capSysAdmin)
            (lib.mkForce "cap_sys_admin,cap_sys_nice+p");
      };
    };
}
