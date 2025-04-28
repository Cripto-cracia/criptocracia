/*!  counting.rs — Electoral Commission logic
     Manages voter registration, issuance of blind tokens, vote reception, and counting. */

     use rand::rngs::OsRng;
     use rsa::{traits::{PrivateKeyParts, PublicKeyParts}, BigUint, RsaPrivateKey, RsaPublicKey};
     use std::collections::{HashMap, HashSet};
     
     use crate::Candidate;
     
     /// Blind signature petition made by a voter.
     pub struct BlindTokenRequest {
         pub voter_pk: String,
         pub blinded_hash: BigUint,
     }

     pub enum Status {
         /// Election is open for voting.
         Open,
         /// Election is closed for voting.
         Closed,
     }
     
     /// Commissioner of Elections (CE) manages the election process.
     pub struct Election {
        pub id: uuid::Uuid,
        pub priv_rsa: RsaPrivateKey,
        pub pub_rsa: RsaPublicKey,
        pub authorized_voters: HashSet<String>, // allowed pubkeys
        pub used_tokens: HashSet<BigUint>,       // h_n already used
        pub votes: Vec<u8>,                     // votes received
        pub candidates: Vec<Candidate>,
        pub start_time: u64,
        pub end_time: u64,
        pub status: Status,
     }
     
     impl Election {
         /// Create a new EC with a 2048-bit RSA key.
         pub fn new(candidates: Vec<Candidate>, start_time: u64, duration: u64) -> Self {
             let mut rng = OsRng;
             let priv_rsa = RsaPrivateKey::new(&mut rng, 2048).expect("Failed to generate RSA key");
             let pub_rsa = RsaPublicKey::from(&priv_rsa);
             let end_time = start_time + duration;
             let id = uuid::Uuid::new_v4();
             Self {
                id,
                priv_rsa,
                pub_rsa,
                authorized_voters: HashSet::new(),
                used_tokens: HashSet::new(),
                votes: vec![],
                candidates,
                start_time,
                end_time,
                status: Status::Open,
             }
         }
     
         /// Returns the EC's RSA public key.
         pub fn public_rsa(&self) -> &RsaPublicKey {
             &self.pub_rsa
         }
     
         /// Registers the pubkey nostr of an authorized voter.
         pub fn register_voter(&mut self, voter_pk: &str) {
            println!("🔑 Registering voter: {voter_pk}");
             // 1) Check that the pubkey is not already registered.
             if self.authorized_voters.contains(voter_pk) {
                 println!("⚠️ Voter already registered");
                 return;
             }
             // 2) Add to the list of authorized voters.
            self.authorized_voters.insert(voter_pk.to_string());
         }
     
         /// Blindly signs the hash submitted by a voter.
         pub fn issue_token(&mut self, req: BlindTokenRequest) -> Result<BigUint, &'static str> {
             // 1) Check that the voter is authorized and has not previously requested it.
             if !self.authorized_voters.remove(&req.voter_pk) {
                 return Err("unauthorized voter or signature already issued");
             }
             // 2) Sign: s' = blinded^d  (mód n)
             let blind_sig = req
                 .blinded_hash
                 .modpow(self.priv_rsa.d(), self.priv_rsa.n());
             Ok(blind_sig)
         }
     
         /// Receives a vote along with (h_n, token) and verifies validity.
         pub fn receive_vote(
             &mut self,
             voter_name: String,
             h_n: BigUint,
             token: BigUint,
             encrypted_vote: u8,
         ) -> Result<(), &'static str> {
             // 1) Validates signature: token^e ≟ h_n  (mód n)
             if token.modpow(self.pub_rsa.e(), self.pub_rsa.n()) != h_n {
                 return Err("Invalid token");
             }
             // 2) Avoid double voting.
             if !self.used_tokens.insert(h_n) {
                 return Err("duplicated vote");
             }
             // 3) Store encrypted vote (for demo purposes it will be the candidate's number).
             self.votes.push(encrypted_vote);
             println!("✅ Vote received from {voter_name}");
             Ok(())
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
     
         /// Print the final results to the console.
         pub fn print_results(&self) {
             println!("\n──────── Final results ────────");
             let tally = self.tally();
             for (cand, count) in &tally {
                 println!("{}: {} voto(s)", cand.name, count);
             }
             if let Some((winner, _)) = tally.iter().max_by_key(|(_, c)| *c) {
                 println!("🏆 Ganador: {}", winner.name);
             }
         }

         pub fn as_json(&self) -> String {
            let election_data = serde_json::json!({
                "id": self.id.to_string(),
                "start_time": self.start_time,
                "end_time": self.end_time,
                "candidates": self.candidates,
                "status": match self.status {
                    Status::Open => "open",
                    Status::Closed => "closed",
                },
            });
            election_data.to_string()
         }
     }
     