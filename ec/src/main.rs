mod types;
mod election;

use base64::{engine::general_purpose, Engine as _};
use anyhow::Result;
use types::{Candidate, Voter};
use nostr_sdk::prelude::*;
use std::fs;
use tokio::sync::mpsc;
use fern::Dispatch;
use chrono::Local;
use num_bigint_dig::BigUint;

// Demo keys for the electoral commission:
// Hex public key:   0000001ace57d0da17fc18562f4658ac6d093b2cc8bb7bd44853d0c196e24a9c
// Hex private key:  e3f33350728580cd51db8f4048d614910d48a5c0d7f1af6811e83c07fc865a5c
// Npub public key:  npub1qqqqqxkw2lgd59lurptz73jc43ksjwevezahh4zg20gvr9hzf2wq8nzqyl
// Nsec private key: nsec1u0enx5rjskqv65wm3aqy34s5jyx53fwq6lc676q3aq7q0lyxtfwqph3yue

/// Initialize logger function
fn setup_logger(level: log::LevelFilter) -> Result<(), fern::InitError> {
    Dispatch::new()
        .format(|out, message, record| {
            out.finish(format_args!(
                "[{}] [{}] - {}",
                Local::now().format("%Y-%m-%d %H:%M:%S"),
                record.level(),
                message
            ))
        })
        .level(level)
        .chain(fern::log_file("app.log")?)
        .apply()?;
    Ok(())
}

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize logger
    setup_logger(log::LevelFilter::Info).expect("Can't initialize logger");
    let keys = Keys::parse("e3f33350728580cd51db8f4048d614910d48a5c0d7f1af6811e83c07fc865a5c")?;

    println!("🔑 Electoral Commission Public key: {}", keys.public_key().to_bech32()?);

    // Build the signing client
    let client = Client::builder()
        .signer(keys.clone())
        .build();

    // Add the Mostro relay and connect
    client.add_relay("wss://relay.mostro.network").await?;
    client.connect().await;

    let candidates: Vec<Candidate> = vec![
        Candidate::new(1, "Burro 🐴"),
        Candidate::new(2, "Oveja 🐑"),
        Candidate::new(3, "Perezoso 🦥"),
    ];
    let now = chrono::Utc::now();
    let start_time = now.timestamp() as u64;
    // Duration of the election
    let duration = 1 * 60 * 60; // 1 hour in seconds
    let election_name = "Libertad 2024".to_string();
    let mut election = election::Election::new(election_name, candidates.clone(), start_time, duration);
    // Timestamp for the expiration of the election
    let future = now + chrono::Duration::days(5);
    let secs = future.timestamp() as u64;
    let future_ts = Timestamp::from(secs);
    println!("🗳️ Election: {}", election.as_json());
    // We publish the candidates list in a custom event with kind 35_000
    let event = EventBuilder::new(Kind::Custom(35_000), election.as_json())
        .tag(Tag::identifier(election.id.to_string()))
        .tag(Tag::expiration(future_ts))
        .sign(&keys).await?;

    // Publish the event to the relay
    client.send_event(&event).await?;

    println!("🎁 Event with the list of candidates sent!");
    let file_path = "data/voters_pubkeys.json";
    // Read voters json file
    let json_content = fs::read_to_string(file_path)
        .map_err(|e| anyhow::anyhow!("Error reading file {}: {}", file_path, e))?;
    // 2. Parse the JSON string into a Vec<Voter>
    let voters: Vec<Voter> = serde_json::from_str(&json_content)
        .map_err(|e| anyhow::anyhow!("Error parsing JSON from {}: {}", file_path, e))?;

    // 3. Iterate through the vector and print the name of each voter
    println!("Voter Names:");
    for voter in voters {
        println!("👤 {}", voter.name);
        election.register_voter(&voter.pubkey);
    }
    let subscription = Filter::new()
        .pubkey(keys.public_key())
        .kind(Kind::GiftWrap)
        .limit(0);
    // Client subscription
    client.subscribe(subscription, None).await?;
    // Set up channel for real-time order updates
    let (tx, mut rx) = mpsc::channel(100);

    // Spawn a task to handle Nostr events
    tokio::spawn(async move {
        let mut notifications = client.notifications();
        while let Ok(notification) = notifications.recv().await {
            if let RelayPoolNotification::Event { event, .. } = notification {
                // Validate event signature
                if event.verify().is_err() {
                    log::warn!("Error in event verification")
                };
                let event = match nip59::extract_rumor(&keys, &event).await {
                    Ok(u) => u,
                    Err(_) => {
                        println!("Error unwrapping gift");
                        continue;
                    }
                };
                let decoded_bytes = match general_purpose::STANDARD.decode(&event.rumor.content) {
                    Ok(bytes) => bytes,
                    Err(e) => {
                        log::warn!("Error decoding content: {}", e);
                        continue;
                    }
                };
                let h_n = BigUint::from_bytes_be(&decoded_bytes);
                println!("{:#?}", h_n.to_bytes_be());
                let _ = tx.send(event).await;
            }
        }
    });
    loop {
        // Check for new orders without blocking
        while let Ok(event) = rx.try_recv() {
            log::info!("New event rx: {:#?}", event);
        }
    }
}
