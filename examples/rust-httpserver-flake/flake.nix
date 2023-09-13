# syntax = ghcr.io/reproducible-containers/buildkit-nix:v0.1.1@sha256:7d4c42a5c6baea2b21145589afa85e0862625e6779c89488987266b85e088021

{
  inputs.flake-utils.url = "github:numtide/flake-utils";
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        # See https://ryantm.github.io/nixpkgs/languages-frameworks/rust/
        app = pkgs.rustPlatform.buildRustPackage {
          name = "rust-httpserver";
          cargoSha256 = "N8HCmBEiIX5G3F2OQH5IvkzpwhCJVpR51TB86gV9IAo=";
          src = ./.;
        };
      in rec {
        defaultPackage = pkgs.dockerTools.buildImage {
          name = "rust-httpserver";
          tag = "nix";
          contents = [ pkgs.bash pkgs.coreutils app ];
          config = {
            Cmd = [ "rust-httpserver" ];
            ExposedPorts = { "80/tcp" = { }; };
          };
        };
      });
}
