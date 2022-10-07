# syntax = ghcr.io/akihirosuda/buildkit-nix:v0.0.3@sha256:ecc6f051398441038af21186c2e23feed443efc3941c7567e3c113107712f103

# Hints:
# - https://nix.dev/tutorials/building-and-running-docker-images
# - https://nixos.org/manual/nixpkgs/stable/#ssec-pkgs-dockerTools-buildImage
# - https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/docker/examples.nix
# - https://nix.dev/tutorials/towards-reproducibility-pinning-nixpkgs

{ sources ? import ./nix/sources.nix, pkgs ? import sources.nixpkgs { } }:
let
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
in pkgs.dockerTools.buildImage {
  name = "nginx";
  tag = "nix";
  contents = [
    # fakeNss creates /etc/passwd and /etc/group (https://github.com/NixOS/nixpkgs/blob/e548124f/pkgs/build-support/docker/default.nix#L741-L763)
    pkgs.dockerTools.fakeNss
    pkgs.bash
    pkgs.coreutils
    pkgs.gnugrep
    pkgs.nginx
    (pkgs.writeTextDir "${pkgs.nginx}/html/index.html" ''
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
}
