# gRPC Admin API Documentation

The Criptocracia Electoral Commission provides a gRPC-based admin API for managing elections, candidates, and voters. The server runs on port 50001 by default.

## Overview

The AdminService provides the following operations:
- **AddVoter**: Add authorized voters to the system
- **AddElection**: Create new elections with candidates
- **AddCandidate**: Add candidates to existing elections
- **GetElection**: Retrieve election details and current vote counts
- **ListVoters**: List all registered voters with pagination
- **ListElections**: List all elections with pagination

## Starting the gRPC Server

The gRPC server starts automatically when you run the Electoral Commission daemon:

```bash
cargo run --bin ec
```

The server will log:
```
Starting gRPC admin server on port 50001
```

## API Reference

### AddVoter

Add a new voter to the authorized voters list.

**Request:**
```protobuf
message AddVoterRequest {
    string name = 1;      // Human-readable name
    string pubkey = 2;    // Nostr public key (hex or npub format)
}
```

**Response:**
```protobuf
message AddVoterResponse {
    bool success = 1;     // Operation success status
    string message = 2;   // Status message
    string voter_id = 3;  // The voter's public key (if successful)
}
```

**Validation:**
- Name cannot be empty
- Public key must be valid hex (64+ chars) or npub format
- Public key must be unique

### AddElection

Create a new election with candidates.

**Request:**
```protobuf
message AddElectionRequest {
    string name = 1;                      // Election name (max 100 chars)
    uint64 start_time = 2;               // Unix timestamp
    uint64 duration = 3;                 // Duration in seconds
    repeated CandidateInfo candidates = 4; // List of candidates
    string rsa_public_key = 5;           // RSA public key for blind signatures
}
```

**Response:**
```protobuf
message AddElectionResponse {
    bool success = 1;     // Operation success status
    string message = 2;   // Status message
    string election_id = 3; // Generated election ID (if successful)
}
```

**Validation:**
- Name cannot be empty and must be ≤ 100 characters
- Start time and duration must be > 0
- Must have at least one candidate
- Candidate IDs must be 1-255 and unique
- Candidate names cannot be empty and must be ≤ 50 characters

### AddCandidate

Add a candidate to an existing election.

**Request:**
```protobuf
message AddCandidateRequest {
    string election_id = 1;  // Target election ID
    uint32 candidate_id = 2; // Candidate ID (1-255)
    string name = 3;         // Candidate name (max 50 chars)
}
```

**Response:**
```protobuf
message AddCandidateResponse {
    bool success = 1;     // Operation success status
    string message = 2;   // Status message
}
```

**Validation:**
- Election must exist
- Candidate ID must be 1-255 and unique within the election
- Candidate name cannot be empty and must be ≤ 50 characters

### GetElection

Retrieve election details and current vote counts.

**Request:**
```protobuf
message GetElectionRequest {
    string election_id = 1;  // Election ID to retrieve
}
```

**Response:**
```protobuf
message GetElectionResponse {
    bool success = 1;           // Operation success status
    string message = 2;         // Status message
    ElectionInfo election = 3;  // Election details (if found)
}
```

### ListVoters

List registered voters with pagination.

**Request:**
```protobuf
message ListVotersRequest {
    uint32 limit = 1;   // Max records to return (default: 100, max: 1000)
    uint32 offset = 2;  // Number of records to skip
}
```

**Response:**
```protobuf
message ListVotersResponse {
    bool success = 1;              // Operation success status
    string message = 2;            // Status message
    repeated VoterInfo voters = 3; // List of voters
    uint32 total_count = 4;        // Total number in this response
}
```

### ListElections

List elections with pagination.

**Request:**
```protobuf
message ListElectionsRequest {
    uint32 limit = 1;   // Max records to return (default: 100, max: 1000)
    uint32 offset = 2;  // Number of records to skip
}
```

**Response:**
```protobuf
message ListElectionsResponse {
    bool success = 1;                    // Operation success status
    string message = 2;                  // Status message
    repeated ElectionInfo elections = 3; // List of elections
    uint32 total_count = 4;              // Total number in this response
}
```

## Data Types

