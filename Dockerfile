# ── Frontend build ───────────────────────────────────────────────────────────
FROM oven/bun:1 AS frontend-builder

WORKDIR /frontend
COPY frontend/ .
RUN bun install --frozen-lockfile
RUN bunx vite build

# ── Backend build ────────────────────────────────────────────────────────────
FROM golang:1.26-alpine AS backend-builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

ARG VERSION=dev
ARG COMMIT=none
ARG BUILD_DATE=unknown

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w -X 'main.Version=${VERSION}' -X 'main.Commit=${COMMIT}' -X 'main.BuildDate=${BUILD_DATE}'" -o ./CLIProxyAPI ./cmd/server/

# ── Runtime ──────────────────────────────────────────────────────────────────
FROM alpine:3.22.0

RUN apk add --no-cache tzdata ca-certificates

RUN mkdir -p /CLIProxyAPI/panel

COPY --from=backend-builder /app/CLIProxyAPI /CLIProxyAPI/CLIProxyAPI
COPY --from=frontend-builder /frontend/dist/ /CLIProxyAPI/panel/

COPY config.example.yaml /CLIProxyAPI/config.example.yaml

WORKDIR /CLIProxyAPI

EXPOSE 8317

ENV TZ=Asia/Shanghai
ENV MANAGEMENT_PANEL_DIR=/CLIProxyAPI/panel

RUN cp /usr/share/zoneinfo/${TZ} /etc/localtime && echo "${TZ}" > /etc/timezone

CMD ["./CLIProxyAPI"]