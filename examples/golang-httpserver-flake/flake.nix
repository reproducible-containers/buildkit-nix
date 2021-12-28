# syntax = ghcr.io/akihirosuda/buildkit-nix:v0.0.2@sha256:ad13161464806242fd69dbf520bd70a15211b557d37f61178a4bf8e1fd39f1f2

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
