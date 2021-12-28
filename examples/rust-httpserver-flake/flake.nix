# syntax = ghcr.io/akihirosuda/buildkit-nix:v0.0.2@sha256:ad13161464806242fd69dbf520bd70a15211b557d37f61178a4bf8e1fd39f1f2

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
