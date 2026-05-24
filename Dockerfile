# syntax=docker/dockerfile:1
#
# One multi-stage Dockerfile builds any of the three Go services.
# Select which one with:  --build-arg SERVICE=catalog|order|payment
# The whole workspace is copied so go.work resolves all modules; only the
# selected service's cmd is compiled into the final binary.

ARG GO_VERSION=1.25

# ── build stage ──────────────────────────────────────────────
FROM golang:${GO_VERSION}-alpine AS build
WORKDIR /src

# Workspace + all modules (go.work lists every module, so all must be present).
COPY go.work ./
COPY pkg/ ./pkg/
COPY services/catalog/ ./services/catalog/
COPY services/order/   ./services/order/
COPY services/payment/ ./services/payment/

ARG SERVICE
RUN test -n "$SERVICE" || (echo "ERROR: build arg SERVICE is required (catalog|order|payment)" && exit 1)

# Cache mounts speed up repeat builds without copying go.mod separately.
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    CGO_ENABLED=0 GOOS=linux \
    go build -trimpath -ldflags="-s -w" -o /out/app ./services/${SERVICE}/cmd

# ── runtime stage ────────────────────────────────────────────
# distroless static: no shell, no package manager → tiny + smaller attack surface.
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/app /app
USER nonroot:nonroot
ENTRYPOINT ["/app"]
