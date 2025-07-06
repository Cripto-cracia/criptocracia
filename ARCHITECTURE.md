# Architecture

This document describes the high-level architecture and design decisions of Criptocracia, an experimental trustless electronic voting system.

## System Overview

Criptocracia implements a blind signature-based voting system using the Nostr protocol for communication. The system ensures voter anonymity, vote secrecy, and public verifiability while preventing double voting.

## Core Security Properties

1. **Vote Secrecy/Anonymity**: Voter choices remain hidden from the Electoral Commission and third parties through blind RSA signatures
2. **Voter Authentication**: Only eligible voters with registered Nostr public keys can participate
3. **Vote Uniqueness**: Each voter may cast only one valid vote, enforced through nonce tracking
4. **Verifiability/Auditability**: Electoral process and results are publicly verifiable via Nostr events

## High-Level Architecture

```
┌─────────────────┐    Nostr Protocol     ┌─────────────────┐
│                 │   (NIP-59 Gift Wrap)  │                 │
│     Voter       │◄──────────────────────┤ Electoral Comm. │
│    Client       │                       │      (EC)       │
│                 │                       │                 │
└─────────────────┘                       └─────────────────┘
         │                                         │
         │ 1. Request blind token                  │ 2. Issue blind signature
         │ 3. Cast anonymous vote                  │ 4. Verify & tally votes
         │                                         │
         ▼                                         ▼
┌─────────────────┐                       ┌─────────────────┐
│   Local State   │                       │  Election State │
│ - Nonce & Hash  │                       │ - Voter Registry│
│ - Blind Token   │                       │ - Used Tokens   │
│ - Vote Receipt  │                       │ - Vote Tallies  │
└─────────────────┘                       └─────────────────┘
                           │
                           ▼
                  ┌─────────────────┐
                  │ Nostr Relays    │
                  │ - Elections     │
                  │ - Vote Results  │
                  │ - Gift Wrapped  │
                  │   Messages      │
                  └─────────────────┘
```

## Component Architecture

### Workspace Structure

```
criptocracia/
├── ec/                 # Electoral Commission binary
│   ├── src/
│   │   ├── main.rs     # Event loop, Nostr handling
│   │   ├── election.rs # Election logic, vote processing
│   │   ├── types.rs    # Shared data structures
│   │   └── util.rs     # Key loading, logging
│   └── Cargo.toml
├── voter/              # Voter client binary
│   ├── src/
│   │   ├── main.rs     # TUI interface, voting flow
│   │   ├── election.rs # Election data parsing
│   │   ├── settings.rs # Configuration management
│   │   └── util.rs     # Crypto utilities
│   └── Cargo.toml
├── Cargo.toml          # Workspace configuration
└── data/               # Demo voter registry
```

## Cryptographic Protocol

### 1. Blind Signature Request
```
Voter:
1. Generate 128-bit random nonce
2. Compute h_n = SHA256(nonce)
3. Blind h_n using EC's RSA public key → blinded_h_n
4. Send blinded_h_n to EC via NIP-59 Gift Wrap

EC:
1. Verify voter's Nostr pubkey against authorized list
2. Sign blinded_h_n with RSA private key → blind_signature
3. Remove voter from authorized list (prevent reuse)
4. Return blind_signature via Gift Wrap
```

### 2. Vote Casting
```
Voter:
1. Unblind signature using stored blinding factor → token
2. Verify token against EC's RSA public key
3. Generate anonymous Nostr keypair
4. Package (h_n, token, blinding_factor, candidate_id)
5. Send vote via Gift Wrap with anonymous key

EC:
1. Decode vote components from Base64
2. Verify token signature on h_n
3. Check h_n hasn't been used (prevent double voting)
4. Record vote and update tally
5. Publish results to Nostr
```

## Nostr Integration

### Event Types

| Kind  | Purpose | Content | Publisher |
|-------|---------|---------|-----------|
| 35000 | Election Announcement | Election metadata, candidates, RSA pubkey | EC |
| 35001 | Vote Tally | Current vote counts | EC |
| 1059  | Gift Wrap | Encrypted voter-EC communication | Voter/EC |

### Communication Flow

1. **Election Setup**: EC publishes Kind 35000 with election details
2. **Token Request**: Voter → EC via encrypted Gift Wrap
3. **Token Response**: EC → Voter via encrypted Gift Wrap  
4. **Vote Submission**: Anonymous Voter → EC via encrypted Gift Wrap
5. **Result Updates**: EC publishes Kind 35001 after each vote

## Data Models

