mod database;
mod election;
mod grpc;
mod types;
mod util;

use crate::database::Database;
use crate::election::Election;
use crate::grpc::server::GrpcServer;
use crate::util::{load_keys, load_keys_from_pem, setup_logger, validate_required_files};

use anyhow::Result;
use base64::{Engine as _, engine::general_purpose};
use blind_rsa_signatures::{BlindedMessage, MessageRandomizer, Options, Signature as RSASignature};
use clap::Parser;
use election::BlindTokenRequest;
use nostr_sdk::prelude::*;
use num_bigint_dig::BigUint;
use std::{collections::HashMap, fs, path::PathBuf, sync::Arc};
use tokio::{
    sync::{Mutex, mpsc},
    time::Duration,
};
use types::{Candidate, Message};

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Directory to store application data and keys
    #[arg(short, long, default_value = "")]
    dir: String,
}

/// Load elections from database and restore their state
async fn load_elections_from_database(db: &Database) -> Result<Vec<Election>> {
    let election_records = db.load_all_elections().await?;
    let mut elections = Vec::new();

    for election_record in election_records {
        // Load candidates for this election
        let candidate_records = db.get_candidates(&election_record.id).await?;

        // Load authorized voters for this election
        let authorized_voters = db.load_election_voters(&election_record.id).await?;

        // Load used tokens for this election
        let used_tokens = db.load_used_tokens(&election_record.id).await?;

        // Restore the election from database records
        let election = Election::from_database(
            election_record,
            candidate_records,
            authorized_voters,
            used_tokens,
        );

        log::info!("Loaded election: {} (ID: {})", election.name, election.id);
        elections.push(election);
    }

    Ok(elections)
}

/// Publish the state of the election
async fn publish_election_event(
    client: &Client,
    keys: &Keys,
    election: &Election,
    db: &Database,
) -> Result<()> {
    log::info!(
        "Publishing election {} status: {:?}",
        election.id,
        election.status
    );
    // Old election events are expired after 15 days
    let expire_ts = chrono::Utc::now()
        .checked_add_signed(chrono::Duration::days(15))
        .unwrap()
        .timestamp() as u64;
    let future_ts = Timestamp::from(expire_ts);
    let event = EventBuilder::new(Kind::Custom(35_000), election.as_json_string())
        .tag(Tag::identifier(election.id.to_string()))
        .tag(Tag::expiration(future_ts))
        .sign(keys)
        .await?;

    client.send_event(&event).await?;
    log::info!(
        "Event with election {} status {:?} broadcast to Nostr relays!",
        election.id,
        election.status
    );

    // Save election to database
    db.upsert_election(election).await?;
    log::info!("Election {} saved to database", election.id);

    Ok(())
}

