# Multi-stage build for optimized production image
FROM rust:1.86-slim AS builder

# Install system dependencies needed for building (including protobuf for gRPC)
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    ca-certificates \
    protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy workspace files  
COPY Cargo.toml Cargo.lock ./
COPY ec/Cargo.toml ./ec/
COPY voter/Cargo.toml ./voter/

# Copy EC source code and build files
COPY ec/src ./ec/src
COPY ec/build.rs ./ec/
COPY ec/proto ./ec/proto

# Create minimal voter stub to satisfy workspace requirements
RUN mkdir -p voter/src && echo 'fn main() {}' > voter/src/main.rs

# Copy examples for testing
COPY examples ./examples

# Build only the EC package (no workspace modification needed)
RUN cargo build --release --package ec

# Runtime stage with minimal base image
FROM debian:bookworm-slim

# Install runtime dependencies (including net-tools for health check)
RUN apt-get update && apt-get install -y \
    ca-certificates \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for security
RUN useradd --create-home --shell /bin/bash ec

# Set working directory
WORKDIR /app

# Copy the built binary from builder stage
COPY --from=builder /app/target/release/ec /usr/local/bin/ec

# Create data directory and set ownership
RUN mkdir -p /app/data && chown -R ec:ec /app

# Switch to non-root user
USER ec

# Expose gRPC admin API port
EXPOSE 50001

# Set environment variables for configuration
ENV RUST_LOG=info
ENV DATA_DIR=/app/data

# RSA keys should be provided via secure methods:
# 1. File mounts (recommended): -v /host/keys:/app/data:ro
# 2. Docker secrets (production): --secret source=ec_private_key,target=/app/data/ec_private.pem
# 3. Never use environment variables for private key material

# Health check for gRPC API availability
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD netstat -an | grep -q ":50001.*LISTEN" || exit 1

# Default command - use the data directory
CMD ["ec", "--dir", "/app/data"]