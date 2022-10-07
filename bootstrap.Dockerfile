ARG GOLANG_IMAGE=golang:1.19.2-alpine@sha256:9d3bd0937054ed71c04839c909aec4736b1a83a96010826cfeed4abed12acf59
ARG NIX_IMAGE=nixos/nix:2.11.1@sha256:d8c6b97091d6944dd773c3c239899af047077dbf5411ef229bb50e5b21404b0d

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
