/// Example gRPC client for the Criptocracia Electoral Commission Admin API
/// 
/// This example demonstrates how to interact with the EC admin API using gRPC.
/// 
/// To use this example:
/// 1. Start the EC daemon: `cargo run --bin ec`
/// 2. Run this client: `cargo run --example grpc_client`

use tonic::Request;

// Generated gRPC client types
pub mod admin_proto {
    tonic::include_proto!("admin");
}

use admin_proto::{
    admin_service_client::AdminServiceClient,
    AddVoterRequest, AddElectionRequest, AddCandidateRequest,
    GetElectionRequest, ListVotersRequest, ListElectionsRequest,
    CandidateInfo,
};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("🔗 Connecting to Electoral Commission gRPC API...");
    
    let mut client = AdminServiceClient::connect("http://127.0.0.1:50001").await?;
    println!("✅ Connected to gRPC server");

    // 1. Add voters
    println!("\n📊 Adding voters...");
    let voters = vec![
        ("Alice Johnson", "npub1alice123456789abcdefghijklmnopqrstuvwxyz1234567890abcdefg"),
        ("Bob Smith", "npub1bob456789abcdefghijklmnopqrstuvwxyz1234567890abcdefghijk"),
        ("Charlie Brown", "npub1charlie123456789abcdefghijklmnopqrstuvwxyz1234567890abcd"),
    ];

    for (name, pubkey) in voters {
        let request = Request::new(AddVoterRequest {
            name: name.to_string(),
            pubkey: pubkey.to_string(),
        });

        let response = client.add_voter(request).await?;
        let inner = response.into_inner();
        
        if inner.success {
            println!("✅ Added voter: {} ({})", name, inner.voter_id);
        } else {
            println!("❌ Failed to add voter {}: {}", name, inner.message);
        }
    }

    // 2. Create an election
    println!("\n🗳️ Creating election...");
    let candidates = vec![
        CandidateInfo {
            id: 1,
            name: "Environmental Party".to_string(),
            vote_count: 0,
        },
        CandidateInfo {
            id: 2,
            name: "Tech Innovation Party".to_string(),
            vote_count: 0,
        },
        CandidateInfo {
            id: 3,
            name: "Social Justice Party".to_string(),
            vote_count: 0,
        },
    ];

    let start_time = chrono::Utc::now().timestamp() as u64 + 300; // Start in 5 minutes
    let duration = 3600; // 1 hour

    let request = Request::new(AddElectionRequest {
        name: "Community Leadership Election 2024".to_string(),
        start_time,
        duration,
        candidates,
        rsa_public_key: "dummy_rsa_key_for_example".to_string(),
    });

    let response = client.add_election(request).await?;
    let inner = response.into_inner();
    
    let election_id = if inner.success {
        println!("✅ Created election: {}", inner.election_id);
        inner.election_id
    } else {
        println!("❌ Failed to create election: {}", inner.message);
        return Ok(());
    };

    // 3. Add another candidate
    println!("\n➕ Adding additional candidate...");
    let request = Request::new(AddCandidateRequest {
        election_id: election_id.clone(),
        candidate_id: 4,
        name: "Independent Candidate".to_string(),
    });

    let response = client.add_candidate(request).await?;
    let inner = response.into_inner();
    
    if inner.success {
        println!("✅ Added candidate: Independent Candidate");
    } else {
        println!("❌ Failed to add candidate: {}", inner.message);
    }

    // 4. Get election details
    println!("\n📋 Retrieving election details...");
    let request = Request::new(GetElectionRequest {
        election_id: election_id.clone(),
    });

    let response = client.get_election(request).await?;
    let inner = response.into_inner();
    
    if inner.success {
        if let Some(election) = inner.election {
            println!("📊 Election: {}", election.name);
            println!("   ID: {}", election.id);
            println!("   Status: {}", election.status);
            println!("   Start: {}", chrono::DateTime::from_timestamp(election.start_time as i64, 0)
                .unwrap_or_default().format("%Y-%m-%d %H:%M:%S UTC"));
            println!("   End: {}", chrono::DateTime::from_timestamp(election.end_time as i64, 0)
                .unwrap_or_default().format("%Y-%m-%d %H:%M:%S UTC"));
            println!("   Total Votes: {}", election.total_votes);
            println!("   Candidates:");
            for candidate in election.candidates {
                println!("     {}. {} ({} votes)", candidate.id, candidate.name, candidate.vote_count);
            }
        }
    } else {
        println!("❌ Failed to get election: {}", inner.message);
    }

    // 5. List voters
    println!("\n👥 Listing voters...");
    let request = Request::new(ListVotersRequest {
        limit: 10,
        offset: 0,
    });

    let response = client.list_voters(request).await?;
    let inner = response.into_inner();
    
    if inner.success {
        println!("📋 Registered voters ({} total):", inner.total_count);
        for voter in inner.voters {
            println!("   • {} ({})", voter.name, voter.pubkey);
        }
    } else {
        println!("❌ Failed to list voters: {}", inner.message);
    }

    // 6. List elections
    println!("\n🗳️ Listing elections...");
    let request = Request::new(ListElectionsRequest {
        limit: 10,
        offset: 0,
    });

    let response = client.list_elections(request).await?;
    let inner = response.into_inner();
    
    if inner.success {
        println!("📋 Elections ({} total):", inner.total_count);
        for election in inner.elections {
            println!("   • {} ({})", election.name, election.status);
            println!("     ID: {}", election.id);
            println!("     Votes: {}", election.total_votes);
        }
    } else {
        println!("❌ Failed to list elections: {}", inner.message);
    }

    println!("\n🎉 Demo complete!");
    Ok(())
}