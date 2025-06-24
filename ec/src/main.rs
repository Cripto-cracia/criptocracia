mod election;
mod types;
mod util;

use crate::election::{Election, Status};
use crate::util::{load_keys, setup_logger};

use anyhow::Result;
use base64::{Engine as _, engine::general_purpose};
use blind_rsa_signatures::{BlindedMessage, MessageRandomizer, Options, Signature as RSASignature};
use election::BlindTokenRequest;
use nostr_sdk::prelude::*;
use num_bigint_dig::BigUint;
use std::{
    fs,
    sync::{Arc, Mutex},
};
use tokio::{
    sync::mpsc,
    time::{Duration, Instant, sleep_until},
};
use types::{Candidate, Message, Voter};

// Demo keys for the electoral commission:
// Hex public key:   0000001ace57d0da17fc18562f4658ac6d093b2cc8bb7bd44853d0c196e24a9c
// Hex private key:  e3f33350728580cd51db8f4048d614910d48a5c0d7f1af6811e83c07fc865a5c
// Npub public key:  npub1qqqqqxkw2lgd59lurptz73jc43ksjwevezahh4zg20gvr9hzf2wq8nzqyl
// Nsec private key: nsec1u0enx5rjskqv65wm3aqy34s5jyx53fwq6lc676q3aq7q0lyxtfwqph3yue

/// Publish the state of the election
async fn publish_election_event(client: &Client, keys: &Keys, election: &Election) -> Result<()> {
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
    Ok(())
}

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize logger
    setup_logger(log::LevelFilter::Info).expect("Can't initialize logger");
    log::info!("Criptocracia started");
    let keys = Keys::parse("e3f33350728580cd51db8f4048d614910d48a5c0d7f1af6811e83c07fc865a5c")?;

    // 1. Load the keys from PEM files
    let (pk, sk) = load_keys("ec_private.pem", "ec_public.pem")?;
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
    // The election starts in 60 seconds
    let starting_ts = chrono::Utc::now().timestamp() as u64 + 60; // 1 minute from now
    // Duration of the election
    let duration = 60 * 60; // 1 hour in seconds
    let election = Election::new(
        "Libertad 2024".to_string(),
        vec![
            Candidate::new(1, "Donkey 🫏"),
            Candidate::new(2, "Rat 🐀"),
            Candidate::new(3, "Sheep 🐑"),
            Candidate::new(4, "Sloth 🦥"),
        ],
        starting_ts,
        duration,
        pk_der_b64,
    );
    let election = Arc::new(Mutex::new(election));
    // --- Timers to change status automatically ---
    {
        let election = Arc::clone(&election);
        let keys = keys.clone();
        let client = client.clone();
        tokio::spawn(async move {
            let start_ts = {
                let e = election.lock().unwrap();
                e.start_time
            };
            let now = chrono::Utc::now().timestamp() as u64;
            let delay = start_ts.saturating_sub(now);
            sleep_until(Instant::now() + Duration::from_secs(delay)).await;
            let e_data = {
                let mut e = election.lock().unwrap();
                e.status = Status::InProgress;
                log::info!("Election {} -> InProgress", e.id);
                e.clone()
            };
            // Publish the event with the new status
            if let Err(err) = publish_election_event(&client, &keys, &e_data).await {
                log::error!(
                    "Error publishing election with status {:?}: {}",
                    e_data.status,
                    err
                );
            }
        });
    }
    {
        let election = Arc::clone(&election);
        let keys = keys.clone();
        let client = client.clone();
        tokio::spawn(async move {
            let end_ts = {
                let e = election.lock().unwrap();
                e.end_time
            };
            let now = chrono::Utc::now().timestamp() as u64;
            let delay = end_ts.saturating_sub(now);
            sleep_until(Instant::now() + Duration::from_secs(delay)).await;
            let e_data = {
                let mut e = election.lock().unwrap();
                e.status = Status::Finished;
                log::info!("Election {} -> Finished", e.id);
                e.clone()
            };
            // Publish the event with the new status
            if let Err(err) = publish_election_event(&client, &keys, &e_data).await {
                log::error!(
                    "Error publishing election with status {:?}: {}",
                    e_data.status,
                    err
                );
            }
        });
    }
    let e_data = {
        let e = election.lock().unwrap();
        e.clone()
    };
    if let Err(err) = publish_election_event(&client, &keys, &e_data).await {
        log::error!(
            "Error publishing election with status {:?}: {}",
            e_data.status,
            err
        );
    }

    // --- Register voters ---
    let voters: Vec<Voter> = serde_json::from_str(&fs::read_to_string("voters_pubkeys.json")?)?;
    {
        let mut e = election.lock().unwrap();
        for v in &voters {
            e.register_voter(&v.pubkey);
            println!("👤 Registered {}", v.name);
        }
    }
    println!("Election id: {}", election.lock().unwrap().id);
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
        let election = Arc::clone(&election);
        let keys = keys.clone();
        let tx = tx.clone();
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
                            println!("Error unwrapping gift: {:#?}", e);
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
                            // Issue token
                            let blind_sig =
                                match election.lock().unwrap().issue_token(req, sk.clone()) {
                                    Ok(token) => token,
                                    Err(e) => {
                                        log::warn!("Error issuing token: {}", e);
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

                            if let Err(e) = election.lock().unwrap().receive_vote(h_n, vote) {
                                log::warn!("Error receiving vote: {}", e);
                                continue;
                            }
                            // Tally the votes
                            let tally = election.lock().unwrap().tally();
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

                            let (election_id, expire_ts) = {
                                let e = election.lock().unwrap();
                                (
                                    e.id.clone(),
                                    chrono::Utc::now()
                                        .checked_add_signed(chrono::Duration::days(5))
                                        .unwrap()
                                        .timestamp() as u64,
                                )
                            };
                            let future_ts = Timestamp::from(expire_ts);
                            println!("🗳️ Election's result: \n\n{}", results);
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
    loop {
        // Check for new orders without blocking
        while let Ok(_event) = rx.try_recv() {
            // log::info!("New event rx: {:#?}", event);
        }
    }
}
