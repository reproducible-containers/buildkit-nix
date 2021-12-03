#!/usr/bin/env bash
set -eux -o pipefail
timestamp="$(date +%s)"

: "${DOCKER:=docker}"
export DOCKER_BUILDKIT=1

version="$(git describe --match 'v[0-9]*' --dirty='.m' --always --tags)"
td="/tmp/buildkit-nix-test-${version}-${timestamp}"
mkdir -p "${td}"
trap 'rm -rf ${td}' EXIT
cp -a examples "${td}"

"$DOCKER" rm -f reg || true
"$DOCKER" run -d --name reg -p 127.0.0.1:5000:5000 docker.io/library/registry:2

image="127.0.0.1:5000/buildkit-nix:test-${version}-${timestamp}"
"$DOCKER" build -t "$image" -f bootstrap.Dockerfile .
"$DOCKER" push "$image"

(
	cd "${td}/examples/nginx"
	sed -i '1 s/^ *# *syntax *=.*$//' default.nix
	(
		echo "# syntax = ${image}"
		cat default.nix
	) | sponge default.nix
	"$DOCKER" build -t nginx-nix -f default.nix .
)
