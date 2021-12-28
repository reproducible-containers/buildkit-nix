# syntax = ghcr.io/akihirosuda/buildkit-nix:latest

{
  outputs = { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    with pkgs; {
      defaultPackage.x86_64-linux = dockerTools.buildImage {
        name = "nginx";
        tag = "nix";
        contents = [
          # fakeNss creates /etc/passwd and /etc/group (https://github.com/NixOS/nixpkgs/blob/e548124f/pkgs/build-support/docker/default.nix#L741-L763)
          dockerTools.fakeNss
          bash
          coreutils
          nginx
          (writeTextDir "${pkgs.nginx}/html/index.html" ''
            <html><body>hello nix</body></html>
          '')
        ];
        # Use extraCommands, not runAsRoot, to avoid dependency on KVM
        extraCommands = "
          grep -q ^nogroup etc/group || echo nogroup:x:65534: >>etc/group
          mkdir -p var/log/nginx var/cache/nginx/client_body
        ";
        config = {
          Cmd = [ "nginx" "-g" "daemon off; error_log /dev/stderr debug;" ];
          ExposedPorts = {
            "80/tcp" = { };
          };
        };
      };
    };
}
