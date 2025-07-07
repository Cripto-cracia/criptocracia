use anyhow::Result;
use nostr_sdk::{Client, Keys, PublicKey};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::Mutex;
use tonic::{Request, Response, Status};

use crate::database::Database;
use crate::election::{Election, Status as ElectionStatus};
use crate::grpc::admin_proto::admin_service_server::AdminService;
use crate::grpc::admin_proto::*;
use crate::types::Candidate;

/// Implementation of the AdminService gRPC service
pub struct AdminServiceImpl {
    db: Arc<Database>,
    elections: Arc<Mutex<HashMap<String, Election>>>,
    rsa_public_key: String, // DER-encoded base64 RSA public key
    client: Arc<Client>,    // Nostr client for publishing events
    keys: Arc<Keys>,        // Nostr keys for signing events
}

impl AdminServiceImpl {
    /// Create a new AdminServiceImpl instance
    pub fn new(
        db: Arc<Database>,
        elections: Arc<Mutex<HashMap<String, Election>>>,
        rsa_public_key: String,
        client: Arc<Client>,
        keys: Arc<Keys>,
    ) -> Self {
        Self {
            db,
            elections,
            rsa_public_key,
            client,
            keys,
        }
    }

    #[cfg(test)]
    pub fn get_db(&self) -> &Arc<Database> {
        &self.db
    }

    #[cfg(test)]
    pub fn get_elections(&self) -> &Arc<Mutex<HashMap<String, Election>>> {
        &self.elections
    }

    /// Convert ElectionStatus to string
    fn election_status_to_string(status: ElectionStatus) -> String {
        match status {
            ElectionStatus::Open => "Open".to_string(),
            ElectionStatus::InProgress => "InProgress".to_string(),
            ElectionStatus::Finished => "Finished".to_string(),
            ElectionStatus::Canceled => "Canceled".to_string(),
        }
    }

    /// Convert Election to ElectionInfo
    fn election_to_info(election: &Election) -> ElectionInfo {
        let candidates: Vec<CandidateInfo> = election
            .candidates
            .iter()
            .map(|c| {
                let vote_count = election.votes.iter().filter(|&&v| v == c.id).count() as u32;
                CandidateInfo {
                    id: c.id as u32,
                    name: c.name.to_string(),
                    vote_count,
                }
            })
            .collect();

        ElectionInfo {
            id: election.id.clone(),
            name: election.name.clone(),
            start_time: election.start_time,
            end_time: election.end_time,
            status: Self::election_status_to_string(election.status),
            candidates,
            rsa_public_key: election.rsa_pub_key.clone(),
            created_at: 0, // TODO: Add created_at to Election struct
            updated_at: 0, // TODO: Add updated_at to Election struct
            total_votes: election.votes.len() as u32,
        }
    }

    /// Validate voter public key format
    fn validate_voter_pubkey(pubkey: &str) -> Result<(), Box<Status>> {
        if pubkey.is_empty() {
            return Err(Box::new(Status::invalid_argument(
                "Voter public key cannot be empty",
            )));
        }

        // Use Nostr SDK to validate the format (same as election.rs does)
        if pubkey.starts_with("npub") {
            if PublicKey::parse(pubkey).is_err() {
                return Err(Box::new(Status::invalid_argument("Invalid npub format")));
            }
        } else if PublicKey::from_hex(pubkey).is_err() {
            return Err(Box::new(Status::invalid_argument(
                "Invalid hex pubkey format",
            )));
        }

        Ok(())
    }

    /// Validate election name
    fn validate_election_name(name: &str) -> Result<(), Box<Status>> {
        if name.is_empty() {
            return Err(Box::new(Status::invalid_argument(
                "Election name cannot be empty",
            )));
        }

        if name.len() > 100 {
            return Err(Box::new(Status::invalid_argument(
                "Election name is too long (max 100 characters)",
            )));
        }

        Ok(())
    }

    /// Validate candidate data
    fn validate_candidate(candidate_id: u32, name: &str) -> Result<(), Box<Status>> {
        if candidate_id == 0 {
            return Err(Box::new(Status::invalid_argument(
                "Candidate ID must be greater than 0",
            )));
        }

        if candidate_id > 255 {
            return Err(Box::new(Status::invalid_argument(
                "Candidate ID must be less than 256",
            )));
        }

        if name.is_empty() {
            return Err(Box::new(Status::invalid_argument(
                "Candidate name cannot be empty",
            )));
        }

        if name.len() > 50 {
            return Err(Box::new(Status::invalid_argument(
                "Candidate name is too long (max 50 characters)",
            )));
        }

        Ok(())
    }

