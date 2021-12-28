# Example: nginx (Flake)

## Usage

```bash
export DOCKER_BUILDKIT=1
docker build -t nginx-nix -f flake.nix .
```

```
docker run -d -p 8080:80 --name nginx-nix nginx-nix
```

## Updating dependencies

```bash
nix flake update --override-input nixpkgs github:NixOS/nixpkgs/master
```

You might have to create `~/.config/nix/nix.conf` with the following content:
```
experimental-features = nix-command flakes
```
