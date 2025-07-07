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
# Nostr private key (required) - hex format
export NOSTR_PRIVATE_KEY="e3f33350728580cd51db8f4048d614910d48a5c0d7f1af6811e83c07fc865a5c"

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

# If RSA environment variables are not set, files are expected in the --dir directory:
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
1. **Election Creation**: Elections created via gRPC admin API, automatically published to Nostr
2. **Voter Registration**: Voters added per-election via gRPC, stored in database and in-memory election state  
3. **Status Transitions**: Elections automatically transition Open → InProgress → Finished based on timing (30s intervals)
4. **Token Request**: Voter blinds nonce hash, sends via NIP-59 Gift Wrap
5. **Token Issuance**: EC verifies voter authorization per election, issues blind signature
6. **Vote Casting**: Voter unblinds token, sends vote with anonymous keypair
7. **Result Publishing**: EC verifies tokens, tallies votes, publishes results to Nostr

### Admin API (gRPC)
- **Port**: 50001 (localhost only)
- **Services**: AddVoter, AddElection, AddCandidate, GetElection, ListVoters, ListElections
- **Per-Election Voters**: Voters are managed per election (requires election_id)
- **Automatic RSA Keys**: Elections use EC's RSA key automatically (no parameter needed)
- **Auto Nostr Publishing**: Elections created via gRPC are automatically published to Nostr
- **Authentication**: None (secure network access required)
- **Documentation**: See `GRPC_API.md` for complete API reference
- **Example Client**: Run `cargo run --example grpc_client --bin ec`

### Nostr Integration
- **Kind 35000**: Election announcements with candidate lists and RSA public keys
- **Kind 35001**: Real-time vote tallies published after each vote
- **Gift Wrap (NIP-59)**: Encrypted communication between voters and EC
- **Relay**: Uses `wss://relay.mostro.network` for message transport

### Configuration Files
- `{dir}/elections.db`: SQLite database for persistent election, candidate, and per-election voter data
- `~/.voter/settings.toml`: Voter configuration (Nostr keys, EC pubkey, relays)
- RSA key pairs: Specified via `EC_PRIVATE_KEY` and `EC_PUBLIC_KEY` environment variables (PEM content) or files in current directory

### Election Management
- **Multi-Election Support**: System supports multiple concurrent elections via HashMap architecture
- **Database State Restoration**: EC loads elections from database on startup (no demo data)
- **Automatic Status Transitions**: Elections transition Open → InProgress → Finished based on start/end times
- **Status Check Interval**: 30-second periodic timer checks all elections for status changes
- **Nostr Publishing**: Status changes automatically trigger Nostr event publishing

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