    /// Publish election to Nostr using the existing publish_election_event function
    async fn publish_election_to_nostr(&self, election: &Election) -> Result<(), anyhow::Error> {
        crate::publish_election_event(&self.client, &self.keys, election, &self.db).await
    }
}

#[tonic::async_trait]
impl AdminService for AdminServiceImpl {
    async fn add_voter(
        &self,
        request: Request<AddVoterRequest>,
    ) -> Result<Response<AddVoterResponse>, Status> {
        let req = request.into_inner();

        log::info!(
            "Adding voter: {} with pubkey: {} to election: {}",
            req.name,
            req.pubkey,
            req.election_id
        );

        // Validate input
        if req.name.is_empty() {
            return Ok(Response::new(AddVoterResponse {
                success: false,
                message: "Voter name cannot be empty".to_string(),
                voter_id: String::new(),
            }));
        }

        if req.election_id.is_empty() {
            return Ok(Response::new(AddVoterResponse {
                success: false,
                message: "Election ID cannot be empty".to_string(),
                voter_id: String::new(),
            }));
        }

        if let Err(e) = Self::validate_voter_pubkey(&req.pubkey) {
            return Ok(Response::new(AddVoterResponse {
                success: false,
                message: format!("Invalid voter public key: {}", e.message()),
                voter_id: String::new(),
            }));
        }

        // Check if election exists
        {
            let elections_guard = self.elections.lock().await;
            if !elections_guard.contains_key(&req.election_id) {
                return Ok(Response::new(AddVoterResponse {
                    success: false,
                    message: "Election not found".to_string(),
                    voter_id: String::new(),
                }));
            }
        }

        // Add voter to election_voters table
        match self
            .db
            .save_election_voters(&req.election_id, &[req.pubkey.clone()])
            .await
        {
            Ok(()) => {
                // Also add voter to in-memory election's authorized_voters HashSet
                {
                    let mut elections_guard = self.elections.lock().await;
                    if let Some(election) = elections_guard.get_mut(&req.election_id) {
                        election.register_voter(&req.pubkey);
                        log::info!(
                            "Added voter {} to in-memory election {}",
                            req.pubkey,
                            req.election_id
                        );
                    } else {
                        log::error!(
                            "Election {} not found in memory after database save",
                            req.election_id
                        );
                    }
                }

                log::info!(
                    "Successfully added voter: {} to election: {}",
                    req.name,
                    req.election_id
                );
                Ok(Response::new(AddVoterResponse {
                    success: true,
                    message: "Voter added to election successfully".to_string(),
                    voter_id: req.pubkey,
                }))
            }
            Err(e) => {
                log::error!("Failed to add voter to election: {}", e);
                Ok(Response::new(AddVoterResponse {
                    success: false,
                    message: format!("Failed to add voter to election: {}", e),
                    voter_id: String::new(),
                }))
            }
        }
    }

    async fn add_election(
        &self,
        request: Request<AddElectionRequest>,
    ) -> Result<Response<AddElectionResponse>, Status> {
        let req = request.into_inner();

        log::info!("Adding election: {}", req.name);

        // Validate input
        if let Err(e) = Self::validate_election_name(&req.name) {
            return Ok(Response::new(AddElectionResponse {
                success: false,
                message: format!("Invalid election name: {}", e.message()),
                election_id: String::new(),
            }));
        }

        if req.start_time == 0 {
            return Ok(Response::new(AddElectionResponse {
                success: false,
                message: "Election start time cannot be zero".to_string(),
                election_id: String::new(),
            }));
        }

        if req.duration == 0 {
            return Ok(Response::new(AddElectionResponse {
                success: false,
                message: "Election duration cannot be zero".to_string(),
                election_id: String::new(),
            }));
        }

        if req.candidates.is_empty() {
            return Ok(Response::new(AddElectionResponse {
                success: false,
                message: "Election must have at least one candidate".to_string(),
                election_id: String::new(),
            }));
        }

        // Validate candidates
        for candidate in &req.candidates {
            if let Err(e) = Self::validate_candidate(candidate.id, &candidate.name) {
                return Ok(Response::new(AddElectionResponse {
                    success: false,
                    message: format!("Invalid candidate: {}", e.message()),
                    election_id: String::new(),
                }));
            }
        }

        // Convert candidates
        let candidates: Vec<Candidate> = req
            .candidates
            .iter()
            .map(|c| Candidate::new(c.id as u8, &c.name))
            .collect();

        let election_name = req.name.clone();

        // Create election using EC's RSA public key
        let election = Election::new(
            req.name,
            candidates,
            req.start_time,
            req.duration,
            self.rsa_public_key.clone(),
        );

        let election_id = election.id.clone();

        // Add election to HashMap
        {
            let mut elections_guard = self.elections.lock().await;
            elections_guard.insert(election_id.clone(), election.clone());
        }

        // Add to database
        match self.db.upsert_election(&election).await {
            Ok(()) => {
                log::info!("Successfully added election: {}", election_name);

                // Publish election to Nostr
                if let Err(e) = self.publish_election_to_nostr(&election).await {
                    log::error!("Failed to publish election to Nostr: {}", e);
                    // Don't fail the entire operation if Nostr publishing fails
                }

                Ok(Response::new(AddElectionResponse {
                    success: true,
                    message: "Election added successfully".to_string(),
                    election_id,
                }))
            }
            Err(e) => {
                log::error!("Failed to add election: {}", e);
                Ok(Response::new(AddElectionResponse {
                    success: false,
                    message: format!("Failed to add election: {}", e),
                    election_id: String::new(),
                }))
            }
        }
    }

