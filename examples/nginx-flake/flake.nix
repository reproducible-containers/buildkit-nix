# syntax = ghcr.io/reproducible-containers/buildkit-nix:v0.1.1@sha256:7d4c42a5c6baea2b21145589afa85e0862625e6779c89488987266b85e088021

{
  inputs.flake-utils.url = "github:numtide/flake-utils";
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        entrypoint = pkgs.writeScript "docker-entrypoint.sh" ''
          #!${pkgs.stdenv.shell}
          set -eux -o pipefail
          # Create "nogroup" group
          if ! grep -q ^nogroup /etc/group; then
            # dereference symlink (/etc/group -> /nix/....) to support `docker run --read-only`
            cp -aL /etc/group /etc/group.real
            echo nogroup:x:65534: >>/etc/group.real
            rm -f /etc/group
            mv /etc/group.real /etc/group
          fi
          # Initialize /var
          mkdir -p /var/log/nginx /var/cache/nginx/client_body
          exec nginx -g "daemon off; error_log /dev/stderr debug;"
        '';
      in with pkgs; rec {
        defaultPackage = dockerTools.buildImage {
          name = "nginx";
          tag = "nix";
          contents = [
            # fakeNss creates /etc/passwd and /etc/group (https://github.com/NixOS/nixpkgs/blob/e548124f/pkgs/build-support/docker/default.nix#L741-L763)
            dockerTools.fakeNss
            bash
            coreutils
            gnugrep
            nginx
            (writeTextDir "${pkgs.nginx}/html/index.html" ''
              <html><body>hello nix</body></html>
            '')
          ];
          # runAsRoot cannot be used because it depends on KVM.
          # extraCommands can be used but often fails unless running everything as the root.
          # https://discourse.nixos.org/t/dockertools-buildimage-and-user-writable-tmp/5397
          config = {
            Cmd = [ entrypoint ];
            ExposedPorts = { "80/tcp" = { }; };
            Volumes = {
              "/etc" = { };
              "/var" = { };
              "/tmp" = { };
            };
          };
        };
      });
}
