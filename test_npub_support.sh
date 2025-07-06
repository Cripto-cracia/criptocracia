#!/bin/bash

echo "🧪 Testing npub Support in gRPC AddVoterRequest"

# Clean start
rm -f ec/app.log ec/elections.db

# Start EC service in background
echo "📡 Starting EC service..."
cargo run --bin ec > /tmp/ec_npub_test.log 2>&1 &
EC_PID=$!

sleep 3

# Create a test with npub format
echo "🗳️ Testing npub format voter registration..."

# Use a temporary Rust test script to test npub specifically
cat > /tmp/test_npub.rs << 'EOF'
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
    let candidates = vec![
        CandidateInfo {
            id: 1,
            name: "Candidate A".to_string(),
            vote_count: 0,
        },
    ];

    let start_time = chrono::Utc::now().timestamp() as u64 + 300;
    let duration = 3600;

    let request = Request::new(AddElectionRequest {
        name: "npub Test Election".to_string(),
        start_time,
        duration,
        candidates,
    });

    let response = client.add_election(request).await?;
    let inner = response.into_inner();

    if !inner.success {
        println!("❌ Failed to create election: {}", inner.message);
        return Ok(());
    }

    let election_id = inner.election_id;
    println!("✅ Created election: {}", election_id);

    // Test npub format voter
    let npub_voter = "npub1qqqqqxkw2lgd59lurptz73jc43ksjwevezahh4zg20gvr9hzf2wq8nzqyl";
    
    let request = Request::new(AddVoterRequest {
        name: "npub Test Voter".to_string(),
        pubkey: npub_voter.to_string(),
        election_id: election_id.clone(),
    });

    let response = client.add_voter(request).await?;
    let inner = response.into_inner();

    if inner.success {
        println!("✅ npub voter registered successfully: {}", inner.voter_id);
    } else {
        println!("❌ Failed to register npub voter: {}", inner.message);
    }

    // Test hex format voter
    let hex_voter = "00001001063e6bf1b28f6514ac651afef7f51b2a792f0416a5e8273daa9eea6e";
    
    let request = Request::new(AddVoterRequest {
        name: "Hex Test Voter".to_string(),
        pubkey: hex_voter.to_string(),
        election_id: election_id.clone(),
    });

    let response = client.add_voter(request).await?;
    let inner = response.into_inner();

    if inner.success {
        println!("✅ Hex voter registered successfully: {}", inner.voter_id);
    } else {
        println!("❌ Failed to register hex voter: {}", inner.message);
    }

    Ok(())
}
EOF

# Run the test (we'll use the existing example structure)
echo "📋 Running both npub and hex format tests..."

# Create a simpler approach - modify the existing grpc_client temporarily
cp examples/grpc_client.rs /tmp/grpc_client_backup.rs

# Create a test with npub format voter
cat > /tmp/test_client.rs << 'EOF'
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
    println!("🔗 Connecting to Electoral Commission gRPC API...");
    let mut client = AdminServiceClient::connect("http://127.0.0.1:50001").await?;
    println!("✅ Connected to gRPC server");

    // Create election
    let candidates = vec![
        CandidateInfo { id: 1, name: "Test Candidate".to_string(), vote_count: 0 },
    ];

    let request = Request::new(AddElectionRequest {
        name: "npub Test Election".to_string(),
        start_time: chrono::Utc::now().timestamp() as u64 + 300,
        duration: 3600,
        candidates,
    });

    let response = client.add_election(request).await?;
    let election_id = response.into_inner().election_id;
    println!("✅ Created election: {}", election_id);

    // Test npub format
    println!("🧪 Testing npub format...");
    let request = Request::new(AddVoterRequest {
        name: "npub Test User".to_string(),
        pubkey: "npub1qqqqqxkw2lgd59lurptz73jc43ksjwevezahh4zg20gvr9hzf2wq8nzqyl".to_string(),
        election_id: election_id.clone(),
    });

    let response = client.add_voter(request).await?;
    let inner = response.into_inner();
    
    if inner.success {
        println!("✅ npub format accepted: {}", inner.voter_id);
    } else {
        println!("❌ npub format rejected: {}", inner.message);
    }

    // Test hex format 
    println!("🧪 Testing hex format...");
    let request = Request::new(AddVoterRequest {
        name: "Hex Test User".to_string(),
        pubkey: "00001001063e6bf1b28f6514ac651afef7f51b2a792f0416a5e8273daa9eea6e".to_string(),
        election_id: election_id.clone(),
    });

    let response = client.add_voter(request).await?;
    let inner = response.into_inner();
    
    if inner.success {
        println!("✅ Hex format accepted: {}", inner.voter_id);
    } else {
        println!("❌ Hex format rejected: {}", inner.message);
    }

    println!("🎉 Test complete!");
    Ok(())
}
EOF

# Copy our test as the grpc_client example temporarily
cp /tmp/test_client.rs examples/grpc_client.rs

# Run the test
cargo run --example grpc_client > /tmp/npub_test_result.log 2>&1

# Restore original
cp /tmp/grpc_client_backup.rs examples/grpc_client.rs

# Show results
echo "📊 Test Results:"
cat /tmp/npub_test_result.log

# Cleanup
kill $EC_PID 2>/dev/null
wait $EC_PID 2>/dev/null

echo "🧹 Test completed"