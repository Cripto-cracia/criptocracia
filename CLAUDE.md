# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Criptocracia is an experimental, trustless electronic voting system built in Rust. It uses blind RSA signatures to ensure vote secrecy and the Nostr protocol for decentralized, encrypted message transport.

## Commands

### Build and Test Commands
```bash
# Build both binaries in release mode
cargo build --release

# Run tests
cargo test

# Build for development
cargo build

# Run specific binary
cargo run --bin ec     # Electoral Commission
cargo run --bin voter  # Voter client

# Run gRPC client example
cargo run --example grpc_client --bin ec
```

### Key Generation (for EC setup)
```bash
# Generate RSA private key (2048 bits)
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out ec_private.pem

# Extract public key
openssl rsa -in ec_private.pem -pubout -out ec_public.pem
```

### Environment Variables
```bash
# RSA key content (optional, falls back to files in current directory)
export EC_PRIVATE_KEY="$(cat ec_private.pem)"
export EC_PUBLIC_KEY="$(cat ec_public.pem)"

# Alternative: specify PEM content directly
export EC_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC...
-----END PRIVATE KEY-----"
export EC_PUBLIC_KEY="-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAyzrjKKl...
-----END PUBLIC KEY-----"

# If environment variables are not set, files are expected in the --dir directory:
# {dir}/ec_private.pem and {dir}/ec_public.pem
```

## Architecture

### Workspace Structure
- **ec/**: Electoral Commission service - manages voter registration, issues blind signatures, receives votes, tallies results
- **voter/**: Client application - requests tokens, casts votes via TUI interface
- **Shared dependencies**: blind-rsa-signatures, nostr-sdk with NIP-59 Gift Wrap, serialization utilities

### Core Components

#### Electoral Commission (ec/)
- `main.rs`: Event loop handling Nostr messages, token issuance, vote processing
- `election.rs`: Election state management, voter registration, vote tallying
- `types.rs`: Shared data structures (Candidate, Voter, Message)
- `util.rs`: Key loading, logging setup utilities
- `grpc/`: gRPC admin API for election management
  - `admin.rs`: Admin service implementation (AddVoter, AddElection, AddCandidate)
  - `server.rs`: gRPC server configuration and startup
  - `tests.rs`: Comprehensive test suite for gRPC functionality
- `database.rs`: SQLite database operations for persistent storage

#### Voter Client (voter/)
- `main.rs`: TUI interface with ratatui, handles election selection and voting
- `election.rs`: Election data parsing from Nostr events
- `settings.rs`: Configuration management via TOML files
- `util.rs`: Cryptographic utilities, EC public key parsing

### Key Data Flow
1. **Registration**: EC maintains authorized voter pubkeys in database and `voters_pubkeys.json`
2. **Token Request**: Voter blinds nonce hash, sends via NIP-59 Gift Wrap
3. **Token Issuance**: EC verifies voter authorization, issues blind signature
4. **Vote Casting**: Voter unblinds token, sends vote with anonymous keypair
5. **Result Publishing**: EC verifies tokens, tallies votes, publishes results to Nostr

### Admin API (gRPC)
- **Port**: 50001 (localhost only)
- **Services**: AddVoter, AddElection, AddCandidate, GetElection, ListVoters, ListElections
- **Authentication**: None (secure network access required)
- **Documentation**: See `GRPC_API.md` for complete API reference
- **Example Client**: Run `cargo run --example grpc_client --bin ec`

### Nostr Integration
- **Kind 35000**: Election announcements with candidate lists and RSA public keys
- **Kind 35001**: Real-time vote tallies published after each vote
- **Gift Wrap (NIP-59)**: Encrypted communication between voters and EC
- **Relay**: Uses `wss://relay.mostro.network` for message transport

### Configuration Files
- `{dir}/voters_pubkeys.json`: Authorized voter public keys in the specified directory
- `{dir}/elections.db`: SQLite database for persistent election, candidate, and voter data
- `~/.voter/settings.toml`: Voter configuration (Nostr keys, EC pubkey, relays)
- RSA key pairs: Specified via `EC_PRIVATE_KEY` and `EC_PUBLIC_KEY` environment variables (PEM content) or files in current directory

### Security Model
- Voter anonymity via blind signatures and random keypairs for vote casting
- Vote secrecy through blinding - EC cannot correlate votes to voters
- Double-voting prevention via nonce tracking
- Public verifiability through Nostr event publishing

### Development Notes
- Rust 1.86.0+ required
- Uses 2024 edition for both binaries
- Extensive test coverage in `election.rs` covering blind signature flow
- Logging to `app.log` files with configurable levels
- Error handling focuses on graceful degradation and user feedback