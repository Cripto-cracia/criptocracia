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
    AddCandidateRequest, AddElectionRequest, AddVoterRequest, CandidateInfo, GetElectionRequest,
    ListElectionsRequest, ListVotersRequest, CancelElectionRequest, admin_service_client::AdminServiceClient,
};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("🔗 Connecting to Electoral Commission gRPC API...");

    let mut client = AdminServiceClient::connect("http://127.0.0.1:50001").await?;
    println!("✅ Connected to gRPC server");

    // 1. Create an election first (required before adding voters)
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

    let start_time = chrono::Utc::now().timestamp() as u64 + 60; // Start in 1 minute
    let duration = 120; // 2 minutes

    let request = Request::new(AddElectionRequest {
        name: "Community Election 2025".to_string(),
        start_time,
        duration,
        candidates,
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

    // 2. Add voters to the election (demonstrating both hex and npub formats)
    println!("\n📊 Adding voters to election...");
    let voters = vec![
        (
            "Alice in Wonderland",
            "00001001063e6bf1b28f6514ac651afef7f51b2a792f0416a5e8273daa9eea6e",
        ),
        (
            "Bob Marley",
            "3f55f3701e9b00dce27ab6cce6cf487fd5c4ba48f46d475926ebf916d53a9db1",
        ),
        (
            "Charlie Brown",
            "00000699921ac7021b7da121da5bd762d90be830c3964ba12e82b590445797a6",
        ),
        (
            "Diana Prince (npub format)",
            "npub1qqqqqxkw2lgd59lurptz73jc43ksjwevezahh4zg20gvr9hzf2wq8nzqyl",
        ),
    ];

    for (name, pubkey) in voters {
        let request = Request::new(AddVoterRequest {
            name: name.to_string(),
            pubkey: pubkey.to_string(),
            election_id: election_id.clone(),
        });

        let response = client.add_voter(request).await?;
        let inner = response.into_inner();

        if inner.success {
            println!("✅ Added voter: {} ({})", name, inner.voter_id);
        } else {
            println!("❌ Failed to add voter {}: {}", name, inner.message);
        }
    }

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
            println!(
                "   Start: {}",
                chrono::DateTime::from_timestamp(election.start_time as i64, 0)
                    .unwrap_or_default()
                    .format("%Y-%m-%d %H:%M:%S UTC")
            );
            println!(
                "   End: {}",
                chrono::DateTime::from_timestamp(election.end_time as i64, 0)
                    .unwrap_or_default()
                    .format("%Y-%m-%d %H:%M:%S UTC")
            );
            println!("   Total Votes: {}", election.total_votes);
            println!("   Candidates:");
            for candidate in election.candidates {
                println!(
                    "     {}. {} ({} votes)",
                    candidate.id, candidate.name, candidate.vote_count
                );
            }
        }
    } else {
        println!("❌ Failed to get election: {}", inner.message);
    }

    // 5. List voters for the election
    println!("\n👥 Listing voters for election...");
    let request = Request::new(ListVotersRequest {
        limit: 10,
        offset: 0,
        election_id: election_id.clone(),
    });

    let response = client.list_voters(request).await?;
    let inner = response.into_inner();

    if inner.success {
        println!(
            "📋 Authorized voters for election ({} total):",
            inner.total_count
        );
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

    // 7. Cancel the election
    println!("\n❌ Canceling election...");
    let request = Request::new(CancelElectionRequest {
        election_id: election_id.clone(),
    });

    let response = client.cancel_election(request).await?;
    let inner = response.into_inner();

    if inner.success {
        println!("✅ Election canceled: {}", inner.message);
    } else {
        println!("❌ Failed to cancel election: {}", inner.message);
    }

    // 8. Verify election status after cancellation
    println!("\n🔍 Verifying election status after cancellation...");
    let request = Request::new(GetElectionRequest {
        election_id: election_id.clone(),
    });

    let response = client.get_election(request).await?;
    let inner = response.into_inner();

    if inner.success {
        if let Some(election) = inner.election {
            println!("📊 Election Status: {}", election.status);
            if election.status == "Canceled" {
                println!("✅ Election successfully canceled and status updated");
            }
        }
    } else {
        println!("❌ Failed to get election status: {}", inner.message);
    }

    println!("\n🎉 Demo complete!");
    Ok(())
}
