pub mod cli;

use anyhow::Result;
use nostr_sdk::prelude::*;
use cli::CLIArgs;
use std::str::FromStr;
use clap::Parser;
use num_bigint_dig::{BigUint, RandBigInt};
use rand::rngs::OsRng;
use sha2::{Digest, Sha256};
use base64::engine::{general_purpose, Engine};

#[tokio::main]
async fn main() -> Result<()> {
    // Parse CLI arguments
    let parsed_args = CLIArgs::parse();
    let ec_pubkey = PublicKey::from_str(&parsed_args.electoral_commission_pubkey)?;
    let election_id = parsed_args.election_id;
    let vote = parsed_args.vote;
    let keys = Keys::new(
        SecretKey::from_str(&parsed_args.secret).expect("Invalid secret key"),
    );

    println!("🔑 Public key bech32: {}", keys.public_key().to_bech32()?);

    // Construye el cliente firmante
    let client = Client::builder()
        .signer(keys.clone())
        .build();

    // Añade el relay Mostro y conéctate
    client.add_relay("wss://relay.mostro.network").await?;
    client.connect().await;
    // 1. Create random nonce and hash it.
    let nonce: BigUint = OsRng.gen_biguint(128);
    let h_n_bytes = Sha256::digest(&nonce.to_bytes_be());
    // 2. Coding to Base64.
    let h_n_b64 = general_purpose::STANDARD.encode(&h_n_bytes);

    // 3. Creates a "rumor" with the hash of the nonce.
    let rumor: UnsignedEvent = EventBuilder::text_note(h_n_b64).build(keys.public_key());

    // 4. Wraps the rumor in a Gift Wrap.
    let gift_wrap: Event = EventBuilder::gift_wrap(
        &keys,
        &ec_pubkey,
        rumor,
        None
    ).await?;

    // Publica el Gift Wrap en el relay
    client.send_event(&gift_wrap).await?;

    println!("🎁 Gift Wrap sent…");
    tokio::time::sleep(std::time::Duration::from_secs(2)).await;

    Ok(())
}
