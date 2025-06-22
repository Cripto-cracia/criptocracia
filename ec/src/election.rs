/*! election.rs — Electoral Commission logic
Manages voter registration, issuance of blind tokens, vote reception, and counting. */

use blind_rsa_signatures::{BlindSignature, BlindedMessage, Options, SecretKey as RSASecretKey};
use nanoid::nanoid;
use nostr_sdk::PublicKey;
use num_bigint_dig::BigUint;
use rand::thread_rng;
use serde_json::Value;
use std::collections::{HashMap, HashSet};

use crate::Candidate;

/// Blind signature petition made by a voter.
pub struct BlindTokenRequest {
    pub voter_pk: String,
    pub blinded_h_n: BlindedMessage,
}

#[allow(dead_code)]
#[derive(Debug, PartialEq, Clone, Copy)]
pub enum Status {
    Open,
    InProgress,
    Finished,
    Canceled,
}

/// Commissioner of Elections (CE) manages the election process.
#[derive(Debug, Clone)]
pub struct Election {
    pub id: String,
    pub name: String,
    pub authorized_voters: HashSet<String>, // allowed pubkeys
    pub used_tokens: HashSet<BigUint>,      // h_n already used
    pub votes: Vec<u8>,                     // votes received
    pub candidates: Vec<Candidate>,
    pub start_time: u64,
    pub end_time: u64,
    pub status: Status,
    pub rsa_pub_key: String, // RSA public key for the EC
}

impl Election {
    /// Create a new EC with a 2048-bit RSA key.
    pub fn new(
        name: String,
        candidates: Vec<Candidate>,
        start_time: u64,
        duration: u64,
        rsa_pub_key: String,
    ) -> Self {
        let end_time = start_time + duration;
        let id = nanoid!(
            4,
            &[
                '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', 'a', 'b', 'c', 'd', 'e', 'f'
            ]
        );
        Self {
            id,
            name,
            authorized_voters: HashSet::new(),
            used_tokens: HashSet::new(),
            votes: vec![],
            candidates,
            start_time,
            end_time,
            status: Status::Open,
            rsa_pub_key,
        }
    }

    pub fn register_voter(&mut self, voter_pk: &str) {
        if self.status != Status::Open {
            log::warn!("Cannot register voter: election is not open");
            return;
        }
        println!("🔑 Registering voter: {}", voter_pk);

        // Convert npub to hex format if needed
        let hex_pubkey = if voter_pk.starts_with("npub") {
            match PublicKey::parse(voter_pk) {
                Ok(pk) => pk.to_hex(),
                Err(e) => {
                    log::warn!("Invalid npub format: {}", e);
                    return;
                }
            }
        } else {
            // Validate hex format
            match PublicKey::from_hex(voter_pk) {
                Ok(pk) => pk.to_hex(),
                Err(e) => {
                    log::warn!("Invalid pubkey format: {}", e);
                    return;
                }
            }
        };

        // 1) Check that the pubkey is not already registered.
        if self.authorized_voters.contains(&hex_pubkey) {
            println!("⚠️ Voter already registered");
            return;
        }
        // 2) Add to the list of authorized voters in hex format.
        self.authorized_voters.insert(hex_pubkey);
    }

    /// Blindly signs the hash submitted by a voter.
    pub fn issue_token(
        &mut self,
        req: BlindTokenRequest,
        secret_key: RSASecretKey,
    ) -> Result<BlindSignature, &'static str> {
        let options = Options::default();
        let rng = &mut thread_rng();

        // Convert voter_pk to hex format for comparison
        let hex_pubkey = if req.voter_pk.starts_with("npub") {
            match PublicKey::parse(&req.voter_pk) {
                Ok(pk) => pk.to_hex(),
                Err(_) => return Err("Invalid npub format"),
            }
        } else {
            match PublicKey::from_hex(&req.voter_pk) {
                Ok(pk) => pk.to_hex(),
                Err(_) => return Err("Invalid pubkey format"),
            }
        };