### CandidateInfo
```protobuf
message CandidateInfo {
    uint32 id = 1;           // Candidate ID
    string name = 2;         // Candidate name
    uint32 vote_count = 3;   // Current vote count
}
```

### VoterInfo
```protobuf
message VoterInfo {
    string name = 1;         // Voter name
    string pubkey = 2;       // Voter public key
    uint64 created_at = 3;   // Registration timestamp
}
```

### ElectionInfo
```protobuf
message ElectionInfo {
    string id = 1;                      // Election ID
    string name = 2;                    // Election name
    uint64 start_time = 3;              // Start timestamp
    uint64 end_time = 4;                // End timestamp
    string status = 5;                  // Status (Open, InProgress, Finished, Canceled)
    repeated CandidateInfo candidates = 6; // Candidates with vote counts
    string rsa_public_key = 7;          // RSA public key
    uint64 created_at = 8;              // Creation timestamp
    uint64 updated_at = 9;              // Last update timestamp
    uint32 total_votes = 10;            // Total votes cast
}
```

## Client Examples

### Rust Client Example

```rust
use tonic::Request;
use admin_proto::{admin_service_client::AdminServiceClient, AddVoterRequest};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut client = AdminServiceClient::connect("http://127.0.0.1:50001").await?;

    // Add a voter
    let request = Request::new(AddVoterRequest {
        name: "Alice Smith".to_string(),
        pubkey: "npub1alice123456789abcdefghijklmnopqrstuvwxyz1234567890abcdefg".to_string(),
    });

    let response = client.add_voter(request).await?;
    println!("Add voter response: {:?}", response.into_inner());

    Ok(())
}
```

### Python Client Example

```python
import grpc
import admin_pb2
import admin_pb2_grpc

def add_voter():
    with grpc.insecure_channel('localhost:50001') as channel:
        stub = admin_pb2_grpc.AdminServiceStub(channel)
        
        request = admin_pb2.AddVoterRequest(
            name="Bob Johnson",
            pubkey="npub1bob456789abcdefghijklmnopqrstuvwxyz1234567890abcdefghijk"
        )
        
        response = stub.AddVoter(request)
        print(f"Success: {response.success}")
        print(f"Message: {response.message}")
        print(f"Voter ID: {response.voter_id}")

if __name__ == "__main__":
    add_voter()
```

### cURL with grpcurl

First install [grpcurl](https://github.com/fullstorydev/grpcurl):

```bash
# List available services
grpcurl -plaintext localhost:50001 list

# Add a voter
grpcurl -plaintext -d '{
  "name": "Charlie Brown",
  "pubkey": "npub1charlie123456789abcdefghijklmnopqrstuvwxyz1234567890abcd"
}' localhost:50001 admin.AdminService/AddVoter

# Get election details
grpcurl -plaintext -d '{
  "election_id": "your-election-id"
}' localhost:50001 admin.AdminService/GetElection

# List voters
grpcurl -plaintext -d '{
  "limit": 10,
  "offset": 0
}' localhost:50001 admin.AdminService/ListVoters
```

## Error Handling

All responses include a `success` boolean and `message` string. Common error scenarios:

### Validation Errors
- Empty required fields
- Invalid data formats
- Out-of-range values

### Business Logic Errors
- Duplicate candidate IDs
- Election not found
- Voter already exists

### System Errors
- Database connection issues
- Internal server errors

Example error response:
```json
{
  "success": false,
  "message": "Invalid voter public key: Voter public key is too short",
  "voter_id": ""
}
```

## Security Considerations

- The gRPC server binds to localhost (127.0.0.1) only
- No authentication is implemented - secure your network access
- Input validation prevents common injection attacks
- Use TLS in production environments
- Consider implementing API rate limiting

## Performance Notes

- Database operations are asynchronous and non-blocking
- Pagination limits prevent large result sets
- Maximum limits: 1000 records per request
- Database uses SQLite with connection pooling

## Integration with Main Daemon

The gRPC server runs alongside the main Nostr-based voting system:
- Shares the same database and election state
- Changes via gRPC are immediately reflected in the voting system
- Both systems can operate concurrently
- No restart required for configuration changes