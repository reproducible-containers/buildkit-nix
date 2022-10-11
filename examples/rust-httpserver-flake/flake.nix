# syntax = ghcr.io/reproducible-containers/buildkit-nix:v0.1.0@sha256:c727e0efc2a3aa23bbd31404701b5eee420ada1f08c7d4e21d666f24804355b6

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
