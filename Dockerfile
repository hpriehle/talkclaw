# Build stage
FROM swift:6.0-jammy AS builder
WORKDIR /build

# Copy shared models first (dependency)
COPY SharedModels/ SharedModels/

# Copy server source
COPY ClawAppServer/ ClawAppServer/

# Build
WORKDIR /build/ClawAppServer
RUN swift build -c release --static-swift-stdlib

# Runtime stage
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y \
    libsqlite3-0 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /build/ClawAppServer/.build/release/App ./clawapp-server

EXPOSE 8080
ENV SWIFT_LOG_LEVEL=info

ENTRYPOINT ["./clawapp-server"]
CMD ["serve", "--hostname", "0.0.0.0", "--port", "8080"]