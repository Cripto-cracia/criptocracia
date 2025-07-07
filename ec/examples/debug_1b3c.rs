/// Debug script to check election 1b3c voters
use tonic::Request;

// Generated gRPC client types
pub mod admin_proto {
    tonic::include_proto!("admin");
}

use admin_proto::{
    GetElectionRequest, ListVotersRequest, admin_service_client::AdminServiceClient,
};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("🔍 Debugging election 1b3c...");

    let mut client = AdminServiceClient::connect("http://127.0.0.1:50001").await?;
    
    // Get election details
    println!("\n📊 Getting election 1b3c details...");
    let election_request = Request::new(GetElectionRequest {
        election_id: "1b3c".to_string(),
    });
    
    match client.get_election(election_request).await {
        Ok(response) => {
            let resp = response.into_inner();
            if resp.success {
                if let Some(election) = resp.election {
                    println!("✅ Election: {}", election.name);
                    println!("   ID: {}", election.id);
                    println!("   Status: {}", election.status);
                    println!("   Start: {}", chrono::DateTime::<chrono::Utc>::from_timestamp(election.start_time as i64, 0).unwrap_or_default());
                    println!("   End: {}", chrono::DateTime::<chrono::Utc>::from_timestamp(election.end_time as i64, 0).unwrap_or_default());
                } else {
                    println!("❌ Election data not found");
                }
            } else {
                println!("❌ Failed to get election: {}", resp.message);
            }
        }
        Err(e) => {
            println!("❌ Error getting election: {}", e);
        }
    }
    
    // List voters for election 1b3c
    println!("\n👥 Listing voters for election 1b3c...");
    let voters_request = Request::new(ListVotersRequest {
        election_id: "1b3c".to_string(),
        limit: 100,
        offset: 0,
    });
    
    match client.list_voters(voters_request).await {
        Ok(response) => {
            let resp = response.into_inner();
            if resp.success {
                let voter_count = resp.voters.len();
                println!("📋 Voters for election 1b3c ({} total):", voter_count);
                for voter in &resp.voters {
                    println!("   • {} ({})", voter.name, voter.pubkey);
                    
                    // Check if this matches the failing voter
                    if voter.pubkey == "3f55f3701e9b00dce27ab6cce6cf487fd5c4ba48f46d475926ebf916d53a9db1" {
                        println!("     ✅ This is the voter from the mobile app!");
                    }
                }
                if resp.voters.is_empty() {
                    println!("   ⚠️  NO VOTERS REGISTERED FOR THIS ELECTION!");
                    println!("   🔧 You need to add the voter to election 1b3c:");
                    println!("      AddVoterRequest {{");
                    println!("        election_id: \"1b3c\",");
                    println!("        name: \"Mobile App User\",");
                    println!("        pubkey: \"3f55f3701e9b00dce27ab6cce6cf487fd5c4ba48f46d475926ebf916d53a9db1\"");
                    println!("      }}");
                }
            } else {
                println!("❌ Failed to list voters: {}", resp.message);
            }
        }
        Err(e) => {
            println!("❌ Error listing voters: {}", e);
        }
    }
    
    Ok(())
}