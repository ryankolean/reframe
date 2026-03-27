# Build stage
FROM golang:1.22-bookworm AS builder

WORKDIR /build

# Install system dependencies for CGo (SQLite, libvips)
RUN apt-get update && apt-get install -y \
    libvips-dev \
    libraw-dev \
    && rm -rf /var/lib/apt/lists/*

COPY go.mod go.sum* ./
RUN go mod download 2>/dev/null || true

COPY . .
RUN CGO_ENABLED=1 go build -o reframe ./cmd/server

# Runtime stage
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    libvips42 \
    libraw20 \
    ffmpeg \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /build/reframe .
COPY migrations/ ./migrations/

# Create data directories
RUN mkdir -p /data/database /data/originals /data/thumbnails /data/faces /data/video /data/exports /data/temp

EXPOSE 2283

ENTRYPOINT ["./reframe"]