#[tokio::main]
async fn main() -> Result<()> {
    // Parse command line arguments
    let args = Args::parse();

    // Determine the application directory
    let app_dir = if args.dir.is_empty() {
        // Use default directory: $HOME/.ec/
        let home_dir = std::env::var("HOME").unwrap_or_else(|_| ".".to_string());
        PathBuf::from(home_dir).join(".ec")
    } else {
        PathBuf::from(args.dir)
    };

    // Create the directory if it doesn't exist
    if !app_dir.exists() {
        fs::create_dir_all(&app_dir)?;
        println!("Created directory: {}", app_dir.display());
    }

    // Validate that all required files exist
    validate_required_files(&app_dir)?;

    // Initialize logger
    setup_logger(log::LevelFilter::Info, app_dir.join("app.log")).expect("Can't initialize logger");
    log::info!("Criptocracia started");
    log::info!("Using directory: {}", app_dir.display());

    // Initialize database
    let db = Arc::new(Database::new(app_dir.join("elections.db")).await?);
    log::info!("Database initialized successfully");

    // Load Nostr keys from environment variable
    let keys = if let Ok(nostr_private_key) = std::env::var("NOSTR_PRIVATE_KEY") {
        Keys::parse(&nostr_private_key)?
    } else {
        return Err(anyhow::anyhow!("NOSTR_PRIVATE_KEY environment variable is required"));
    };

    // 1. Load the keys from environment variables or fallback to files
    let (pk, sk) = if let (Ok(private_pem), Ok(public_pem)) = (
        std::env::var("EC_PRIVATE_KEY"),
        std::env::var("EC_PUBLIC_KEY"),
    ) {
        // Load keys from environment variables
        load_keys_from_pem(&private_pem, &public_pem)?
    } else {
        // Fallback to loading from files in app directory
        load_keys(
            app_dir.join("ec_private.pem"),
            app_dir.join("ec_public.pem"),
        )?
    };
    let pk_der = pk.to_der()?;
    // We need to encode the RSA public key in Base64 to publish it on Nostr
    let pk_der_b64 = general_purpose::STANDARD.encode(&pk_der);

    println!(
        "🔑 Electoral Commission Nostr Public key: {}",
        keys.public_key()
    );

    // Build the signing client
    let client = Client::builder().signer(keys.clone()).build();

    // Add the Mostro relay and connect
    client.add_relay("wss://relay.mostro.network").await?;
    client.connect().await;

    // Load elections from database and store in HashMap
    let elections_vec = load_elections_from_database(&db).await?;
    let mut elections_map = HashMap::new();

    for election in elections_vec {
        elections_map.insert(election.id.clone(), election);
    }

    if elections_map.is_empty() {
        log::info!("No elections found in database. Starting with empty state.");
        println!(
            "🗳️ Electoral Commission started with no elections. Use gRPC admin API to create elections."
        );
    } else {
        log::info!("Loaded {} elections from database", elections_map.len());
        println!(
            "🗳️ Electoral Commission started with {} elections loaded from database",
            elections_map.len()
        );

        // Display loaded elections
        for (id, election) in &elections_map {
            println!(
                "📋 Election: {} (ID: {}, Status: {:?})",
                election.name, id, election.status
            );
        }
    }

    let elections = Arc::new(Mutex::new(elections_map));

    // Start periodic election status checker
    {
        let elections_clone = Arc::clone(&elections);
        let db_clone = Arc::clone(&db);
        let client_clone = client.clone();
        let keys_clone = keys.clone();
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(Duration::from_secs(30));
            loop {
                interval.tick().await;

                let current_time = chrono::Utc::now().timestamp() as u64;
                let mut elections_to_update = Vec::new();

                // Check and update election statuses
                {
                    let mut elections_guard = elections_clone.lock().await;
                    for (election_id, election) in elections_guard.iter_mut() {
                        if election.update_status_based_on_time(current_time) {
                            log::info!(
                                "Election {} status changed to {:?}",
                                election_id,
                                election.status
                            );
                            elections_to_update.push(election.clone());
                        }
                    }
                }

                // Persist status changes and publish to Nostr
                for election in elections_to_update {
                    // Save to database
                    if let Err(e) = db_clone.upsert_election(&election).await {
                        log::error!(
                            "Failed to update election {} in database: {}",
                            election.id,
                            e
                        );
                    }

                    // Publish to Nostr
                    if let Err(e) =
                        publish_election_event(&client_clone, &keys_clone, &election, &db_clone)
                            .await
                    {
                        log::error!(
                            "Failed to publish election {} status update to Nostr: {}",
                            election.id,
                            e
                        );
                    }
                }
            }
        });
    }
    let subscription = Filter::new()
        .pubkey(keys.public_key())
        .kind(Kind::GiftWrap)
        .limit(0);
    // Client subscription
    client.subscribe(subscription, None).await?;
    // Set up channel for real-time order updates
    let (tx, mut rx) = mpsc::channel(100);
    {
        let client = client.clone();
        let elections = Arc::clone(&elections);
        let keys = keys.clone();
        let tx = tx.clone();
        let db = Arc::clone(&db);
        // Spawn a task to handle Nostr events
        tokio::spawn(async move {
            let mut notifications = client.notifications();
            while let Ok(notification) = notifications.recv().await {
                if let RelayPoolNotification::Event { event, .. } = notification {
                    // Validate event signature
                    if event.verify().is_err() {
                        log::warn!("Event failed signature verification – ignored");
                        continue;
                    };
                    let event = match nip59::extract_rumor(&keys, &event).await {
                        Ok(u) => u,
                        Err(e) => {
                            log::warn!("Error unwrapping gift: {}", e);
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
                            log::info!("Token request received: {:#?}", message);
                            let blinded_bytes =
                                match general_purpose::STANDARD.decode(message.payload) {
                                    Ok(bytes) => bytes,
                                    Err(e) => {
                                        log::warn!("Error decoding content: {}", e);
                                        continue;
                                    }
                                };
                            let blinded_h_n = BlindedMessage::from(blinded_bytes);
                            let req = BlindTokenRequest {
                                voter_pk: voter.to_string(),
                                blinded_h_n,
                            };
                            // Handle election-specific or legacy token requests
                            let mut blind_sig = None;
                            {
                                let mut elections_guard = elections.lock().await;
                                
                                if let Some(election_id) = &message.election_id {
                                    // New protocol: election-specific token request
                                    if let Some(election) = elections_guard.get_mut(election_id) {
                                        let req_copy = BlindTokenRequest {
                                            voter_pk: req.voter_pk.clone(),
                                            blinded_h_n: req.blinded_h_n.clone(),
                                        };
                                        match election.issue_token(req_copy, sk.clone()) {
                                            Ok(token) => {
                                                blind_sig = Some(token);
                                                log::info!("Token issued for election {}", election_id);
                                            }
                                            Err(e) => {
                                                log::warn!("Token request failed for election {}: {}", election_id, e);
                                            }
                                        }
                                    } else {
                                        log::warn!("Election {} not found", election_id);
                                    }
                                } else {
                                    // Legacy protocol: try all elections (for backward compatibility)
                                    log::warn!("Legacy token request without election_id - trying all elections");
                                    for (_election_id, election) in elections_guard.iter_mut() {
                                        let req_copy = BlindTokenRequest {
                                            voter_pk: req.voter_pk.clone(),
                                            blinded_h_n: req.blinded_h_n.clone(),
                                        };
                                        match election.issue_token(req_copy, sk.clone()) {
                                            Ok(token) => {
                                                blind_sig = Some(token);
                                                break;
                                            }
                                            Err(_) => continue, // Try next election
                                        }
                                    }
                                }
                            }

                            let blind_sig = match blind_sig {
                                Some(sig) => sig,
                                None => {
                                    if message.election_id.is_some() {
                                        log::warn!("Voter {} not authorized for election {:?}", voter, message.election_id);
                                    } else {
                                        log::warn!("Voter {} not authorized for any election", voter);
                                    }
                                    continue;
                                }
                            };
                            // Encode token to Base64
                            let blind_sig_b64 = general_purpose::STANDARD.encode(blind_sig);
                            let response =
                                Message::new(message.id.clone(), 1, blind_sig_b64.clone());
                            // Creates a "rumor" with the hash of the nonce.
                            let rumor: UnsignedEvent = EventBuilder::text_note(response.as_json())
                                .build(keys.public_key());

                            // Wraps the rumor in a Gift Wrap.
                            let gift_wrap =
                                match EventBuilder::gift_wrap(&keys, &voter, rumor, None).await {
                                    Ok(ev) => ev,
                                    Err(e) => {
                                        log::warn!("Unable to build GiftWrap for {}: {}", voter, e);
                                        continue;
                                    }
                                };

                            match client.send_event(&gift_wrap).await {
                                Ok(_) => log::info!("Blind signature sent to: {}", voter),
                                Err(e) => log::error!("Failed to send blind signature: {}", e),
                            }
                        }
                        2 => {
                            // Split the incoming vote message into parts.
                            let parts: Vec<&str> = message.payload.split(':').collect();
                            if parts.len() != 4 {
                                log::warn!("Invalid vote format: {}", message.payload);
                                continue;
                            }

                            // Decode h_n from Base64
                            let h_n_bytes = match general_purpose::STANDARD.decode(parts[0]) {
                                Ok(bytes) => bytes,
                                Err(e) => {
                                    log::warn!("Failed to decode h_n: {}", e);
                                    continue;
                                }
                            };
                            let h_n = BigUint::from_bytes_be(&h_n_bytes);

                            // Decode token from Base64
                            let token_bytes = match general_purpose::STANDARD.decode(parts[1]) {
                                Ok(b) => b,
                                Err(_) => continue,
                            };
                            let token: RSASignature = RSASignature::from(token_bytes.clone());

                            // Decode MessageRandomizer from Base64
                            let r_bytes = match general_purpose::STANDARD.decode(parts[2]) {
                                Ok(b) => b,
                                Err(_) => continue,
                            };
                            let rand_arr: [u8; 32] = match <[u8; 32]>::try_from(&r_bytes[..]) {
                                Ok(arr) => arr,
                                Err(_) => {
                                    log::warn!("Invalid randomizer length");
                                    continue;
                                }
                            };
                            let msg_rand = MessageRandomizer::from(rand_arr);

                            // Parse vote as an integer
                            let vote = match parts[3].parse::<u8>() {
                                Ok(v) => v,
                                Err(e) => {
                                    log::warn!("Failed to parse vote: {}", e);
                                    continue;
                                }
                            };
                            let options = Options::default();
                            // Verify the signature on the raw h_n_bytes
                            if token
                                .verify(&pk, Some(msg_rand), &h_n_bytes, &options)
                                .is_err()
                            {
                                log::warn!("Invalid token signature");
                                continue;
                            }

                            // Handle election-specific or legacy vote submission
                            let mut vote_accepted = false;
                            let mut tally = HashMap::new();
                            let mut election_id_for_results = String::new();
                            {
                                let mut elections_guard = elections.lock().await;
                                
                                if let Some(election_id) = &message.election_id {
                                    // New protocol: election-specific vote submission
                                    if let Some(election) = elections_guard.get_mut(election_id) {
                                        match election.receive_vote(h_n.clone(), vote) {
                                            Ok(()) => {
                                                vote_accepted = true;
                                                election_id_for_results = election_id.clone();
                                                log::info!("Vote accepted for election {}", election_id);

                                                // Save used token to database
                                                if let Err(e) =
                                                    election.save_used_token_to_db(&db, &h_n).await
                                                {
                                                    log::error!(
                                                        "Failed to save used token to database: {}",
                                                        e
                                                    );
                                                }

                                                // Get tally for this election
                                                tally = election.tally();
                                            }
                                            Err(e) => {
                                                log::warn!("Vote rejected for election {}: {}", election_id, e);
                                            }
                                        }
                                    } else {
                                        log::warn!("Election {} not found for vote submission", election_id);
                                    }
                                } else {
                                    // Legacy protocol: try all elections (for backward compatibility)
                                    log::warn!("Legacy vote submission without election_id - trying all elections");
                                    for (election_id, election) in elections_guard.iter_mut() {
                                        match election.receive_vote(h_n.clone(), vote) {
                                            Ok(()) => {
                                                vote_accepted = true;
                                                election_id_for_results = election_id.clone();

                                                // Save used token to database
                                                if let Err(e) =
                                                    election.save_used_token_to_db(&db, &h_n).await
                                                {
                                                    log::error!(
                                                        "Failed to save used token to database: {}",
                                                        e
                                                    );
                                                }

                                                // Get tally for this election
                                                tally = election.tally();
                                                break;
                                            }
                                            Err(_) => continue, // Try next election
                                        }
                                    }
                                }
                            }

                            if !vote_accepted {
                                if message.election_id.is_some() {
                                    log::warn!("Vote not accepted for election {:?}", message.election_id);
                                } else {
                                    log::warn!("Vote not accepted by any election");
                                }
                                continue;
                            }

                            let election_id = election_id_for_results;

                            let mut results = String::new();
                            let mut json_results: Vec<(u8, u32)> = Vec::new();
                            for (cand, count) in &tally {
                                results.push_str(&format!("{}: {} vote(s)\n", cand.name, count));
                                json_results.push((cand.id, *count));
                            }
                            let json_string = match serde_json::to_string(&json_results) {
                                Ok(json) => json,
                                Err(err) => {
                                    log::error!(
                                        "Failed to serialize election results to JSON: {}",
                                        err
                                    );
                                    continue;
                                }
                            };

                            let expire_ts = chrono::Utc::now()
                                .checked_add_signed(chrono::Duration::days(5))
                                .unwrap()
                                .timestamp() as u64;
                            let future_ts = Timestamp::from(expire_ts);
                            println!("🗳️ Election's result: \n\n{}", results);

                            // Update vote counts in database
                            if let Err(err) =
                                db.update_vote_counts(&election_id, &json_results).await
                            {
                                log::error!("Failed to update vote counts in database: {}", err);
                            }

                            // We publish the results in a custom event with kind 35_001
                            match EventBuilder::new(Kind::Custom(35_001), json_string)
                                .tag(Tag::identifier(election_id.clone()))
                                .tag(Tag::expiration(future_ts))
                                .sign(&keys)
                                .await
                            {
                                Ok(event) => {
                                    // Publish the event to the relay
                                    match client.send_event(&event).await {
                                        Ok(_) => {
                                            log::info!("Election results published successfully")
                                        }
                                        Err(e) => log::error!("Failed to publish results: {}", e),
                                    }
                                }
                                Err(e) => log::error!("Failed to sign results event: {}", e),
                            };
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
    }

    // Start gRPC server for admin operations
    {
        let db_clone = Arc::clone(&db);
        let elections_clone = Arc::clone(&elections);
        let pk_der_b64_clone = pk_der_b64.clone();
        let client_clone = Arc::new(client.clone());
        let keys_clone = Arc::new(keys.clone());
        tokio::spawn(async move {
            let grpc_server = GrpcServer::default(); // Uses port 50001
            log::info!("Starting gRPC admin server on port {}", grpc_server.port);
            if let Err(e) = grpc_server
                .start(
                    db_clone,
                    elections_clone,
                    pk_der_b64_clone,
                    client_clone,
                    keys_clone,
                )
                .await
            {
                log::error!("gRPC server failed: {}", e);
            }
        });
    }

    loop {
        // Check for new orders without blocking
        while let Ok(_event) = rx.try_recv() {
            // log::info!("New event rx: {:#?}", event);
        }
    }
}
