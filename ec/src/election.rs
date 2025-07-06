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
use crate::database::{ElectionRecord, CandidateRecord};

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

    /// Restore an election from database records
    pub fn from_database(
        election_record: ElectionRecord,
        candidate_records: Vec<CandidateRecord>,
        authorized_voters: Vec<String>,
        used_tokens: Vec<String>,
    ) -> Self {
        let status = match election_record.status.as_str() {
            "open" => Status::Open,
            "in-progress" => Status::InProgress,
            "finished" => Status::Finished,
            "canceled" => Status::Canceled,
            _ => Status::Open,
        };

        let candidates = candidate_records
            .into_iter()
            .map(|c| Candidate::new(c.candidate_id as u8, c.name))
            .collect();

        let authorized_voters_set: HashSet<String> = authorized_voters.into_iter().collect();

        let used_tokens_set: HashSet<BigUint> = used_tokens
            .into_iter()
            .filter_map(|token| {
                match BigUint::parse_bytes(token.as_bytes(), 16) {
                    Some(big_uint) => Some(big_uint),
                    None => {
                        log::warn!("Failed to parse used token: {}", token);
                        None
                    }
                }
            })
            .collect();

        Self {
            id: election_record.id,
            name: election_record.name,
            authorized_voters: authorized_voters_set,
            used_tokens: used_tokens_set,
            votes: vec![], // We'll reconstruct votes from candidate vote counts if needed
            candidates,
            start_time: election_record.start_time as u64,
            end_time: election_record.end_time as u64,
            status,
            rsa_pub_key: election_record.rsa_pub_key,
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

    /// Save used token to database (to be called after receive_vote)
    pub async fn save_used_token_to_db(&self, db: &crate::database::Database, h_n: &BigUint) -> Result<(), anyhow::Error> {
        let token_hash = format!("{:x}", h_n);
        db.save_used_token(&self.id, &token_hash).await?;
        Ok(())
    }

    /// Save authorized voters to database  
    pub async fn save_authorized_voters_to_db(&self, db: &crate::database::Database) -> Result<(), anyhow::Error> {
        let voters: Vec<String> = self.authorized_voters.iter().cloned().collect();
        db.save_election_voters(&self.id, &voters).await?;
        Ok(())
    }

    /// Check if election should be in progress based on current time
    pub fn should_be_in_progress(&self, current_time: u64) -> bool {
        current_time >= self.start_time && current_time < self.end_time && self.status == Status::Open
    }

    /// Check if election should be finished based on current time
    pub fn should_be_finished(&self, current_time: u64) -> bool {
        current_time >= self.end_time && (self.status == Status::Open || self.status == Status::InProgress)
    }

    /// Update election status based on current time
    /// Returns true if status was changed, false if no change needed
    pub fn update_status_based_on_time(&mut self, current_time: u64) -> bool {
        let old_status = self.status;
        
        if self.should_be_finished(current_time) {
            self.status = Status::Finished;
        } else if self.should_be_in_progress(current_time) {
            self.status = Status::InProgress;
        }
        
        old_status != self.status
    }

    /// Returns a map candidate → number of votes.
    pub fn tally(&self) -> HashMap<Candidate, u32> {
        let mut counts = HashMap::new();
        for &v in &self.votes {
            if let Some(c) = self.candidates.iter().find(|c| c.id == v) {
                *counts.entry(c.clone()).or_insert(0) += 1;
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

    #[test]
    fn test_complete_voting_flow_without_nostr() {
        // Setup: Load RSA keys and create election
        let (pk, sk) =
            load_keys("ec_private.pem", "ec_public.pem").expect("Failed to load RSA keys");

        let mut election = Election::new(
            "Complete Flow Test".to_string(),
            vec![
                Candidate::new(1, "Alice"),
                Candidate::new(2, "Bob"),
                Candidate::new(3, "Charlie"),
            ],
            1000, // start_time
            3600, // duration
            "test_rsa_key".to_string(),
        );

        // Register voters first (while status is Open)
        let voter1_pk = "e3f33350728580cd51db8f4048d614910d48a5c0d7f1af6811e83c07fc865a5c";
        let voter2_pk = "a1b2c3d4e5f67890123456789012345678901234567890123456789012345678";
        let voter3_pk = "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef";

        election.register_voter(voter1_pk);
        election.register_voter(voter2_pk);
        election.register_voter(voter3_pk);

        assert_eq!(election.authorized_voters.len(), 3);

        // Change status to InProgress to allow voting
        election.status = Status::InProgress;

        // === VOTER 1 FLOW ===
        println!("=== Testing Voter 1 Flow ===");

        // 1. Voter generates nonce and blinds it
        let rng = &mut rand::thread_rng();
        let options = Options::default();

        // Generate 128-bit nonce
        let voter1_nonce: BigUint = OsRng.gen_biguint(128);
        let voter1_h_n_bytes = Sha256::digest(voter1_nonce.to_bytes_be()).to_vec();
        let voter1_h_n = BigUint::from_bytes_be(&voter1_h_n_bytes);

        // Blind the hash
        let voter1_blinding_result = pk
            .blind(rng, &voter1_h_n_bytes, true, &options)
            .expect("Failed to blind message for voter 1");

        // 2. Create token request (simulating what happens in main.rs)
        let voter1_request = BlindTokenRequest {
            voter_pk: voter1_pk.to_string(),
            blinded_h_n: voter1_blinding_result.blind_msg.clone(),
        };

        // 3. EC issues blind signature
        let voter1_blind_sig = election
            .issue_token(voter1_request, sk.clone())
            .expect("Failed to issue token to voter 1");

        // Verify voter was removed from authorized list
        assert_eq!(election.authorized_voters.len(), 2);

        // 4. Voter unblinds the signature to get token
        let voter1_token = pk
            .finalize(
                &voter1_blind_sig,
                &voter1_blinding_result.secret,
                voter1_blinding_result.msg_randomizer,
                &voter1_h_n_bytes,
                &options,
            )
            .expect("Failed to unblind signature for voter 1");

        // 5. Verify token is valid
        assert!(
            voter1_token
                .verify(
                    &pk,
                    voter1_blinding_result.msg_randomizer,
                    &voter1_h_n_bytes,
                    &options
                )
                .is_ok(),
            "Voter 1 token verification failed"
        );

        // 6. Cast vote for candidate 2 (Bob)
        let voter1_candidate_id = 2u8;
        let voter1_vote_result = election.receive_vote(voter1_h_n, voter1_candidate_id);
        assert!(
            voter1_vote_result.is_ok(),
            "Failed to receive vote from voter 1"
        );

        // === VOTER 2 FLOW ===
        println!("=== Testing Voter 2 Flow ===");

        let voter2_nonce: BigUint = OsRng.gen_biguint(128);
        let voter2_h_n_bytes = Sha256::digest(voter2_nonce.to_bytes_be()).to_vec();
        let voter2_h_n = BigUint::from_bytes_be(&voter2_h_n_bytes);

        let voter2_blinding_result = pk
            .blind(rng, &voter2_h_n_bytes, true, &options)
            .expect("Failed to blind message for voter 2");

        let voter2_request = BlindTokenRequest {
            voter_pk: voter2_pk.to_string(),
            blinded_h_n: voter2_blinding_result.blind_msg.clone(),
        };

        let voter2_blind_sig = election
            .issue_token(voter2_request, sk.clone())
            .expect("Failed to issue token to voter 2");

        let voter2_token = pk
            .finalize(
                &voter2_blind_sig,
                &voter2_blinding_result.secret,
                voter2_blinding_result.msg_randomizer,
                &voter2_h_n_bytes,
                &options,
            )
            .expect("Failed to unblind signature for voter 2");

        assert!(
            voter2_token
                .verify(
                    &pk,
                    voter2_blinding_result.msg_randomizer,
                    &voter2_h_n_bytes,
                    &options
                )
                .is_ok(),
            "Voter 2 token verification failed"
        );

        // Cast vote for candidate 1 (Alice)
        let voter2_candidate_id = 1u8;
        let voter2_vote_result = election.receive_vote(voter2_h_n, voter2_candidate_id);
        assert!(
            voter2_vote_result.is_ok(),
            "Failed to receive vote from voter 2"
        );

        // === VOTER 3 FLOW ===
        println!("=== Testing Voter 3 Flow ===");

        let voter3_nonce: BigUint = OsRng.gen_biguint(128);
        let voter3_h_n_bytes = Sha256::digest(voter3_nonce.to_bytes_be()).to_vec();
        let voter3_h_n = BigUint::from_bytes_be(&voter3_h_n_bytes);

        let voter3_blinding_result = pk
            .blind(rng, &voter3_h_n_bytes, true, &options)
            .expect("Failed to blind message for voter 3");

        let voter3_request = BlindTokenRequest {
            voter_pk: voter3_pk.to_string(),
            blinded_h_n: voter3_blinding_result.blind_msg.clone(),
        };

        let voter3_blind_sig = election
            .issue_token(voter3_request, sk.clone())
            .expect("Failed to issue token to voter 3");

        let voter3_token = pk
            .finalize(
                &voter3_blind_sig,
                &voter3_blinding_result.secret,
                voter3_blinding_result.msg_randomizer,
                &voter3_h_n_bytes,
                &options,
            )
            .expect("Failed to unblind signature for voter 3");

        assert!(
            voter3_token
                .verify(
                    &pk,
                    voter3_blinding_result.msg_randomizer,
                    &voter3_h_n_bytes,
                    &options
                )
                .is_ok(),
            "Voter 3 token verification failed"
        );

        // Cast vote for candidate 2 (Bob)
        let voter3_candidate_id = 2u8;
        let voter3_vote_result = election.receive_vote(voter3_h_n, voter3_candidate_id);
        assert!(
            voter3_vote_result.is_ok(),
            "Failed to receive vote from voter 3"
        );

        // === VERIFY RESULTS ===
        println!("=== Verifying Election Results ===");

        // All voters should be removed from authorized list
        assert_eq!(election.authorized_voters.len(), 0);

        // Check vote tallies
        let tally = election.tally();
        println!("Final tally: {:?}", tally);

        // Alice (id=1) should have 1 vote (from voter2)
        let alice_votes = tally.get(&Candidate::new(1, "Alice")).unwrap_or(&0);
        assert_eq!(*alice_votes, 1, "Alice should have 1 vote");

        // Bob (id=2) should have 2 votes (from voter1 and voter3)
        let bob_votes = tally.get(&Candidate::new(2, "Bob")).unwrap_or(&0);
        assert_eq!(*bob_votes, 2, "Bob should have 2 votes");

        // Charlie (id=3) should have 0 votes
        let charlie_votes = tally.get(&Candidate::new(3, "Charlie")).unwrap_or(&0);
        assert_eq!(*charlie_votes, 0, "Charlie should have 0 votes");

        // Verify total votes
        assert_eq!(
            election.votes.len(),
            3,
            "Should have received 3 votes total"
        );

        println!("✅ Complete voting flow test passed!");
    }

    #[test]
    fn test_voting_flow_error_cases() {
        let (pk, sk) =
            load_keys("ec_private.pem", "ec_public.pem").expect("Failed to load RSA keys");

        let mut election = Election::new(
            "Error Cases Test".to_string(),
            vec![Candidate::new(1, "Alice"), Candidate::new(2, "Bob")],
            1000,
            3600,
            "test_rsa_key".to_string(),
        );

        let voter_pk = "e3f33350728580cd51db8f4048d614910d48a5c0d7f1af6811e83c07fc865a5c";
        election.register_voter(voter_pk);

        election.status = Status::InProgress;

        let rng = &mut rand::thread_rng();
        let options = Options::default();

        // === Test 1: Unauthorized voter trying to get token ===
        let unauthorized_pk = "1111111111111111111111111111111111111111111111111111111111111111";
        let nonce1: BigUint = OsRng.gen_biguint(128);
        let h_n_bytes1 = Sha256::digest(nonce1.to_bytes_be()).to_vec();

        let blinding_result1 = pk
            .blind(rng, &h_n_bytes1, true, &options)
            .expect("Failed to blind message");

        let unauthorized_request = BlindTokenRequest {
            voter_pk: unauthorized_pk.to_string(),
            blinded_h_n: blinding_result1.blind_msg.clone(),
        };

        let unauthorized_result = election.issue_token(unauthorized_request, sk.clone());
        assert!(
            unauthorized_result.is_err(),
            "Unauthorized voter should not receive token"
        );
        assert_eq!(
            unauthorized_result.unwrap_err(),
            "Unauthorized voter or nonce hash already issued"
        );

        // === Test 2: Successful token issuance ===
        let nonce2: BigUint = OsRng.gen_biguint(128);
        let h_n_bytes2 = Sha256::digest(nonce2.to_bytes_be()).to_vec();
        let h_n2 = BigUint::from_bytes_be(&h_n_bytes2);

        let blinding_result2 = pk
            .blind(rng, &h_n_bytes2, true, &options)
            .expect("Failed to blind message");

        let valid_request = BlindTokenRequest {
            voter_pk: voter_pk.to_string(),
            blinded_h_n: blinding_result2.blind_msg.clone(),
        };

        let blind_sig = election
            .issue_token(valid_request, sk.clone())
            .expect("Valid voter should receive token");

        let _token = pk
            .finalize(
                &blind_sig,
                &blinding_result2.secret,
                blinding_result2.msg_randomizer,
                &h_n_bytes2,
                &options,
            )
            .expect("Failed to unblind signature");

        // === Test 3: Double voting with same token ===
        let vote_result1 = election.receive_vote(h_n2.clone(), 1);
        assert!(vote_result1.is_ok(), "First vote should succeed");

        let vote_result2 = election.receive_vote(h_n2.clone(), 2);
        assert!(vote_result2.is_err(), "Double voting should be rejected");
        assert_eq!(vote_result2.unwrap_err(), "duplicated vote");

        // === Test 4: Trying to request token again from same voter ===
        let nonce3: BigUint = OsRng.gen_biguint(128);
        let h_n_bytes3 = Sha256::digest(nonce3.to_bytes_be()).to_vec();

        let blinding_result3 = pk
            .blind(rng, &h_n_bytes3, true, &options)
            .expect("Failed to blind message");

        let repeat_request = BlindTokenRequest {
            voter_pk: voter_pk.to_string(),
            blinded_h_n: blinding_result3.blind_msg.clone(),
        };

        let repeat_result = election.issue_token(repeat_request, sk.clone());
        assert!(repeat_result.is_err(), "Voter should not get second token");

        println!("✅ Error cases test passed!");
    }
}
