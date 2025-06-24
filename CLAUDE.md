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
```

### Key Generation (for EC setup)
```bash
# Generate RSA private key (2048 bits)
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out ec_private.pem

# Extract public key
openssl rsa -in ec_private.pem -pubout -out ec_public.pem
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

#### Voter Client (voter/)
- `main.rs`: TUI interface with ratatui, handles election selection and voting
- `election.rs`: Election data parsing from Nostr events
- `settings.rs`: Configuration management via TOML files
- `util.rs`: Cryptographic utilities, EC public key parsing

### Key Data Flow
1. **Registration**: EC maintains authorized voter pubkeys in `voters_pubkeys.json`
2. **Token Request**: Voter blinds nonce hash, sends via NIP-59 Gift Wrap
3. **Token Issuance**: EC verifies voter authorization, issues blind signature
4. **Vote Casting**: Voter unblinds token, sends vote with anonymous keypair
5. **Result Publishing**: EC verifies tokens, tallies votes, publishes results to Nostr

### Nostr Integration
- **Kind 35000**: Election announcements with candidate lists and RSA public keys
- **Kind 35001**: Real-time vote tallies published after each vote
- **Gift Wrap (NIP-59)**: Encrypted communication between voters and EC
- **Relay**: Uses `wss://relay.mostro.network` for message transport

### Configuration Files
- `ec/voters_pubkeys.json`: Authorized voter public keys
- `~/.voter/settings.toml`: Voter configuration (Nostr keys, EC pubkey, relays)
- RSA key pairs: `ec_private.pem` and `ec_public.pem` for blind signatures

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