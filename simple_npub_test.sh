#!/bin/bash

echo "🧪 Simple npub Test"

# Start EC in background
cargo run --bin ec > /tmp/ec_simple.log 2>&1 &
EC_PID=$!

sleep 5

# Create a simple test client
cat > /tmp/simple_test.rs << 'EOF'
use tonic::Request;

pub mod admin_proto {
    tonic::include_proto!("admin");
}

use admin_proto::{
    AddElectionRequest, AddVoterRequest, CandidateInfo,
    admin_service_client::AdminServiceClient,
};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut client = AdminServiceClient::connect("http://127.0.0.1:50001").await?;

    // Create election first
    let request = Request::new(AddElectionRequest {
        name: "Test Election".to_string(),
        start_time: chrono::Utc::now().timestamp() as u64 + 300,
        duration: 3600,
        candidates: vec![CandidateInfo { id: 1, name: "Test".to_string(), vote_count: 0 }],
    });

    let response = client.add_election(request).await?;
    let election_id = response.into_inner().election_id;

    // Test npub - use a valid npub
    let request = Request::new(AddVoterRequest {
        name: "Test User".to_string(),
        pubkey: "npub1qqqqqxkw2lgd59lurptz73jc43ksjwevezahh4zg20gvr9hzf2wq8nzqyl".to_string(),
        election_id: election_id.clone(),
    });

    let response = client.add_voter(request).await?;
    let result = response.into_inner();
    
    println!("npub test result: success={}, message='{}'", result.success, result.message);
    
    Ok(())
}
EOF

# Replace example temporarily
cp examples/grpc_client.rs /tmp/original_client.rs
cp /tmp/simple_test.rs examples/grpc_client.rs

# Run test
cargo run --example grpc_client 2>&1

# Restore
cp /tmp/original_client.rs examples/grpc_client.rs

# Cleanup
kill $EC_PID 2>/dev/null

echo "Done"