# Criptocracia

![logo](logo.png)

*Disclaimer: The author is NOT a cryptographer and this work has not been reviewed. This means that there is very likely a fatal flaw somewhere. Criptocracia is still experimental and not production-ready.*

**Criptocracia** is an experimental, trustless open-source electronic voting system built in Rust. It leverages blind RSA signatures to ensure vote secrecy, voter anonymity and integrity, and uses the Nostr protocol for decentralized, encrypted message transport.

## Quick Start

### Prerequisites

- Rust 1.86.0 or later
- OpenSSL (for RSA key generation)
- SQLite development libraries
- Protocol Buffers compiler (for gRPC)

### Installation

```bash
# Clone the repository
git clone https://github.com/grunch/criptocracia.git
cd criptocracia

# Install system dependencies (Ubuntu/Debian)
sudo apt update
sudo apt install -y cmake build-essential libsqlite3-dev pkg-config libssl-dev protobuf-compiler ca-certificates

# Build the project
cargo build --release
```

### Running the Electoral Commission

1. **Generate RSA keys** (required for blind signatures):
   ```bash
   # Generate RSA private key (2048 bits)
   openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out ec_private.pem
   
   # Extract public key
   openssl rsa -in ec_private.pem -pubout -out ec_public.pem
   ```

2. **Set environment variables**:
   ```bash
   # Required: Nostr private key for EC identity
   export NOSTR_PRIVATE_KEY="your_nostr_private_key_here"
   
   # Optional: RSA keys (falls back to files in current directory)
   export EC_PRIVATE_KEY="$(cat ec_private.pem)"
   export EC_PUBLIC_KEY="$(cat ec_public.pem)"
   
   # Optional: gRPC server binding (default: 127.0.0.1 for localhost only)
   export GRPC_BIND_IP="0.0.0.0"  # For external access
   ```

3. **Start the Electoral Commission**:
   ```bash
   ./target/release/ec
   ```

### Running the Voter Client

1. **Configure voter settings**:
   ```bash
   mkdir -p ~/.voter
   # Edit ~/.voter/settings.toml with your configuration
   ```

2. **Start the voter client**:
   ```bash
   ./target/release/voter
   ```

### gRPC Admin API

The EC provides a gRPC API for election management on port 50001:

```bash
# Run the example gRPC client
cargo run --example grpc_client --bin ec
```

Available operations:
- **AddElection**: Create new elections
- **AddCandidate**: Add candidates to elections
- **AddVoter**: Register voters for specific elections
- **CancelElection**: Cancel ongoing elections
- **GetElection**: Retrieve election details
- **ListElections**: List all elections
- **ListVoters**: List voters for an election

## Context
The critical need for secure, transparent, and anonymous electronic‑voting systems is becoming ever more pressing, especially in settings where trust in central authorities is limited—addressing concerns that authoritarian regimes may use electoral systems to stay in power. The historical challenges of electoral fraud underscore the importance of exploring robust solutions. Modern cryptography provides powerful tools for building systems that can withstand manipulation and allow for public verification.

## Goal
The goal of leveraging open technologies such as the Rust programming language and the Nostr protocol, along with cryptographic techniques (initially, blind signatures), to develop a fraud-resistant and publicly auditable voting system is recognized.

## Fundamental Requirements
Derived from the initial consultation, the key security properties for this system are:
- Vote Secrecy/Anonymity: Voter choices must remain hidden from the Electoral Commission (EC) and third parties.
- Voter Authentication: Only eligible voters, identified by their Nostr public keys, are eligible to participate.
- Vote Uniqueness: Each voter may cast only one valid vote.
- Verifiability/Auditability: The electoral process and results must be publicly verifiable without compromising the identity of the voter, minimizing the trust required in the central tallying authority. (This central tallying authority may be comprised of a committee composed of a representative from each voting option.)
- Nostr's Role: Nostr is proposed as the underlying communication layer. Its decentralized, public/private event-based features can be used for both vote transmission and the implementation of a public bulletin board. Features such as NIP-59 Gift Wrap are used to encrypt data during transmission, protecting the confidentiality of the vote in transit.

## Voters
Registered users with a Nostr key pair (public and private). The public key (voter_pk) identifies the voter to the Electoral Commission.

## Electoral Commission (EC)

The EC is the central authority that manages elections and maintains voter anonymity through blind signatures:

