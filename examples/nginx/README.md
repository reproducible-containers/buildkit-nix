# Example: nginx

## Usage

```bash
export DOCKER_BUILDKIT=1
docker build -t nginx-nix -f default.nix .
```

```
docker run -d -p 8080:80 --name nginx-nix nginx-nix
```

## Updating dependencies

```bash
nix-env -i niv
niv update
```
