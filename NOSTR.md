# Nostr Protocol Integration in Criptocracia

This document provides a comprehensive technical overview of how Criptocracia integrates with the Nostr protocol for decentralized voting communication and public verifiability.

## Overview

Criptocracia leverages Nostr as the communication layer for:
- **Public election announcements** (Kind 35000)
- **Real-time vote result publishing** (Kind 35001) 
- **Encrypted voter-EC communication** (NIP-59 Gift Wrap)

The system ensures voter privacy through blind signatures while maintaining public verifiability through Nostr's decentralized event publishing.

## Election Events (Kind 35000)

### Event Type
Election announcements use **Kind 35000** custom events, which are **addressable events** as defined in [NIP-01](https://github.com/nostr-protocol/nips/blob/master/01.md).

### Addressable Event Properties
- **Unique identifier**: Uses the election ID in the `d` tag
- **Replaceable**: New events with the same `d` tag replace previous ones
- **Queryable**: Clients can fetch the latest state using the identifier

### Event Structure

```json
{
  "kind": 35000,
  "content": "{\"id\":\"f5f7\",\"name\":\"Libertad 2024\",\"start_time\":1746611643,\"end_time\":1746615243,\"candidates\":[{\"id\":1,\"name\":\"Donkey 🫏\"},{\"id\":2,\"name\":\"Rat 🐀\"},{\"id\":3,\"name\":\"Sheep 🐑\"},{\"id\":4,\"name\":\"Sloth 🦥\"}],\"status\":\"open\",\"rsa_pub_key\":\"MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAyzrjKKlz8JpyKrqnCNr2n/iXwSgHAnrNyZwOJ6UW4actxDnI3dyweOqXtGZyIg4+PeEmDrTY5sP6pN2p5qVM6XGmt7DCfStJgaCpB0D/BZd/ar/sh9aj9ATLQe24/UDXweGTgzWVsky8uCRODczaxhDPXvwRAQICuZNO3OxQ5ss7uc1ZfSDS++857q8k6KHdbnWkAy3+NoGslZWqIQH/h9tDl8zfKH5AP5MZibdna+/P2wbz86/8uq+hBupxwympiQXxLB7rfjfOkLX22WguseovpbA/7If3LNned5UuxX1IxuFzBtw7W1RAy8B1MqlAobf5K+e4XzAzl49AqQn6swIDAQAB\"}",
  "tags": [
    ["d", "f5f7"],
    ["expiration", "1747043643"]
  ],
  "pubkey": "0000001ace57d0da17fc18562f4658ac6d093b2cc8bb7bd44853d0c196e24a9c",
  "created_at": 1746611643,
  "sig": "8b5bc04003c1d20ba98d33b2fd98a536d538d58afa1c9cfa81d3b693a3a20a764b51258e28335b10945439f7a09fca1d4d2ac40135a506e1bb4a8116259c46ab",
  "id": "557d833876048e50068dfb06b82344a058d8104f08578e8060623ec8004c29ac"
}
```

### Content Structure

The event content is a JSON object containing:

```json
{
  "id": "f5f7",                    // Unique election identifier (4-character hex)
  "name": "Libertad 2024",         // Human-readable election name
  "start_time": 1746611643,        // Unix timestamp when voting begins
  "end_time": 1746615243,          // Unix timestamp when voting ends
  "candidates": [                  // Array of candidates
    {
      "id": 1,                     // Candidate ID (used in votes)
      "name": "Donkey 🫏"          // Candidate display name
    }
  ],
  "status": "open",                // Election status: "open", "in-progress", "finished", "canceled"
  "rsa_pub_key": "MIIBIjAN..."     // EC's RSA public key for vote verification (Base64 DER)
}
```

### When Events Are Created/Updated

#### Initial Creation
- **gRPC AddElection**: When elections are created through the admin API
- **System startup**: When restoring elections from database

#### Status Updates
- **Automatic transitions**: Every 30 seconds, the EC checks election times and updates status:
  - `open` → `in-progress` (at start_time)
  - `in-progress` → `finished` (at end_time)
- **Manual updates**: When elections are cancelled via gRPC CancelElection

#### Event Properties
- **Expiration**: 15 days from creation timestamp
- **Identifier tag**: `["d", "election_id"]` for addressable lookup
- **Creator**: Electoral Commission's Nostr public key

### Code Reference
Election events are published in `ec/src/main.rs:publish_election_event()`

## Results Events (Kind 35001)

### Event Type
Vote tallies use **Kind 35001** custom events, also addressable events that provide real-time election results.

### Event Structure

```json
{
  "kind": 35001,
  "content": "[[4,21],[3,35]]",
  "tags": [
    ["d", "f5f7"],
    ["expiration", "1747043706"]
  ],
  "pubkey": "0000001ace57d0da17fc18562f4658ac6d093b2cc8bb7bd44853d0c196e24a9c",
  "created_at": 1746611706,
  "sig": "3eb717f176be137d7adc0f9e6d52556c38d988bce59c2f683cbdc6f796df3a3e6d31aecf2866fa2df5d58ce7a287236f83e2c368a89015f7b8f4c5eea21e134d",
  "id": "7ae5c519f9e8886b70d0cef6155a69f3194e7b89cb88e589ed2012853915581e"
}
```

### Content Structure

The event content is a JSON array of `[candidate_id, vote_count]` pairs:

```json
[
  [4, 21],  // Candidate ID 4 has 21 votes
  [3, 35]   // Candidate ID 3 has 35 votes
]
```

### When Events Are Sent/Updated

#### Real-time Updates
- **After each vote**: Immediately published when a valid vote is received and tallied
- **Live results**: Provides real-time election results as voting progresses

#### Event Properties
- **Expiration**: 5 days from creation timestamp
- **Identifier tag**: `["d", "election_id"]` (same as election event)
- **Creator**: Electoral Commission's Nostr public key
- **Frequency**: One event per valid vote received

### Code Reference
Results events are published in `ec/src/main.rs` vote processing logic (Kind::Custom(35_001))

## Gift Wrap Messages (NIP-59)

### Overview
[NIP-59 Gift Wrap](https://github.com/nostr-protocol/nips/blob/master/59.md) provides end-to-end encryption for sensitive voter-EC communication, ensuring vote secrecy and metadata protection.

### Message Types

Criptocracia uses custom message types within Gift Wrap events:

```json
{
  "id": "message_identifier",
  "kind": 1,                      // 1 = Token request, 2 = Vote submission
  "payload": "base64_content",    // Message-specific payload
  "election_id": "f5f7"          // Target election (added for security)
}
```

### Token Request Messages (Kind 1)

#### Purpose
Voters request blind-signed tokens from the EC for anonymous voting.

#### Message Structure
```json
{
  "id": "token_request_1746611643",
  "kind": 1,
  "payload": "SGVsbG8gV29ybGQ=",    // Base64-encoded blinded hash nonce
  "election_id": "f5f7"             // Target election ID
}
```

#### Payload Content
- **Blinded hash nonce**: `blind(SHA256(random_nonce))` encoded in Base64
- **Encryption**: The entire message is wrapped in NIP-59 Gift Wrap using voter's keys

#### Flow
1. **Voter generates**: 128-bit random nonce
2. **Hash**: `h_n = SHA256(nonce)`
3. **Blind**: `blinded_h_n = blind(h_n, ec_public_key)`
4. **Encode**: Base64 encode the blinded hash
5. **Wrap**: Create Gift Wrap event with voter's real identity
6. **Send**: Publish to Nostr relay

#### EC Response
The EC responds with a Gift Wrap containing the blind signature:
```json
{
  "id": "token_request_1746611643",  // Same ID as request
  "kind": 1,
  "payload": "base64_blind_signature",
  "election_id": "f5f7"              // Same election_id as request (if provided)
}
```

**Note**: For requests that include `election_id`, the response will also include the same `election_id`. Legacy requests without `election_id` receive responses without this field for backward compatibility.

### Vote Submission Messages (Kind 2)

#### Purpose
Voters submit their final votes using the unblinded tokens for verification.

#### Message Structure
```json
{
  "id": "vote_1746611800",
  "kind": 2,
  "payload": "h_n_b64:token_b64:randomizer_b64:candidate_id",
  "election_id": "f5f7"
}
```

#### Payload Format
Colon-delimited string with four components:
1. **h_n_b64**: Original hash nonce (Base64)
2. **token_b64**: Unblinded signature token (Base64)  
3. **randomizer_b64**: Message randomizer used in blinding (Base64)
4. **candidate_id**: Chosen candidate ID (integer)

#### Anonymity Protection
- **Random keypair**: Voter generates fresh Nostr keys for vote submission
- **Identity separation**: Vote cannot be linked back to voter's identity
- **Gift Wrap encryption**: Vote content is still encrypted in transit

#### Flow
1. **Voter unblinds**: `token = unblind(blind_signature, blinding_factor)`
2. **Verify token**: Validate token signature against EC's public key
3. **Prepare vote**: Format payload with token and candidate choice
4. **Generate random keys**: Create fresh Nostr keypair for anonymity
5. **Wrap**: Create Gift Wrap event with random identity
6. **Send**: Publish to Nostr relay

### Election-Specific Security (New)

#### Enhanced Message Format
Recent security improvements add `election_id` field to prevent cross-election attacks:

```json
{
  "id": "unique_message_id",
  "kind": 1,                    // or 2
  "payload": "message_content", 
  "election_id": "target_election_id"  // Required for validation
}
```

#### Security Benefits
- **Election isolation**: Prevents tokens from one election being used in another
- **Direct validation**: EC validates requests for specific elections only
- **Authorization checking**: Ensures voters are registered for the target election

#### Backward Compatibility
- Legacy messages without `election_id` fall back to trying all elections
- New clients always include `election_id` for enhanced security

## Event Flow Diagrams

### 1. Election Creation and Announcement

```
Admin/gRPC → EC → Database → Nostr (Kind 35000)
     │        │       │           │
     │        │       │           └─ Public election announcement
     │        │       └─ Store election data
     │        └─ Create election object
     └─ AddElection request
```

### 2. Token Request Flow

```
Voter → Nostr (Gift Wrap) → EC → Database → EC → Nostr (Gift Wrap) → Voter
  │           │               │       │       │         │            │
  │           │               │       │       │         │            └─ Receive blind signature
  │           │               │       │       │         └─ Send encrypted response
  │           │               │       │       └─ Generate blind signature
  │           │               │       └─ Check voter authorization
  │           │               └─ Validate election_id & voter
  │           └─ Encrypted token request (kind 1)
  └─ Generate blinded nonce
```

### 3. Vote Submission Flow

```
Voter → Nostr (Gift Wrap) → EC → Database → Nostr (Kind 35001)
  │           │               │       │           │
  │           │               │       │           └─ Publish updated results
  │           │               │       └─ Store used token
  │           │               └─ Verify token & tally vote
  │           └─ Encrypted vote (kind 2, random keys)
  └─ Unblind token & create vote
```

### 4. Automatic Status Updates

```
Timer (30s) → EC → Database → Nostr (Kind 35000)
     │         │       │           │
     │         │       │           └─ Updated election status
     │         │       └─ Update election status
     │         └─ Check election times
     └─ Periodic status checker
```

## Technical Implementation Details

### Relay Configuration
- **Default relay**: `wss://relay.mostro.network`
- **Configurable**: Can be changed in voter settings
- **Connection**: Automatic reconnection handling

### Event Filtering

#### EC Subscriptions
```rust
// EC listens for Gift Wrap events directed to it
Filter::new()
    .pubkey(ec_keys.public_key())
    .kind(Kind::GiftWrap)
    .limit(0)
```

#### Voter Subscriptions
```rust
// Voters listen for election and results events
Filter::new()
    .kinds([Kind::Custom(35_000), Kind::Custom(35_001)])
    .pubkey(ec_public_key)
    .since(two_days_ago)

// Voters also listen for Gift Wrap responses
Filter::new()
    .kind(Kind::GiftWrap)
    .pubkey(voter_keys.public_key())
    .limit(20)
    .since(timestamp)
```

### Error Handling
- **Invalid signatures**: Events with invalid signatures are ignored
- **Decryption failures**: Gift Wrap decryption errors are logged and skipped
- **Malformed content**: Invalid JSON or message format is rejected
- **Authorization failures**: Unauthorized voters receive no response

### Code References

#### Key Files
- `ec/src/main.rs`: Main event processing loop and publishing logic
- `ec/src/election.rs`: Election data structures and JSON serialization
- `voter/src/main.rs`: Voter client event handling and UI
- `voter/src/election.rs`: Voter-side message structures

#### Critical Functions
- `publish_election_event()`: Publishes Kind 35000 events
- Vote processing loop: Handles Gift Wrap and publishes Kind 35001
- Event subscription and filtering logic

### Security Considerations

#### Voter Privacy
- **Blind signatures**: EC cannot link votes to voter identities
- **Random keypairs**: Vote submissions use fresh, anonymous keys
- **Gift Wrap encryption**: All sensitive communication is encrypted
- **Metadata protection**: NIP-59 prevents correlation via metadata

#### System Integrity
- **Digital signatures**: All events are cryptographically signed
- **Public verifiability**: Election results can be independently verified
- **Double-vote prevention**: Nonce tracking prevents vote duplication
- **Election isolation**: Cross-election attacks are prevented

#### Network Security
- **Decentralized relays**: No single point of failure
- **Event expiration**: Automatic cleanup of old events
- **Rate limiting**: Natural rate limiting through cryptographic operations

This documentation provides the complete technical specification for Nostr integration in Criptocracia, enabling developers to build compatible clients and understand the security properties of the voting protocol.