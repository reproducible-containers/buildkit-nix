# syntax = ghcr.io/reproducible-containers/buildkit-nix:v0.1.0@sha256:c727e0efc2a3aa23bbd31404701b5eee420ada1f08c7d4e21d666f24804355b6

{
  inputs.flake-utils.url = "github:numtide/flake-utils";
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        # See https://ryantm.github.io/nixpkgs/languages-frameworks/go/
        app = pkgs.buildGoModule {
          name = "golang-httpserver";
          src = ./.;
          vendorSha256 = "FdDIvZrvGFHk7aqjLtJsiqsIHM6lob9iNPLd7ITau7o=";
          runVend = true;
        };
      in rec {
        defaultPackage = pkgs.dockerTools.buildImage {
          name = "golang-httpserver";
          tag = "nix";
          contents = [ pkgs.bash pkgs.coreutils app ];
          config = {
            Cmd = [ "golang-httpserver" ];
            ExposedPorts = { "80/tcp" = { }; };
          };
        };
      });
}
