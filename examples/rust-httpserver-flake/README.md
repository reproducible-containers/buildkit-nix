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

To obtain the new `cargoSha256` value, set `cargoSha256` value to `0000000000000000000000000000000000000000000000000000`,
and see the error log of a failed build.

e.g.,
```
error: hash mismatch in fixed-output derivation '/nix/store/68r9m67jx8z86fx91cd93fm3npbr945y-rust-httpserver-vendor.tar.gz.drv':
         specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
            got:    sha256-N8HCmBEiIX5G3F2OQH5IvkzpwhCJVpR51TB86gV9IAo=
```

In this case, the new `cargoSha256` value should be set to `N8HCmBEiIX5G3F2OQH5IvkzpwhCJVpR51TB86gV9IAo=`.

(There should be some automation tool for this?)

### Build with `nix build`

```bash
nix build
docker load < result
```
