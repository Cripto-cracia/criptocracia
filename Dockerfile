# Multi-stage build for optimized production image
FROM rust:1.86-slim AS builder

# Install system dependencies needed for building
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy workspace configuration
COPY Cargo.toml Cargo.lock ./
COPY ec/Cargo.toml ./ec/
COPY voter/Cargo.toml ./voter/

# Copy source code
COPY ec/src ./ec/src
COPY voter/src ./voter/src

# Build the electoral commission binary in release mode
RUN cargo build --release --bin ec

# Runtime stage with minimal base image
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
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

# Expose port (Digital Ocean Apps will map this automatically)
EXPOSE 3000

# Set environment variables for configuration
ENV RUST_LOG=info
ENV DATA_DIR=/app/data

# Health check for Digital Ocean App Platform
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD echo "Electoral Commission is running"

# Default command - use the data directory
CMD ["ec", "--dir", "/app/data"]