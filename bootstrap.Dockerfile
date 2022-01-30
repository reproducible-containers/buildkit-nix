ARG GOLANG_IMAGE=golang:1.17.5-alpine@sha256:4918412049183afe42f1ecaf8f5c2a88917c2eab153ce5ecf4bf2d55c1507b74
ARG NIX_IMAGE=nixos/nix:2.6.0@sha256:f085a81ca39642a405b41f45e8c21a369d89c65ca9f05d3a9b78dc5852d300ff

FROM ${GOLANG_IMAGE} AS build
WORKDIR /src
ENV CGO_ENABLED=0
RUN --mount=target=. --mount=target=/root/.cache,type=cache --mount=target=/go/pkg,type=cache \
  go build -trimpath -ldflags "-s -w" -o /out/buildkit-nix ./cmd/buildkit-nix

FROM scratch
COPY --from=build /out/ /
ARG NIX_IMAGE
ENV NIX_IMAGE=${NIX_IMAGE}
LABEL moby.buildkit.frontend.network.none="true"
ENTRYPOINT ["/buildkit-nix", "frontend"]
