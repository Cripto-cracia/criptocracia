use nostr_sdk::{Client, event::Event};
use num_bigint_dig::{BigUint, RandBigInt};
use rand::rngs::OsRng;
use sha2::{Digest, Sha256};

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum Status {
    Open,
    InProgress,
    Finished,
    Canceled,
}

#[derive(Debug, serde::Deserialize)]
pub struct Candidate {
    pub id: u8,
    pub name: String,
}

impl Candidate {
    pub fn new(id: u8, name: String) -> Self {
        Self { id, name }
    }
}

#[derive(Debug, serde::Deserialize)]
pub struct Election {
    pub id: String,
    pub name: String,
    pub candidates: Vec<Candidate>,
    pub start_time: u64,
    pub end_time: u64,
    pub status: Status,
}

impl Election {
    pub fn new(
        id: String,
        name: String,
        candidates: Vec<Candidate>,
        start_time: u64,
        duration: u64,
    ) -> Self {
        let end_time = start_time + duration;
        // Validate that ID follows expected format (4-character hex string)
        debug_assert!(
            id.len() == 4 && id.chars().all(|c| c.is_ascii_hexdigit()),
            "Election ID should be a 4-character hex string"
        );
        Self {
            id,
            name,
            candidates,
            start_time,
            end_time,
            status: Status::Open,
        }
    }

    pub fn parse_event(event: &Event) -> Result<Self, anyhow::Error> {
        let data = event.content.clone();
        let election = serde_json::from_str(&data);

        let election = match election {
            Ok(e) => e,
            Err(e) => {
                return Err(anyhow::anyhow!("Failed to parse election event: {}", e));
            }
        };

        Ok(election)
    }
}

//     pub async fn obtain_token(&self, client: Client) -> BigUint {
//         // Create random nonce and hash it.
//         let nonce: BigUint = OsRng.gen_biguint(128);
//         let h_n_bytes = &Sha256::digest(&nonce.to_bytes_be());
//         // Coding to Base64.
//         let h_n_b64 = general_purpose::STANDARD.encode(&h_n_bytes);

//         // Creates a "rumor" with the hash of the nonce.
//         let rumor: UnsignedEvent = EventBuilder::text_note(h_n_b64).build(keys.public_key());

//         // Wraps the rumor in a Gift Wrap.
//         let gift_wrap: Event = EventBuilder::gift_wrap(&keys, &ec_pubkey, rumor, None).await?;

//         // Send the Gift Wrap
//         client.send_event(&gift_wrap).await?;

//         log::info!("Token request sent: {}", gift_wrap.id);
//         // Wait for the Gift Wrap to be unwrapped.
//         let unwrap_event = client
//             .wait_for_event(&gift_wrap.id, 10)
//             .await
//             .ok_or_else(|| anyhow::anyhow!("Failed to unwrap gift wrap"))?;
//         tokio::time::sleep(std::time::Duration::from_secs(2)).await;
//     }
// }
