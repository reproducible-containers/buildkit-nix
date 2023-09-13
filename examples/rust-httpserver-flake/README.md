# Example: A simple http server in Rust (Flake)

## Usage

```bash
export DOCKER_BUILDKIT=1
docker build -t rust-httpserver -f flake.nix .
```

```
docker run -d -p 8080:80 --read-only --name rust-httpserver rust-httpserver
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

#### Cargo

After updating `Cargo.{toml,lock}`, you might need to update the `cargoSha256` value in `flake.nix`.

To obtain the new `cargoHash` value, set `cargoHash` value to an empty string,
and see the error log of a failed build.

e.g.,
```
error: hash mismatch in fixed-output derivation '/nix/store/rd4z5iz7sn8rlj3wr0y3y2kqch723xq9-rust-httpserver-vendor.tar.gz.drv':
         specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
            got:    sha256-c7dAXdlwIy9t/UufyyjDdZOMoAwRqphkYghp2aKW45U=
```

In this case, the new `cargoHash` value should be set to `sha256-c7dAXdlwIy9t/UufyyjDdZOMoAwRqphkYghp2aKW45U=`.

(There should be some automation tool for this?)

### Build with `nix build`

```bash
nix build
docker load < result
```
