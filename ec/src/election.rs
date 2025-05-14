/*! election.rs — Electoral Commission logic
Manages voter registration, issuance of blind tokens, vote reception, and counting. */

use blind_rsa_signatures::{BlindSignature, BlindedMessage, Options, SecretKey as RSASecretKey};
use nanoid::nanoid;
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
}

impl Election {
    /// Create a new EC with a 2048-bit RSA key.
    pub fn new(name: String, candidates: Vec<Candidate>, start_time: u64, duration: u64) -> Self {
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
        }
    }

    pub fn register_voter(&mut self, voter_pk: &str) {
        if self.status != Status::Open {
            log::warn!("Cannot register voter: election is not open");
            return;
        }
        println!("🔑 Registering voter: {}", voter_pk);
        // 1) Check that the pubkey is not already registered.
        if self.authorized_voters.contains(voter_pk) {
            println!("⚠️ Voter already registered");
            return;
        }
        // 2) Add to the list of authorized voters.
        self.authorized_voters.insert(voter_pk.to_string());
    }

    /// Blindly signs the hash submitted by a voter.
    pub fn issue_token(
        &mut self,
        req: BlindTokenRequest,
        secret_key: RSASecretKey,
    ) -> Result<BlindSignature, &'static str> {
        let options = Options::default();
        let rng = &mut thread_rng();
        // Check that the voter is authorized and has not previously requested it.
        if !self.authorized_voters.remove(&req.voter_pk) {
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
    use num_bigint_dig::{BigUint, RandBigInt};
    use serde_json::Value;
    use crate::util::load_keys;
    use blind_rsa_signatures::{Options};
    use rand::rngs::OsRng;
    use sha2::{Digest, Sha256};
    use std::collections::HashMap;

    fn make_election() -> Election {
        // start_time = 1000, duration = 3600
        Election::new(
            "TestElect".to_string(),
            vec![Candidate::new(1, "Alice"), Candidate::new(2, "Bob")],
            1000,
            3600,
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
        let pk = "npub_test";
        e.register_voter(pk);
        assert!(e.authorized_voters.contains(pk));

        // Re-registration does not duplicate
        e.register_voter(pk);
        assert_eq!(e.authorized_voters.len(), 1);

        // Change status to InProgress and do not allow registration
        e.status = Status::InProgress;
        e.register_voter("otra");
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
        let token = pk.finalize(
            &blind_sig,
            &blinding_result.secret,
            blinding_result.msg_randomizer,
            &h_n_bytes,
            &options,
        ).expect("Error getting the token");
        // Voter verify against the original hash.
        assert!(
            token.verify(&pk, blinding_result.msg_randomizer, &h_n_bytes, &options).is_ok(),
            "The token is not valid"
        );
    }
}
