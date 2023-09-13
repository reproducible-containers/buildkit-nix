ARG GOLANG_IMAGE=golang:1.21.1-alpine@sha256:96634e55b363cb93d39f78fb18aa64abc7f96d372c176660d7b8b6118939d97b
ARG NIX_IMAGE=nixos/nix:2.17.0@sha256:a186d0501304e87751280b7b6ad62b54b9d08b8c5c63b9752eac408e1159c340

FROM --platform=${BUILDPLATFORM} ${GOLANG_IMAGE} AS build
WORKDIR /src
ENV CGO_ENABLED=0
ARG TARGETOS
ARG TARGETARCH
RUN --mount=target=. --mount=target=/root/.cache,type=cache --mount=target=/go/pkg,type=cache \
  GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -ldflags "-s -w" -o /out/buildkit-nix ./cmd/buildkit-nix

FROM scratch
COPY --from=build /out/ /
ARG NIX_IMAGE
ENV NIX_IMAGE=${NIX_IMAGE}
LABEL moby.buildkit.frontend.network.none="true"
ENTRYPOINT ["/buildkit-nix", "frontend"]
