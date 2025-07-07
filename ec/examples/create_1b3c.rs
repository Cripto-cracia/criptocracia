/// Create election for mobile app
use tonic::Request;

// Generated gRPC client types
pub mod admin_proto {
    tonic::include_proto!("admin");
}

use admin_proto::{
    AddElectionRequest, AddVoterRequest, CandidateInfo, admin_service_client::AdminServiceClient,
};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("🔧 Creating election for mobile app...");

    let mut client = AdminServiceClient::connect("http://127.0.0.1:50001").await?;
    
    println!("\n🗳️ Creating election...");
    let candidates = vec![
        CandidateInfo {
            id: 1,
            name: "Option A".to_string(),
            vote_count: 0,
        },
        CandidateInfo {
            id: 2,
            name: "Option B".to_string(),
            vote_count: 0,
        },
    ];

    let start_time = chrono::Utc::now().timestamp() as u64 + 10; // Start in 10 seconds
    let duration = 600; // 10 minutes

    let request = Request::new(AddElectionRequest {
        name: "Mobile App Test Election".to_string(),
        start_time,
        duration,
        candidates,
    });

    match client.add_election(request).await {
        Ok(response) => {
            let resp = response.into_inner();
            if resp.success {
                println!("✅ Created election: {}", resp.election_id);
                
                // Add the mobile app voter
                println!("\n👤 Adding mobile app voter...");
                let voter_request = Request::new(AddVoterRequest {
                    election_id: resp.election_id.clone(),
                    name: "Mobile App User".to_string(),
                    pubkey: "3f55f3701e9b00dce27ab6cce6cf487fd5c4ba48f46d475926ebf916d53a9db1".to_string(),
                });
                
                match client.add_voter(voter_request).await {
                    Ok(voter_response) => {
                        let voter_resp = voter_response.into_inner();
                        if voter_resp.success {
                            println!("✅ Added mobile app voter to election {}", resp.election_id);
                            println!("\n📱 MOBILE APP CONFIGURATION:");
                            println!("   Election ID: {}", resp.election_id);
                            println!("   Voter pubkey: 3f55f3701e9b00dce27ab6cce6cf487fd5c4ba48f46d475926ebf916d53a9db1");
                            println!("   Status: Election will start in 10 seconds and run for 10 minutes");
                        } else {
                            println!("❌ Failed to add voter: {}", voter_resp.message);
                        }
                    }
                    Err(e) => {
                        println!("❌ Error adding voter: {}", e);
                    }
                }
            } else {
                println!("❌ Failed to create election: {}", resp.message);
            }
        }
        Err(e) => {
            println!("❌ Error creating election: {}", e);
        }
    }
    
    Ok(())
}