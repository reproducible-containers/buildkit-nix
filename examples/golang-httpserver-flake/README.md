# Example: A simple http server in Go (Flake)

## Usage

```bash
export DOCKER_BUILDKIT=1
docker build -t golang-httpserver -f default.nix .
```

```
docker run -d -p 8080:80 --read-only --name golang-httpserver golang-httpserver
```

## Advanced guides
### Updating dependencies

```bash
nix flake update --override-input nixpkgs github:NixOS/nixpkgs/master
```

You might have to create `~/.config/nix/nix.conf` with the following content:
```
experimental-features = nix-command flakes
```

### Build with `nix build`

```bash
nix build
docker load < result
```