### Key Features
- **Multi-election support**: Manages multiple concurrent elections via HashMap architecture
- **Database persistence**: SQLite database for elections, candidates, and voters
- **Automatic status transitions**: Elections progress from Open → InProgress → Finished automatically
- **Blind signature voting**: Issues anonymous voting tokens while preventing double voting
- **Real-time tallying**: Publishes vote counts to Nostr after each vote
- **gRPC admin API**: Complete election management interface
- **Nostr integration**: Publishes election announcements and results

### Election Status Flow
1. **Open**: Election created, voters can request tokens
2. **InProgress**: Voting period active (automatically transitions based on start_time)
3. **Finished**: Voting ended, final results published (based on end_time)
4. **Cancelled**: Election cancelled via admin API

### Data Storage
- **elections.db**: SQLite database with election, candidate, and voter data
- **voters_pubkeys.json**: Legacy voter authorization file (database takes precedence)
- **app.log**: Application logs with configurable verbosity

## Nostr: Communication protocol used for:
- Requesting blind signatures (via NIP-59 Gift Wrap).
- Casting encrypted votes (via NIP-59 Gift Wrap).

## Architecture

Criptocracia is organized as a Cargo workspace containing two main binaries:

* **ec**: The Electoral Commission service that manages multiple elections, registers voters per election, issues blind signatures on voting tokens, receives anonymized votes, verifies them, and publishes results. Includes gRPC admin API.
* **voter**: The client-side application used by registered voters to request a blind-signed token, unblind it, and cast their vote.

Shared workspace dependencies include:

* `blind-rsa-signatures v0.15.2` for RSA-based blind signature operations.
* `nostr-sdk v0.41.0` (feature `nip59`) for Gift Wrap message encryption and transport.
* `base64`, `num-bigint-dig`, `sha2`, and other utility crates for serialization and hashing.

---

## Cryptographic Protocol

1. **Blind Signature Request**

   * Voter generates a random nonce (128-bit BigUint) and computes `h_n = SHA256(nonce)`.
   * Voter blinds `h_n` using the EC's RSA public key to obtain `blinded_h_n` and a blinding factor.
   * `blinded_h_n` is Base64-encoded and sent to the EC via an encrypted Nostr Gift Wrap message.

2. **Blind Signature Issuance**

   * EC verifies the sender’s Nostr public key against the authorized voter list.
   * EC uses its RSA secret key to sign `blinded_h_n`, producing a blind signature.
   * EC encodes the blind signature in Base64 and returns it via Gift Wrap.

3. **Unblinding and Voting**

   * Voter decodes the blind signature, unblinds it using the stored blinding factor, and verifies the resulting token against the EC’s public RSA key.
   * The voter packages `(h_n, token, blinding_factor, candidate_id)` into a colon-delimited payload, Base64-encodes the first three parts, and sends via Gift Wrap with a freshly generated Nostr key pair to anonymize origin.

4. **Vote Reception and Tally**

   * EC receives the vote payload, decodes `h_n`, `token`, and `blinding_factor` from Base64, and parses `candidate_id`.
   * EC verifies the signature on `h_n` and checks that `h_n` has not been used before (prevents double voting).
   * Valid votes are recorded, tallied, and results published to Nostr as a custom event.

---

## Configuration

### Environment Variables

#### Required
- `NOSTR_PRIVATE_KEY`: The EC's Nostr private key (hex format)

#### Optional
- `EC_PRIVATE_KEY`: RSA private key content (PEM format)
- `EC_PUBLIC_KEY`: RSA public key content (PEM format)
- `GRPC_BIND_IP`: gRPC server bind address (default: 127.0.0.1)

#### RSA Key Loading Priority
1. Environment variables (`EC_PRIVATE_KEY`, `EC_PUBLIC_KEY`)
2. Files in current directory (`ec_private.pem`, `ec_public.pem`)

### Configuration Files

#### Voter Configuration (~/.voter/settings.toml)
```toml
# Voter's Nostr private key
nostr_private_key = "your_voter_private_key"

# EC's public key for verification
ec_public_key = "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...\n-----END PUBLIC KEY-----"

# Nostr relays for communication
relays = ["wss://relay.mostro.network"]
```

### Database Schema

