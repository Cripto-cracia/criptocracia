mod election;
mod types;

use anyhow::Result;
use base64::{Engine as _, engine::general_purpose};
use chrono::Local;
use election::BlindTokenRequest;
use fern::Dispatch;
use nostr_sdk::prelude::*;
use num_bigint_dig::BigUint;
use std::fs;
use tokio::sync::mpsc;
use types::{Candidate, Message, Voter};

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
    log::info!("Criptocracia started");
    let keys = Keys::parse("e3f33350728580cd51db8f4048d614910d48a5c0d7f1af6811e83c07fc865a5c")?;

    println!(
        "🔑 Electoral Commission Public key: {}",
        keys.public_key().to_bech32()?
    );

    // Build the signing client
    let client = Client::builder().signer(keys.clone()).build();

    // Add the Mostro relay and connect
    client.add_relay("wss://relay.mostro.network").await?;
    client.connect().await;

    let candidates: Vec<Candidate> = vec![
        Candidate::new(1, "Vaca lola"),
        Candidate::new(2, "Cerdo loco"),
        Candidate::new(3, "Rata sabrosa"),
        Candidate::new(4, "Perro rabioso"),
    ];
    let now = chrono::Utc::now();
    let start_time = now.timestamp() as u64;
    // Duration of the election
    let duration = 60 * 60; // 1 hour in seconds
    let election_name = "Libertad 2024".to_string();
    let mut election =
        election::Election::new(election_name, candidates.clone(), start_time, duration);
    // Timestamp for the expiration of the election
    let future = now + chrono::Duration::days(5);
    let secs = future.timestamp() as u64;
    let future_ts = Timestamp::from(secs);
    println!("🗳️ Election: {}", election.as_json());
    // We publish the candidates list in a custom event with kind 35_000
    let event = EventBuilder::new(Kind::Custom(35_000), election.as_json())
        .tag(Tag::identifier(election.id.to_string()))
        .tag(Tag::expiration(future_ts))
        .sign(&keys)
        .await?;

    // Publish the event to the relay
    client.send_event(&event).await?;

    println!("🎁 Event with the list of candidates sent!");
    let file_path = "voters_pubkeys.json";
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
                let voter = event.sender;
                let message = match Message::from_json(&event.rumor.content) {
                    Ok(m) => m,
                    Err(e) => {
                        log::warn!("Error parsing message: {}", e);
                        continue;
                    }
                };
                // Check if the message is a token request
                match message.kind {
                    1 => {
                        log::info!("Token request received: {}", message.content);
                        let decoded_bytes = match general_purpose::STANDARD.decode(message.content)
                        {
                            Ok(bytes) => bytes,
                            Err(e) => {
                                log::warn!("Error decoding content: {}", e);
                                continue;
                            }
                        };
                        let h_n = BigUint::from_bytes_be(&decoded_bytes);
                        let req = BlindTokenRequest {
                            voter_pk: voter.to_string(),
                            blinded_hash: h_n,
                        };
                        // Issue token
                        let blind_sig = match election.issue_token(req) {
                            Ok(token) => token,
                            Err(e) => {
                                log::warn!("Error issuing token: {}", e);
                                continue;
                            }
                        };
                        // Encode token to Base64
                        let h_n_b64 = general_purpose::STANDARD.encode(blind_sig.to_bytes_be());
                        let message = Message::new(message.id.clone(), 1, h_n_b64.clone());
                        log::info!("Blind Token content: {:#?}", message);
                        // Creates a "rumor" with the hash of the nonce.
                        let rumor: UnsignedEvent =
                            EventBuilder::text_note(message.as_json()).build(keys.public_key());

                        // Wraps the rumor in a Gift Wrap.
                        let gift_wrap =
                            match EventBuilder::gift_wrap(&keys, &voter, rumor, None).await {
                                Ok(ev) => ev,
                                Err(e) => {
                                    log::warn!("Unable to build GiftWrap for {}: {}", voter, e);
                                    continue;
                                }
                            };

                        // Send the Gift Wrap
                        if let Err(e) = client.send_event(&gift_wrap).await {
                            log::warn!("Failed to send GiftWrap to {}: {}", voter, e);
                        }

                        log::info!("Token request sent to: {}", voter);
                    }
                    2 => {
                        log::info!("Vote received: {}", message.content);
                    }
                    _ => {
                        log::warn!("Unknown message kind: {}", message.kind);
                        continue;
                    }
                }
                let _ = tx.send(event).await;
            }
        }
    });
    loop {
        // Check for new orders without blocking
        while let Ok(event) = rx.try_recv() {
            // log::info!("New event rx: {:#?}", event);
        }
    }
}
