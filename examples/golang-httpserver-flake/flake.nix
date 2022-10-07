# syntax = ghcr.io/akihirosuda/buildkit-nix:v0.0.3@sha256:ecc6f051398441038af21186c2e23feed443efc3941c7567e3c113107712f103

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