The EC uses SQLite with the following tables:
- **elections**: Election metadata and status
- **candidates**: Candidate information per election
- **voters**: Authorized voters per election
- **votes**: Vote tracking and tallying

### Security Considerations

- **Network Access**: gRPC binds to localhost by default for security
- **Key Management**: Store RSA keys securely, never commit to version control
- **Voter Privacy**: Blind signatures ensure EC cannot correlate votes to voters
- **Double Voting Prevention**: Nonce tracking prevents multiple votes per voter

---

## Limitations

* **Experimental**: No formal security audit. Use only for study/demonstration.
* **Single EC**: Central authority issues tokens—no threshold or multi-party setup.
* **Replay Protection**: Based on one-time `h_n`, but stronger measures (timestamps, channels) may be needed.

---

## Nostr

As mentioned above, both the voter and the EC communicate by sending Gift Wrap events, but there are other messages that the EC publishes.

### Election

An addressable event kind `35000` with the election information in a serialized json object in the content field of the event, here an example of the json object:

```json
{
  "id": "f5f7",
  "name": "Libertad 2024",
  "start_time": 1746611643,
  "status": "open",
  "candidates": [
    {
      "id": 1,
      "name": "Donkey 🫏"
    },
    {
      "id": 2,
      "name": "Rat 🐀"
    },
    {
      "id": 3,
      "name": "Sheep 🐑"
    },
    {
      "id": 4,
      "name": "Sloth 🦥"
    }
  ],
  "end_time": 1746615243,
  "rsa_pub_key": "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAyzrjKKlz8JpyKrqnCNr2n/iXwSgHAnrNyZwOJ6UW4actxDnI3dyweOqXtGZyIg4+PeEmDrTY5sP6pN2p5qVM6XGmt7DCfStJgaCpB0D/BZd/ar/sh9aj9ATLQe24/UDXweGTgzWVsky8uCRODczaxhDPXvwRAQICuZNO3OxQ5ss7uc1ZfSDS++857q8k6KHdbnWkAy3+NoGslZWqIQH/h9tDl8zfKH5AP5MZibdna+/P2wbz86/8uq+hBupxwympiQXxLB7rfjfOkLX22WguseovpbA/7If3LNned5UuxX1IxuFzBtw7W1RAy8B1MqlAobf5K+e4XzAzl49AqQn6swIDAQAB"
}
```

The event would look like this:

```json
[
  "EVENT",
  "7157aabf-389e-4d3e-9656-4d818159dff2",
  {
    "tags": [
      [
        "d",
        "f5f7"
      ],
      [
        "expiration",
        "1747043643"
      ]
    ],
    "content": "{\"candidates\":[{\"id\":1,\"name\":\"Donkey 🫏\"},{\"id\":2,\"name\":\"Rat 🐀\"},{\"id\":3,\"name\":\"Sheep 🐑\"},{\"id\":4,\"name\":\"Sloth 🦥\"}],\"end_time\":1746615243,\"id\":\"f5f7\",\"name\":\"Libertad 2024\",\"rsa_pub_key\":\"MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAyzrjKKlz8JpyKrqnCNr2n/iXwSgHAnrNyZwOJ6UW4actxDnI3dyweOqXtGZyIg4+PeEmDrTY5sP6pN2p5qVM6XGmt7DCfStJgaCpB0D/BZd/ar/sh9aj9ATLQe24/UDXweGTgzWVsky8uCRODczaxhDPXvwRAQICuZNO3OxQ5ss7uc1ZfSDS++857q8k6KHdbnWkAy3+NoGslZWqIQH/h9tDl8zfKH5AP5MZibdna+/P2wbz86/8uq+hBupxwympiQXxLB7rfjfOkLX22WguseovpbA/7If3LNned5UuxX1IxuFzBtw7W1RAy8B1MqlAobf5K+e4XzAzl49AqQn6swIDAQAB\",\"start_time\":1746611643,\"status\":\"open\"}",
    "sig": "8b5bc04003c1d20ba98d33b2fd98a536d538d58afa1c9cfa81d3b693a3a20a764b51258e28335b10945439f7a09fca1d4d2ac40135a506e1bb4a8116259c46ab",
    "id": "557d833876048e50068dfb06b82344a058d8104f08578e8060623ec8004c29ac",
    "pubkey": "0000001ace57d0da17fc18562f4658ac6d093b2cc8bb7bd44853d0c196e24a9c",
    "created_at": 1746611643,
    "kind": 35000
  }
]
```