### Election State (EC)
```rust
struct Election {
    id: String,
    name: String,
    authorized_voters: HashSet<String>,  // Per-election registered pubkeys
    used_tokens: HashSet<BigUint>,       // Prevent double voting
    votes: Vec<u8>,                      // Candidate IDs
    candidates: Vec<Candidate>,
    start_time: u64,
    end_time: u64,
    status: Status,                      // Open/InProgress/Finished/Canceled
    rsa_pub_key: String,                 // EC's RSA public key (DER base64)
}

// EC maintains multiple elections in HashMap
Arc<Mutex<HashMap<String, Election>>>   // election_id -> Election

// Status transitions (automatic, 30s intervals):
// Open -> InProgress (when current_time >= start_time)
// InProgress -> Finished (when current_time >= end_time)
```

### Voter State
```rust
struct App {
    nonce: Option<BigUint>,              // Generated nonce
    h_n_bytes: Option<Vec<u8>>,          // Hashed nonce
    r: Option<MessageRandomizer>,        // Blinding factor
    token: Option<Signature>,            // Received blind signature
    secret: Option<Secret>,              // Unblinding secret
    election_id: Option<String>,
    candidate_id: Option<u8>,
    results: Option<Vec<(u8, u32)>>,     // Live results
    ec_rsa_pub_key: Option<RSAPublicKey>,
}
```

## Security Considerations

### Threat Model
- **Trusted**: RSA cryptography, Nostr protocol, voter device security
- **Semi-trusted**: Electoral Commission (honest-but-curious)
- **Untrusted**: Network infrastructure, relay operators

### Mitigations
- **Vote Privacy**: Blind signatures prevent EC from linking votes to voters
- **Communication Privacy**: NIP-59 Gift Wrap encrypts all voter-EC messages
- **Replay Protection**: Nonce tracking prevents vote reuse
- **Public Auditability**: All election events published to Nostr
- **Anonymous Voting**: Fresh keypairs used for vote submission

### Known Limitations
- **Single EC**: No threshold or multi-party signature scheme
- **Key Management**: RSA keys generated/managed locally
- **Network Dependency**: Requires reliable Nostr relay connectivity
- **Experimental Status**: No formal security audit or cryptographic review

## Configuration Management

### Electoral Commission
- `{dir}/elections.db`: SQLite database for elections, candidates, per-election voters, used tokens
- `ec_private.pem`: RSA private key for blind signatures (or EC_PRIVATE_KEY env var)
- `ec_public.pem`: RSA public key shared with voters (or EC_PUBLIC_KEY env var)
- Database state restoration: Elections loaded from database on startup
- Multi-election architecture: HashMap-based concurrent election support

### Voter Client  
- `~/.voter/settings.toml`: Nostr keys, EC pubkey, relay configuration
- In-memory state: Voting session data, received tokens

### Database Schema
- **elections**: id, name, start_time, end_time, status, rsa_pub_key, created_at, updated_at
- **candidates**: election_id, candidate_id, name
- **election_voters**: election_id, voter_pubkey (per-election authorization)
- **used_tokens**: election_id, token_hash (prevent double voting)

## Deployment Architecture

### Development Setup
```bash
# Generate RSA keypair for EC
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out ec_private.pem
openssl rsa -in ec_private.pem -pubout -out ec_public.pem

# Build binaries
cargo build --release

# Run Electoral Commission
./target/release/ec

# Run Voter (separate terminal)
./target/release/voter
```

### Production Considerations
- Secure RSA key generation and storage
- Voter registration process and pubkey distribution
- Relay selection and redundancy
- Election timing and coordination
- Result verification and archival

## Recent Enhancements

### Completed Features
- **Multi-Election Support**: HashMap-based architecture for concurrent elections
- **Automatic Status Transitions**: Open → InProgress → Finished based on timing
- **gRPC Admin API**: Complete election and voter management capabilities
- **Database State Restoration**: EC loads elections from database on startup
- **Per-Election Voter Management**: Voters authorized per election rather than globally
- **Automatic Nostr Publishing**: Elections created via gRPC auto-publish to Nostr
- **Streamlined RSA Key Management**: EC uses its own keys automatically

### Planned Features (from TODO)
- Registration token system for dynamic voter enrollment
- Multi-party Electoral Commission with threshold signatures
- Enhanced replay protection with timestamps
- Mobile voter application
- Formal security analysis and audit

### Scalability Improvements  
- Sharded vote processing for large elections
- Batch verification of signatures
- Distributed relay architecture
- Optimized client-side cryptographic operations