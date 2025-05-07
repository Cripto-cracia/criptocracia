mod election;
mod types;

use anyhow::Result;
use base64::{Engine as _, engine::general_purpose};
use blind_rsa_signatures::{
    BlindedMessage, MessageRandomizer, Options, PublicKey as RSAPublicKey,
    SecretKey as RSASecretKey, Signature as RSASignature,
};
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

// Demo RSA keys for the electoral commission:
const EC_PRIVATE_PEM: &str = r#"-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDLOuMoqXPwmnIq
uqcI2vaf+JfBKAcCes3JnA4npRbhpy3EOcjd3LB46pe0ZnIiDj494SYOtNjmw/qk
3anmpUzpcaa3sMJ9K0mBoKkHQP8Fl39qv+yH1qP0BMtB7bj9QNfB4ZODNZWyTLy4
JE4NzNrGEM9e/BEBAgK5k07c7FDmyzu5zVl9INL77znuryTood1udaQDLf42gayV
laohAf+H20OXzN8ofkA/kxmJt2dr78/bBvPzr/y6r6EG6nHDKamJBfEsHut+N86Q
tfbZaC6x6i+lsD/sh/cs2d53lS7FfUjG4XMG3DtbVEDLwHUyqUCht/kr57hfMDOX
j0CpCfqzAgMBAAECggEAF4PNyuOofZtxQE5ui1DCnonmDTxzay8IZp5+6MlqV1u/
qOfCvSEO7j6+pOoBpL0fKIvHmoYEXtcoRjE7ums/9fbngnOaXV9H1w7e3+7+UwhP
fuuME7+bIt33Ir6929fH3zAZoGHv2zyTzX6t5Vzhp29Ef0oNMZ+o7w4DXv6c8cc3
Wpl52suNclz//p7tkGYjtHNGAabSmoFYZhBEjTHclhgPCs3hkgIiSXiT4c28O+hn
pPjqjY+ALiAQ6TMCuB250kSHKHWLcTEdEqCI4nbtiCe852csBsZeYSiZ3HILZhSd
5/PLkXLRttC+HmQ946GlrCOhyFrIewvMhMT6QF12MQKBgQDYJ0+njfucgzdLJ9f2
+TM/JgDmUbn2cJ114G5lvFsosQvSVjXK62QSDBWtjdLMDJkU7CQSg8amhgZPgzBu
zsGRf6Mi4cb9YrXTqGJ87pPhtbHsp6K0kQtjWpk8Yy0JgDdXR9BwAnrHwnYUeupq
zmaKUUUzFg9FVktLFtk+/Bj+iQKBgQDwsbDTYYJy8CUzbEyw2C6BTBpRKH7tF32N
ufViHrAHfQV8tJQP0eQwTr0Uqx5vocGg7OjFVT1OUY0pXYNkHGWZCGUnldcbOCam
r44zbVEk8YJC0Z9fM5G9U/U/Ost40lrGB0NlwY6d18fTjpIJ/aWM5fW6+pUSDH89
FeDhdQuAWwKBgAyhz3/lRk0RRgv4WiCu05XfLLJJGGsUjb8zzH/ZkCJCpoQ2UZJ4
SzLazfGElksieVfFrR3/4X4d2wSOkCgJoTpVkT0aoLxyJlomPws6Dh5kte80pMeU
qmu2AbqLuTgS7CkHo2DIZFCERs5PmJ+BTHDM6xRfN6k/r8rFnRCXPwaxAoGAfj9F
l2oS6USqzpEknLGXmvwW5bDO+n8SvO7oFYIxJIxf/2wcKTwXa3sxVBD5UuZOUKFS
6oZuNJEz8Jl7HFyEscMkg6HlhQJry4xTkwfowu7mOzQGWwIKlHrgLT0ikooLUMlo
gYwHySTwTDgAw7rGReQsgtmCrUfeyWSbYsZotPcCgYEAmpNvn6N8dApA1Bxo+Phq
iMyOqgt3twtvMeb+PgttHbN1PAidB7y/tuqHhNSugOSYnejxPL+usZovQOrR4I/2
eEsAyGyHwxeg5E6IHfia87NPjMzV2dm+k+dzN08Wy3aNwAQTRgngNc8aN+dsmU7Y
W+aipD7vvxPN16yBxqWo/Ts=
-----END PRIVATE KEY-----"#;

