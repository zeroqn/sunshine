{
  description = "Sunshine Vulkan build via overlay";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      overlay = final: prev: {
        sunshine = prev.callPackage ./vulkan.nix {
          # Avoid recursive self-reference when overriding pkgs.sunshine.
          pkgs = prev;
        };
      };
    in
    (flake-utils.lib.eachSystem [
      "x86_64-linux"
      "aarch64-linux"
    ] (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      in {
        packages = {
          default = pkgs.sunshine;
          sunshine = pkgs.sunshine;
        };
      }))
    // {
      overlays.default = overlay;
    };
}
