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

for f in "${td}"/examples/*; do
	name="$(basename "${f}")"
	echo "===== ${name} ====="
	(
		cd "$f"
		df="default.nix"
		if [[ -e "flake.nix" ]]; then
			df="flake.nix"
		fi
		sed -i '1 s/^ *# *syntax *=.*$//' "${df}"
		(
			echo "# syntax = ${image}"
			cat "${df}"
		) | sponge "${df}"
		"$DOCKER" build -t "${name}" -f "${df}" .
	)
done