const EC_PUBLIC_PEM: &str = r#"-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAyzrjKKlz8JpyKrqnCNr2
n/iXwSgHAnrNyZwOJ6UW4actxDnI3dyweOqXtGZyIg4+PeEmDrTY5sP6pN2p5qVM
6XGmt7DCfStJgaCpB0D/BZd/ar/sh9aj9ATLQe24/UDXweGTgzWVsky8uCRODcza
xhDPXvwRAQICuZNO3OxQ5ss7uc1ZfSDS++857q8k6KHdbnWkAy3+NoGslZWqIQH/
h9tDl8zfKH5AP5MZibdna+/P2wbz86/8uq+hBupxwympiQXxLB7rfjfOkLX22Wgu
seovpbA/7If3LNned5UuxX1IxuFzBtw7W1RAy8B1MqlAobf5K+e4XzAzl49AqQn6
swIDAQAB
-----END PUBLIC KEY-----"#;

fn load_keys() -> Result<(RSAPublicKey, RSASecretKey)> {
    let sk = RSASecretKey::from_pem(EC_PRIVATE_PEM)?;
    let pk = RSAPublicKey::from_pem(EC_PUBLIC_PEM)?;

    Ok((pk, sk))
}

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

    // 1. Load the keys from PEM files
    let (pk, sk) = load_keys().expect("Failed to load keys");

    println!("🔑 Electoral Commission Public key: {}", keys.public_key());

    // Build the signing client
    let client = Client::builder().signer(keys.clone()).build();

    // Add the Mostro relay and connect
    client.add_relay("wss://relay.mostro.network").await?;
    client.connect().await;

    let candidates: Vec<Candidate> = vec![
        Candidate::new(1, "Donkey 🫏"),
        Candidate::new(2, "Rat 🐀"),
        Candidate::new(3, "Sheep 🐑"),
        Candidate::new(4, "Sloth 🦥"),
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

    // We publish the candidates list in a custom event with kind 35_000
    let event = EventBuilder::new(Kind::Custom(35_000), election.as_json_string())
        .tag(Tag::identifier(election.id.to_string()))
        .tag(Tag::expiration(future_ts))
        .sign(&keys)
        .await?;

    // Publish the event to the relay
    client.send_event(&event).await?;

    println!("🎁 Event with the list of candidates broadcast to Nostr relays!");
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
                        log::info!("Token request received: {:#?}", message);
                        let blinded_bytes = match general_purpose::STANDARD.decode(message.payload)
                        {
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
                        let blind_sig = match election.issue_token(req, sk.clone()) {
                            Ok(token) => token,
                            Err(e) => {
                                log::warn!("Error issuing token: {}", e);
                                continue;
                            }
                        };
                        // Encode token to Base64
                        let blind_sig_b64 = general_purpose::STANDARD.encode(blind_sig);
                        let response = Message::new(message.id.clone(), 1, blind_sig_b64.clone());
                        // Creates a "rumor" with the hash of the nonce.
                        let rumor: UnsignedEvent =
                            EventBuilder::text_note(response.as_json()).build(keys.public_key());

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
                        let msg_rand = MessageRandomizer::from(
                            <[u8; 32]>::try_from(&r_bytes[..]).expect("Invalid randomizer length"),
                        );

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

                        if let Err(e) = election.receive_vote(h_n, vote) {
                            log::warn!("Error receiving vote: {}", e);
                            continue;
                        }
                        // Tally the votes
                        let tally = election.tally();
                        let mut results = String::new();
                        for (cand, count) in &tally {
                            results.push_str(&format!("{}: {} vote(s)\n", cand.name, count));
                        }

                        let now = chrono::Utc::now();
                        // Timestamp for the expiration of the election
                        let future = now + chrono::Duration::days(5);
                        let secs = future.timestamp() as u64;
                        let future_ts = Timestamp::from(secs);
                        println!("🗳️ Election's result: \n\n{}", results);
                        // We publish the results in a custom event with kind 35_001
                        match EventBuilder::new(Kind::Custom(35_001), results)
                            .tag(Tag::identifier(election.id.to_string()))
                            .tag(Tag::expiration(future_ts))
                            .sign(&keys)
                            .await
                        {
                            Ok(event) => {
                                // Publish the event to the relay
                                match client.send_event(&event).await {
                                    Ok(_) => log::info!("Election results published successfully"),
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
    loop {
        // Check for new orders without blocking
        while let Ok(_event) = rx.try_recv() {
            // log::info!("New event rx: {:#?}", event);
        }
    }
}