### Current status of the election

After each vote is received, the EC will publish another addressable event of kind `35001`. The event’s content field will contain the current status of the election as a serialized JSON array: the first element is the candidate ID, and the second element is the number of votes received. For example, in an election with the same candidates shown above—where **Sloth 🦥** received 21 vote and **Sheep 🐑** received 35 votes—the event would look like this:

```json
[
  "EVENT",
  "7157aabf-389e-4d3e-9656-4d818159dff2",
  {
    "tags": [
      [
        "d",
        "f5f7"
      ],
      [
        "expiration",
        "1747043706"
      ]
    ],
    "content": "[[4,21],[3,35]]",
    "sig": "3eb717f176be137d7adc0f9e6d52556c38d988bce59c2f683cbdc6f796df3a3e6d31aecf2866fa2df5d58ce7a287236f83e2c368a89015f7b8f4c5eea21e134d",
    "id": "7ae5c519f9e8886b70d0cef6155a69f3194e7b89cb88e589ed2012853915581e",
    "pubkey": "0000001ace57d0da17fc18562f4658ac6d093b2cc8bb7bd44853d0c196e24a9c",
    "created_at": 1746611706,
    "kind": 35001
  }
]
```

---

## License

This project is licensed under MIT. See [LICENSE](LICENSE) for details.

---

## Development Commands

### Build and Test
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

# Code quality checks
cargo clippy
cargo fmt
```

### Docker Deployment

```bash
# Build Docker image
docker build -t criptocracia .

# Run with environment variables
docker run -e NOSTR_PRIVATE_KEY="your_key" -p 50001:50001 criptocracia
```

### Troubleshooting

#### Common Issues

1. **"readonly database" error**: Multiple EC processes running
   ```bash
   pkill -f "target/release/ec"
   ```

2. **gRPC connection refused**: Check if EC is running and port is accessible
   ```bash
   netstat -tlnp | grep 50001
   ```

3. **Voter authorization failed**: Ensure voter is registered for the specific election
   ```bash
   # Use gRPC API to add voter
   cargo run --example grpc_client --bin ec
   ```

4. **RSA key loading failed**: Verify key files exist or environment variables are set
   ```bash
   ls -la ec_*.pem
   echo $EC_PRIVATE_KEY | head -c 50
   ```

## Architecture Details

### Component Interaction
```
┌─────────────┐    gRPC     ┌─────────────────┐    Nostr    ┌─────────────┐
│   Admin     │◄──────────►│       EC        │◄──────────►│   Voters    │
│   Client    │   Port 50001│   (Election     │  Gift Wrap  │  (Client)   │
│             │             │  Commission)    │   Events    │             │
└─────────────┘             └─────────────────┘             └─────────────┘
                                     │
                                     ▼
                            ┌─────────────────┐
                            │    Database     │
                            │   (elections.db)│
                            │   + Nostr Pub   │
                            └─────────────────┘
```

### Cryptographic Flow
1. **Voter Registration**: Admin adds voter pubkey to election via gRPC
2. **Token Request**: Voter blinds nonce hash, sends via NIP-59 Gift Wrap
3. **Token Issuance**: EC verifies voter authorization, issues blind signature
4. **Vote Casting**: Voter unblinds token, sends vote with anonymous keypair
5. **Vote Verification**: EC verifies token signature, prevents double voting
6. **Result Publishing**: Real-time vote tallies published to Nostr

## Feature Status

### Completed (v0.1)
- [x] Multi-election support with HashMap architecture
- [x] gRPC admin API for election and voter management
- [x] Database state restoration on startup
- [x] Automatic election status transitions (Open → InProgress → Finished)
- [x] Per-election voter authorization
- [x] Automatic Nostr publishing for gRPC-created elections
- [x] Cancel election functionality
- [x] Blind signature voting protocol
- [x] Real-time vote tallying and Nostr publishing
- [x] TUI voter client with election selection
- [x] Docker deployment support

### Planned (v0.2)
- [ ] Registration token system for automated voter enrollment
- [ ] Voter self-registration with cryptographic proof
- [ ] Enhanced security auditing and logging
- [ ] Multi-EC threshold signatures
- [ ] Web-based voter interface