        // Check that the voter is authorized and has not previously requested it.
        if !self.authorized_voters.remove(&hex_pubkey) {
            return Err("Unauthorized voter or nonce hash already issued");
        }
        // 2) Sign it
        let blind_sig = secret_key
            .blind_sign(rng, &req.blinded_h_n, &options)
            .map_err(|_| "signing error")?;
        log::info!("Blind signature issued");
        Ok(blind_sig)
    }

    /// Receives a vote along with (h_n, token) and verifies validity.
    pub fn receive_vote(&mut self, h_n: BigUint, vote: u8) -> Result<(), &'static str> {
        if self.status != Status::InProgress {
            return Err("Cannot receive vote: election is not in progress");
        }
        // Avoid double voting.
        if !self.used_tokens.insert(h_n.clone()) {
            log::warn!("Duplicate token detected for h_n={}", h_n);
            return Err("duplicated vote");
        }
        // Store vote (for demo purposes it will be the candidate's number).
        self.votes.push(vote);
        println!("✅ Vote received");

        Ok(())
    }

    /// Returns a map candidate → number of votes.
    pub fn tally(&self) -> HashMap<Candidate, u32> {
        let mut counts = HashMap::new();
        for &v in &self.votes {
            if let Some(c) = self.candidates.iter().find(|c| c.id == v) {
                *counts.entry(*c).or_insert(0) += 1;
            }
        }
        counts
    }

    pub fn as_json(&self) -> Value {
        let election_data = serde_json::json!({
            "id": self.id.to_string(),
            "name": self.name,
            "start_time": self.start_time,
            "end_time": self.end_time,
            "candidates": self.candidates,
            "status": match self.status {
                Status::Open => "open",
                Status::InProgress => "in-progress",
                Status::Finished => "finished",
                Status::Canceled => "canceled",
            },
            "rsa_pub_key": self.rsa_pub_key,
        });
        election_data
    }

    pub fn as_json_string(&self) -> String {
        let election_data = self.as_json();
        serde_json::to_string(&election_data).unwrap()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::util::load_keys;
    use blind_rsa_signatures::Options;
    use nostr_sdk::ToBech32;
    use num_bigint_dig::{BigUint, RandBigInt};
    use rand::rngs::OsRng;
    use serde_json::Value;
    use sha2::{Digest, Sha256};
    use std::collections::HashMap;

    fn make_election() -> Election {
        // start_time = 1000, duration = 3600
        Election::new(
            "TestElect".to_string(),
            vec![Candidate::new(1, "Alice"), Candidate::new(2, "Bob")],
            1000,
            3600,
            "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAyzrjKKlz8JpyKrqnCNr2n/iXwSgHAnrNyZwOJ6UW4actxDnI3dyweOqXtGZyIg4+PeEmDrTY5sP6pN2p5qVM6XGmt7DCfStJgaCpB0D/BZd/ar/sh9aj9ATLQe24/UDXweGTgzWVsky8uCRODczaxhDPXvwRAQICuZNO3OxQ5ss7uc1ZfSDS++857q8k6KHdbnWkAy3+NoGslZWqIQH/h9tDl8zfKH5AP5MZibdna+/P2wbz86/8uq+hBupxwympiQXxLB7rfjfOkLX22WguseovpbA/7If3LNned5UuxX1IxuFzBtw7W1RAy8B1MqlAobf5K+e4XzAzl49AqQn6swIDAQAB".to_string(),
        )
    }

    #[test]
    fn test_new_election_defaults() {
        let e = make_election();
        assert_eq!(e.name, "TestElect");
        assert_eq!(e.status, Status::Open);
        assert_eq!(e.start_time, 1000);
        assert_eq!(e.end_time, 1000 + 3600);
        assert!(e.authorized_voters.is_empty());
        assert!(e.votes.is_empty());
        assert!(e.used_tokens.is_empty());
        assert_eq!(e.candidates.len(), 2);
        assert_eq!(e.id.len(), 4);
    }

    #[test]
    fn test_register_voter_and_duplicate() {
        let mut e = make_election();
        // Use a valid hex public key
        let hex_pk = "e3f33350728580cd51db8f4048d614910d48a5c0d7f1af6811e83c07fc865a5c";

        // Register with hex format
        e.register_voter(hex_pk);
        assert_eq!(e.authorized_voters.len(), 1);
        assert!(e.authorized_voters.contains(hex_pk));

        // Re-registration with same hex does not duplicate
        e.register_voter(hex_pk);
        assert_eq!(e.authorized_voters.len(), 1);

        // Change status to InProgress and do not allow registration
        e.status = Status::InProgress;
        e.register_voter("another_key");
        assert_eq!(e.authorized_voters.len(), 1);
    }

    #[test]
    fn test_register_voter_npub_conversion() {
        let mut e = make_election();
        // Use the valid hex key from main.rs comments
        let hex_pk = "e3f33350728580cd51db8f4048d614910d48a5c0d7f1af6811e83c07fc865a5c";
        // Convert to npub format for testing
        let pk = PublicKey::from_hex(hex_pk).unwrap();
        let npub_pk = pk.to_bech32().unwrap();

        // Register with npub format
        e.register_voter(&npub_pk);
        assert_eq!(e.authorized_voters.len(), 1);
        // Should be stored in hex format
        assert!(e.authorized_voters.contains(hex_pk));
        assert!(!e.authorized_voters.contains(&npub_pk));

        // Re-registration with hex format of same key does not duplicate
        e.register_voter(hex_pk);
        assert_eq!(e.authorized_voters.len(), 1);
    }

    #[test]
    fn test_receive_vote_errors_and_success() {
        let mut e = make_election();
        let h1 = BigUint::from(42u8);

        // Status Open → error
        assert_eq!(
            e.receive_vote(h1.clone(), 1).unwrap_err(),
            "Cannot receive vote: election is not in progress"
        );

        // change to InProgress
        e.status = Status::InProgress;

        // First valid vote
        assert!(e.receive_vote(h1.clone(), 2).is_ok());
        assert_eq!(e.votes, vec![2]);

        // Duplicated vote → error
        assert_eq!(
            e.receive_vote(h1.clone(), 2).unwrap_err(),
            "duplicated vote"
        );
    }

    #[test]
    fn test_tally_counts() {
        let mut e = make_election();
        e.status = Status::InProgress;
        // Valid votes to Alice(id=1) and Bob(id=2)
        let _ = e.receive_vote(BigUint::from(1u8), 1);
        let _ = e.receive_vote(BigUint::from(2u8), 2);
        let _ = e.receive_vote(BigUint::from(3u8), 1);

        let counts = e.tally();
        let mut expected = HashMap::new();
        expected.insert(Candidate::new(1, "Alice"), 2);
        expected.insert(Candidate::new(2, "Bob"), 1);
        assert_eq!(counts, expected);
    }

    #[test]
    fn test_as_json_string_and_value() {
        let mut e = make_election();
        e.status = Status::Finished;
        let s = e.as_json_string();
        let v: Value = serde_json::from_str(&s).unwrap();
        assert_eq!(v["name"], "TestElect");
        assert_eq!(v["status"], "finished");
        assert_eq!(v["start_time"], 1000);
        assert_eq!(v["end_time"], 4600);
        // candidates
        let cands = v["candidates"].as_array().unwrap();
        assert_eq!(cands.len(), 2);
        assert_eq!(cands[0]["id"], 1);
        assert_eq!(cands[1]["name"], "Bob");
    }

    #[test]
    fn test_blind_signature_flow() {
        // Load RSA keys
        let (pk, sk) =
            load_keys("ec_private.pem", "ec_public.pem").expect("The keys could not be loaded");

        // Simulates the voter: generates a random 128-bit nonce and its SHA256 hash
        let rng = &mut rand::thread_rng();
        // Generate nonce and its hash
        let nonce: BigUint = OsRng.gen_biguint(128);
        // Hash the nonce
        let h_n_bytes = Sha256::digest(nonce.to_bytes_be()).to_vec();

        // Voter blind the hash
        let options = Options::default();
        let blinding_result = pk
            .blind(rng, &h_n_bytes, true, &options)
            .expect("Error blinding message");

        // The server (EC) issues the blind signature
        let blind_sig = sk
            .blind_sign(rng, &blinding_result.blind_msg, &options)
            .expect("Blind signing error");

        // The voter "unblinds"
        let token = pk
            .finalize(
                &blind_sig,
                &blinding_result.secret,
                blinding_result.msg_randomizer,
                &h_n_bytes,
                &options,
            )
            .expect("Error getting the token");
        // Voter verify against the original hash.
        assert!(
            token
                .verify(&pk, blinding_result.msg_randomizer, &h_n_bytes, &options)
                .is_ok(),
            "The token is not valid"
        );
    }
}
