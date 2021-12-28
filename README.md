# BuildKit-Nix: Nix as Dockerfiles (`docker build -f default.nix .`)

BuildKit-Nix allows using Nix derivations (`default.nix`, `flake.nix`) as Dockerfiles.

## Examples

Legacy (with Niv):
- [`./examples/nginx/default.nix`](./examples/nginx/default.nix): Nginx

Flakes:
- [`./examples/nginx-flake/flake.nix`](./examples/nginx-flake/flake.nix): Nginx
- [`./examples/golang-httpserver-flake/flake.nix`](./examples/golang-httpserver-flake/flake.nix): A simple http server in Go

## Usage
### With Docker

Requires Docker 20.10 or later.

```
cd examples/nginx
export DOCKER_BUILDKIT=1
docker build -t nginx-nix -f default.nix .
docker run -d -p 8080:80 --name nginx-nix nginx-nix
```

The digest of _the contents of the image_ is reproducible:
```
docker exec nginx-nix cat /.buildkit-nix/result.gunzipped.digest
```

Note: While the digest of _the contents of the image_ is reproducible (as long as Nix can reproduce it),
the digest of _the image itself_ might not be always reproducible, due to potential non-determinism of gzip (and possibly other misc stuffs inside BuildKit).

### With nerdctl

```
cd examples/nginx
nerdctl build -t nginx-nix -f default.nix .
```

### With buildctl

```
cd examples/nginx
buildctl build --frontend dockerfile.v0 --local dockerfile=. --local context=. --opt filename=default.nix
```