    async fn add_candidate(
        &self,
        request: Request<AddCandidateRequest>,
    ) -> Result<Response<AddCandidateResponse>, Status> {
        let req = request.into_inner();

        log::info!(
            "Adding candidate: {} to election: {}",
            req.name,
            req.election_id
        );

        // Validate input
        if let Err(e) = Self::validate_candidate(req.candidate_id, &req.name) {
            return Ok(Response::new(AddCandidateResponse {
                success: false,
                message: format!("Invalid candidate: {}", e.message()),
            }));
        }

        // Check if election exists and add candidate
        let election_clone = {
            let mut elections_guard = self.elections.lock().await;

            let election = match elections_guard.get_mut(&req.election_id) {
                Some(e) => e,
                None => {
                    return Ok(Response::new(AddCandidateResponse {
                        success: false,
                        message: "Election not found".to_string(),
                    }));
                }
            };

            // Check if candidate ID already exists
            if election
                .candidates
                .iter()
                .any(|c| c.id == req.candidate_id as u8)
            {
                return Ok(Response::new(AddCandidateResponse {
                    success: false,
                    message: "Candidate ID already exists".to_string(),
                }));
            }

            // Add candidate
            let candidate = Candidate::new(req.candidate_id as u8, &req.name);
            election.candidates.push(candidate);

            election.clone()
        };

        match self.db.upsert_election(&election_clone).await {
            Ok(()) => {
                log::info!("Successfully added candidate: {}", req.name);
                Ok(Response::new(AddCandidateResponse {
                    success: true,
                    message: "Candidate added successfully".to_string(),
                }))
            }
            Err(e) => {
                log::error!("Failed to add candidate: {}", e);
                Ok(Response::new(AddCandidateResponse {
                    success: false,
                    message: format!("Failed to add candidate: {}", e),
                }))
            }
        }
    }

    async fn get_election(
        &self,
        request: Request<GetElectionRequest>,
    ) -> Result<Response<GetElectionResponse>, Status> {
        let req = request.into_inner();

        log::info!("Getting election: {}", req.election_id);

        let elections_guard = self.elections.lock().await;

        let election = match elections_guard.get(&req.election_id) {
            Some(e) => e,
            None => {
                return Ok(Response::new(GetElectionResponse {
                    success: false,
                    message: "Election not found".to_string(),
                    election: Some(ElectionInfo::default()),
                }));
            }
        };

        let election_info = Self::election_to_info(election);

        Ok(Response::new(GetElectionResponse {
            success: true,
            message: "Election retrieved successfully".to_string(),
            election: Some(election_info),
        }))
    }

