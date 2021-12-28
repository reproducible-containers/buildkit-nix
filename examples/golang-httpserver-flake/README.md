# Example: A simple http server in Go (Flake)

## Usage

```bash
export DOCKER_BUILDKIT=1
docker build -t golang-httpserver -f flake.nix .
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


#### Go modules

After updating `go.{mod,sum}`, you might need to update the `vendorSha256` value in `flake.nix`.

To obtain the new `vendorSha256` value, set `vendorSha256` value to `0000000000000000000000000000000000000000000000000000`,
and see the error log of a failed build.

e.g.,
```
error: hash mismatch in fixed-output derivation '/nix/store/qj09cvarxiwkjcs9jp02dw0gi38sm3nw-golang-httpserver-go-modules.drv':
         specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
            got:    sha256-3shhfsndjeTtpB3f2nhWBqX7jwxQiJ0caiF6Kal+MQg=
```

In this case, the new `vendorSha256` value should be set to `3shhfsndjeTtpB3f2nhWBqX7jwxQiJ0caiF6Kal+MQg=`.

(There should be some automation tool for this?)

### Build with `nix build`

```bash
nix build
docker load < result
```
