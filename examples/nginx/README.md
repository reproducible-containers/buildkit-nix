# Example: nginx

## Usage

```bash
export DOCKER_BUILDKIT=1
docker build -t nginx-nix -f default.nix .
```

```
docker run -d -p 8080:80 --read-only --name nginx-nix nginx-nix
```

## Advanced guides
### Updating dependencies

```bash
nix-env -i niv
niv update
```

### Build with `nix-build`

```bash
nix-build
docker load < result
```
