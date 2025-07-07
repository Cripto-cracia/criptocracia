# Docker Deployment Guide

This guide covers deploying the Criptocracia Electoral Commission using Docker, both locally and on Digital Ocean App Platform.

## Local Development

### Prerequisites
- Docker and Docker Compose installed
- RSA key pair generated (see main README)

### Quick Start

1. **Build and run locally:**
```bash
# Build the Docker image
docker build -t criptocracia-ec .

# Run with environment variables
docker run -d \
  -p 3000:3000 \
  -e EC_PRIVATE_KEY="$(cat ec_private.pem)" \
  -e EC_PUBLIC_KEY="$(cat ec_public.pem)" \
  -v $(pwd)/data:/app/data \
  criptocracia-ec
```

2. **Using Docker Compose:**
```bash
# Create data directory
mkdir -p data

# Set environment variables
export EC_PRIVATE_KEY="$(cat ec_private.pem)"
export EC_PUBLIC_KEY="$(cat ec_public.pem)"

# Start services
docker-compose up -d
```

### Configuration

The container expects:
- RSA keys via `EC_PRIVATE_KEY` and `EC_PUBLIC_KEY` environment variables
- Data directory mounted at `/app/data`

## Digital Ocean App Platform

### Prerequisites
- Digital Ocean account
- GitHub repository with your code
- RSA key pair generated

### Deployment Steps

1. **Prepare your repository:**
   - Ensure all Docker files are committed
   - Push to GitHub

2. **Create App on Digital Ocean:**
   - Go to Digital Ocean App Platform
   - Create new app from GitHub repository
   - Select your `criptocracia` repository
   - Choose `main` branch

3. **Configure Environment Variables:**
   In the Digital Ocean dashboard, add these environment variables:
   - `EC_PRIVATE_KEY`: Your RSA private key PEM content (mark as encrypted)
   - `EC_PUBLIC_KEY`: Your RSA public key PEM content (mark as encrypted)
   - `RUST_LOG`: Set to `info`

### Alternative: Use App Spec

You can also deploy using the included `.do/app.yaml` specification:

```bash
# Install doctl CLI
# Configure with your Digital Ocean API token
doctl apps create --spec .do/app.yaml
```

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `EC_PRIVATE_KEY` | RSA private key in PEM format | Yes |
| `EC_PUBLIC_KEY` | RSA public key in PEM format | Yes |
| `RUST_LOG` | Log level (trace, debug, info, warn, error) | No (default: info) |
| `DATA_DIR` | Directory for application data | No (default: /app/data) |

## Security Notes

- RSA keys are loaded from environment variables for security
- Container runs as non-root user
- Use Digital Ocean's secret management for production
- Regularly rotate RSA keys
- Monitor logs for suspicious activity

## Troubleshooting

### Common Issues

1. **Container won't start:**
   - Check that environment variables are set correctly
   - Verify RSA key format (must include headers/footers)
   - Check logs: `docker logs <container_id>`

2. **Network issues:**
   - Verify port 3000 is accessible
   - Check firewall settings
   - Ensure Nostr relay connectivity

### Health Check

The container includes a health check that runs every 30 seconds. You can manually check:

```bash
docker exec <container_id> echo "Electoral Commission is running"
```

## Scaling

For production deployment:
- Consider using Digital Ocean's database for persistence
- Set up monitoring and alerting
- Implement log aggregation
- Use load balancers for high availability
- Set up backup strategies for election data