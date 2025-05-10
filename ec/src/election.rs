/*!  counting.rs — Electoral Commission logic
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
