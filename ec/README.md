# Electoral Commission (EC)

![logo](../logo.png)

*Disclaimer: The author is NOT a cryptographer and this work has not been reviewed. This means that there is very likely a fatal flaw somewhere. Criptocracia is still experimental and not production-ready.*

The Electoral Commission is the central authority in the Criptocracia voting system, responsible for managing elections, issuing anonymous voting tokens, and maintaining voter privacy through blind signatures.

## Features

- **Multi-election support**: Manage multiple concurrent elections
- **gRPC admin API**: Complete election management interface
- **Database persistence**: SQLite storage for elections, candidates, and voters
- **Automatic status transitions**: Elections progress Open → InProgress → Finished
- **Blind signature voting**: Anonymous token issuance with double-vote prevention
- **Nostr integration**: Publish election announcements and real-time results
- **Docker deployment**: Container-ready for cloud deployment

## Quick Start

### Prerequisites

- Rust 1.86.0+
- OpenSSL (for RSA key generation)
- SQLite development libraries
- Protocol Buffers compiler

### Installation

```bash
# Install system dependencies (Ubuntu/Debian)
sudo apt update
sudo apt install -y cmake build-essential libsqlite3-dev pkg-config libssl-dev protobuf-compiler ca-certificates

# Clone and build from workspace root
git clone https://github.com/grunch/criptocracia.git
cd criptocracia
cargo build --release
```

### Setup

1. **Generate RSA keypair** (for blind signatures):
   ```bash
   openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out ec_private.pem
   openssl rsa -in ec_private.pem -pubout -out ec_public.pem
   ```

2. **Configure environment**:
   ```bash
   # Required: EC's Nostr identity
   export NOSTR_PRIVATE_KEY="your_ec_nostr_private_key_in_hex"
   
   # Optional: RSA keys (uses files if not set)
   export EC_PRIVATE_KEY="$(cat ec_private.pem)"
   export EC_PUBLIC_KEY="$(cat ec_public.pem)"
   
   # Optional: gRPC access control
   export GRPC_BIND_IP="127.0.0.1"  # Localhost only (secure default)
   export GRPC_BIND_IP="0.0.0.0"    # External access (less secure)
   ```

3. **Start the Electoral Commission**:
   ```bash
   ./target/release/ec
   ```

## gRPC Admin API

The EC provides a comprehensive gRPC API for election management on port 50001.

### Available Methods

| Method | Description | Parameters |
|--------|-------------|------------|
| `AddElection` | Create new election | name, start_time, duration, candidates |
| `AddCandidate` | Add candidate to election | election_id, candidate_id, name |
| `AddVoter` | Register voter for election | election_id, name, pubkey (hex/npub) |
| `CancelElection` | Cancel ongoing election | election_id |
| `GetElection` | Get election details | election_id |
| `ListElections` | List all elections | limit, offset |
| `ListVoters` | List election voters | election_id, limit, offset |

### Example Usage

```bash
# Run the interactive gRPC client
cargo run --example grpc_client --bin ec

# Or use external gRPC tools
grpcurl -plaintext localhost:50001 admin.AdminService/ListElections
```

### External gRPC Client Dependencies

To connect from an external Rust project:

```toml
[dependencies]
tonic = "0.12"
prost = "0.13"
tokio = { version = "1.0", features = ["macros", "rt-multi-thread"] }

[build-dependencies]
tonic-build = "0.12"
```

## Database Schema

The EC uses SQLite with persistent storage:

- **elections**: Election metadata (id, name, status, times)
- **candidates**: Candidate information per election
- **voters**: Authorized voter pubkeys per election
- **votes**: Vote tracking and nonce management

## Election Management

### Election Status Flow

1. **Open**: Election created, accepting voter registrations
2. **InProgress**: Voting period active (auto-transition at start_time)
3. **Finished**: Voting ended, final results published (auto-transition at end_time)
4. **Cancelled**: Election cancelled via admin API

### Automatic Status Transitions

The EC automatically transitions elections based on time:
- **Open → InProgress**: At `start_time`
- **InProgress → Finished**: At `start_time + duration`
- Status checks run every 30 seconds

## Security Configuration

### Network Access

- **Default**: gRPC binds to `127.0.0.1:50001` (localhost only)
- **External access**: Set `GRPC_BIND_IP=0.0.0.0` (requires network security)
- **Custom binding**: Set `GRPC_BIND_IP` to specific IP address

### Key Management

- **RSA keys**: Required for blind signature operations
- **Nostr keys**: Required for EC identity and publishing
- **Environment variables**: Preferred for production deployment
- **File fallback**: Uses `ec_private.pem` and `ec_public.pem` if env vars not set

## Docker Deployment

### Build and Run

```bash
# Build container
docker build -t criptocracia-ec .

# Run with required environment
docker run -d \
  -e NOSTR_PRIVATE_KEY="your_nostr_key" \
  -e GRPC_BIND_IP="0.0.0.0" \
  -p 50001:50001 \
  -v $(pwd)/data:/app/data \
  criptocracia-ec
```

### Production Considerations

- Mount persistent volume for SQLite database
- Use Docker secrets for sensitive environment variables
- Configure proper firewall rules for gRPC access
- Monitor logs and database size

## Troubleshooting

### Common Issues

1. **Database readonly error**:
   ```bash
   # Kill competing processes
   pkill -f "target/release/ec"
   # Ensure database permissions
   chmod 644 elections.db
   ```

2. **gRPC connection refused**:
   ```bash
   # Check if EC is running
   netstat -tlnp | grep 50001
   # Verify binding configuration
   echo $GRPC_BIND_IP
   ```

3. **RSA key loading failed**:
   ```bash
   # Check file existence
   ls -la ec_*.pem
   # Verify environment variables
   echo $EC_PRIVATE_KEY | head -c 50
   ```

4. **Nostr connection issues**:
   ```bash
   # Check relay connectivity
   curl -I wss://relay.mostro.network
   # Verify NOSTR_PRIVATE_KEY format
   echo $NOSTR_PRIVATE_KEY | wc -c  # Should be 64 characters
   ```

### Debug Logging

Logs are written to `app.log` in the current directory:

```bash
# Monitor real-time logs
tail -f app.log

# Search for specific events
grep "Election status" app.log
grep "gRPC" app.log
grep "Vote received" app.log
```

## Development

### Build Commands

```bash
# Development build
cargo build

# Release build
cargo build --release

# Run tests
cargo test

# Code quality
cargo clippy
cargo fmt

# Protocol buffer regeneration
cargo clean && cargo build
```

### Testing

```bash
# Run all tests
cargo test

# Run specific test module
cargo test grpc

# Run with output
cargo test -- --nocapture
```