    async fn list_voters(
        &self,
        request: Request<ListVotersRequest>,
    ) -> Result<Response<ListVotersResponse>, Status> {
        let req = request.into_inner();

        log::info!(
            "Listing voters for election: {} with limit: {}, offset: {}",
            req.election_id,
            req.limit,
            req.offset
        );

        // Validate election_id
        if req.election_id.is_empty() {
            return Ok(Response::new(ListVotersResponse {
                success: false,
                message: "Election ID cannot be empty".to_string(),
                voters: vec![],
                total_count: 0,
            }));
        }

        // Check if election exists
        {
            let elections_guard = self.elections.lock().await;
            if !elections_guard.contains_key(&req.election_id) {
                return Ok(Response::new(ListVotersResponse {
                    success: false,
                    message: "Election not found".to_string(),
                    voters: vec![],
                    total_count: 0,
                }));
            }
        }

        // Get voters for the specific election
        match self.db.load_election_voters(&req.election_id).await {
            Ok(voter_pubkeys) => {
                // Apply pagination
                let offset = req.offset as usize;
                let limit = if req.limit == 0 {
                    100
                } else {
                    req.limit.min(1000)
                } as usize;

                let paginated_voters: Vec<String> =
                    voter_pubkeys.into_iter().skip(offset).take(limit).collect();

                let voter_infos: Vec<VoterInfo> = paginated_voters
                    .iter()
                    .map(|pubkey| VoterInfo {
                        name: format!("Voter_{}", &pubkey[..8]), // Use first 8 chars as name placeholder
                        pubkey: pubkey.clone(),
                        created_at: 0, // We don't store created_at for election voters currently
                    })
                    .collect();

                Ok(Response::new(ListVotersResponse {
                    success: true,
                    message: "Voters retrieved successfully".to_string(),
                    voters: voter_infos,
                    total_count: paginated_voters.len() as u32,
                }))
            }
            Err(e) => {
                log::error!(
                    "Failed to list voters for election {}: {}",
                    req.election_id,
                    e
                );
                Ok(Response::new(ListVotersResponse {
                    success: false,
                    message: format!("Failed to list voters: {}", e),
                    voters: vec![],
                    total_count: 0,
                }))
            }
        }
    }

    async fn list_elections(
        &self,
        request: Request<ListElectionsRequest>,
    ) -> Result<Response<ListElectionsResponse>, Status> {
        let req = request.into_inner();

        log::info!(
            "Listing elections with limit: {}, offset: {}",
            req.limit,
            req.offset
        );

        match self.db.get_elections(req.limit, req.offset).await {
            Ok(elections) => {
                let election_infos: Vec<ElectionInfo> = elections
                    .iter()
                    .map(|e| ElectionInfo {
                        id: e.id.clone(),
                        name: e.name.clone(),
                        start_time: e.start_time as u64,
                        end_time: e.end_time as u64,
                        status: e.status.clone(),
                        candidates: vec![], // TODO: Load candidates from database
                        rsa_public_key: e.rsa_pub_key.clone(),
                        created_at: e.created_at as u64,
                        updated_at: e.updated_at as u64,
                        total_votes: 0, // TODO: Load vote count from database
                    })
                    .collect();

                Ok(Response::new(ListElectionsResponse {
                    success: true,
                    message: "Elections retrieved successfully".to_string(),
                    elections: election_infos,
                    total_count: elections.len() as u32,
                }))
            }
            Err(e) => {
                log::error!("Failed to list elections: {}", e);
                Ok(Response::new(ListElectionsResponse {
                    success: false,
                    message: format!("Failed to list elections: {}", e),
                    elections: vec![],
                    total_count: 0,
                }))
            }
        }
    }

    async fn cancel_election(
        &self,
        request: Request<CancelElectionRequest>,
    ) -> Result<Response<CancelElectionResponse>, Status> {
        let req = request.into_inner();

        log::info!("Canceling election: {}", req.election_id);

        // Validate election_id
        if req.election_id.is_empty() {
            return Ok(Response::new(CancelElectionResponse {
                success: false,
                message: "Election ID cannot be empty".to_string(),
            }));
        }

        // Update election status in memory and get election for publishing
        let election_clone = {
            let mut elections_guard = self.elections.lock().await;

            let election = match elections_guard.get_mut(&req.election_id) {
                Some(e) => e,
                None => {
                    return Ok(Response::new(CancelElectionResponse {
                        success: false,
                        message: "Election not found".to_string(),
                    }));
                }
            };

            // Check if election is already canceled
            if election.status == ElectionStatus::Canceled {
                return Ok(Response::new(CancelElectionResponse {
                    success: false,
                    message: "Election is already canceled".to_string(),
                }));
            }

            // Update status to canceled
            election.status = ElectionStatus::Canceled;
            log::info!("Updated election {} status to Canceled in memory", req.election_id);

            election.clone()
        };

        // Update election in database
        match self.db.upsert_election(&election_clone).await {
            Ok(()) => {
                log::info!("Successfully updated election {} in database", req.election_id);

                // Publish updated election to Nostr
                if let Err(e) = self.publish_election_to_nostr(&election_clone).await {
                    log::error!("Failed to publish canceled election to Nostr: {}", e);
                    // Don't fail the entire operation if Nostr publishing fails
                }

                Ok(Response::new(CancelElectionResponse {
                    success: true,
                    message: "Election canceled successfully".to_string(),
                }))
            }
            Err(e) => {
                log::error!("Failed to update canceled election in database: {}", e);
                Ok(Response::new(CancelElectionResponse {
                    success: false,
                    message: format!("Failed to cancel election: {}", e),
                }))
            }
        }
    }
}
