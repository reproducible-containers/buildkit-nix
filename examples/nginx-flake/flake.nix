# syntax = ghcr.io/akihirosuda/buildkit-nix:v0.0.2@sha256:ad13161464806242fd69dbf520bd70a15211b557d37f61178a4bf8e1fd39f1f2

{
  outputs = { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
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
    in with pkgs; {
      defaultPackage.x86_64-linux = dockerTools.buildImage {
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
          };
        };
      };
    };
}
