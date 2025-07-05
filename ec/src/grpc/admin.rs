use anyhow::Result;
use std::sync::Arc;
use tokio::sync::Mutex;
use tonic::{Request, Response, Status};

use crate::database::Database;
use crate::election::{Election, Status as ElectionStatus};
use crate::grpc::admin_proto::admin_service_server::AdminService;
use crate::grpc::admin_proto::*;
use crate::types::{Candidate, Voter};

/// Implementation of the AdminService gRPC service
pub struct AdminServiceImpl {
    db: Arc<Database>,
    election: Arc<Mutex<Election>>,
}

impl AdminServiceImpl {
    /// Create a new AdminServiceImpl instance
    pub fn new(db: Arc<Database>, election: Arc<Mutex<Election>>) -> Self {
        Self { db, election }
    }

    #[cfg(test)]
    pub fn get_db(&self) -> &Arc<Database> {
        &self.db
    }

    #[cfg(test)]
    pub fn get_election_ref(&self) -> &Arc<Mutex<Election>> {
        &self.election
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
    fn validate_voter_pubkey(pubkey: &str) -> Result<(), Status> {
        if pubkey.is_empty() {
            return Err(Status::invalid_argument("Voter public key cannot be empty"));
        }

        // Check if it's a valid hex string or npub format
        if pubkey.len() < 64 {
            return Err(Status::invalid_argument("Voter public key is too short"));
        }

        // Basic validation - should be hex or start with npub
        if !pubkey.starts_with("npub") && !pubkey.chars().all(|c| c.is_ascii_hexdigit()) {
            return Err(Status::invalid_argument("Invalid voter public key format"));
        }

        Ok(())
    }

    /// Validate election name
    fn validate_election_name(name: &str) -> Result<(), Status> {
        if name.is_empty() {
            return Err(Status::invalid_argument("Election name cannot be empty"));
        }

        if name.len() > 100 {
            return Err(Status::invalid_argument("Election name is too long (max 100 characters)"));
        }

        Ok(())
    }

    /// Validate candidate data
    fn validate_candidate(candidate_id: u32, name: &str) -> Result<(), Status> {
        if candidate_id == 0 {
            return Err(Status::invalid_argument("Candidate ID must be greater than 0"));
        }

        if candidate_id > 255 {
            return Err(Status::invalid_argument("Candidate ID must be less than 256"));
        }

        if name.is_empty() {
            return Err(Status::invalid_argument("Candidate name cannot be empty"));
        }

        if name.len() > 50 {
            return Err(Status::invalid_argument("Candidate name is too long (max 50 characters)"));
        }

        Ok(())
    }
}

#[tonic::async_trait]
impl AdminService for AdminServiceImpl {
    async fn add_voter(
        &self,
        request: Request<AddVoterRequest>,
    ) -> Result<Response<AddVoterResponse>, Status> {
        let req = request.into_inner();
        
        log::info!("Adding voter: {} with pubkey: {}", req.name, req.pubkey);

        // Validate input
        if req.name.is_empty() {
            return Ok(Response::new(AddVoterResponse {
                success: false,
                message: "Voter name cannot be empty".to_string(),
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

        // Create voter
        let voter = Voter {
            name: req.name.clone(),
            pubkey: req.pubkey.clone(),
        };

        // Add to database
        match self.db.upsert_voters(&[voter.clone()]).await {
            Ok(()) => {
                log::info!("Successfully added voter: {}", req.name);
                Ok(Response::new(AddVoterResponse {
                    success: true,
                    message: "Voter added successfully".to_string(),
                    voter_id: req.pubkey,
                }))
            }
            Err(e) => {
                log::error!("Failed to add voter: {}", e);
                Ok(Response::new(AddVoterResponse {
                    success: false,
                    message: format!("Failed to add voter: {}", e),
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
        let candidates: Vec<Candidate> = req.candidates
            .iter()
            .map(|c| Candidate::new(c.id as u8, Box::leak(c.name.clone().into_boxed_str())))
            .collect();

        let election_name = req.name.clone();

        // Create election
        let election = Election::new(
            req.name,
            candidates,
            req.start_time,
            req.duration,
            req.rsa_public_key,
        );

        let election_id = election.id.clone();

        // Replace current election (for now, we support only one election)
        {
            let mut current_election = self.election.lock().await;
            *current_election = election.clone();
        }

        // Add to database
        match self.db.upsert_election(&election).await {
            Ok(()) => {
                log::info!("Successfully added election: {}", election_name);
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
        
        log::info!("Adding candidate: {} to election: {}", req.name, req.election_id);

        // Validate input
        if let Err(e) = Self::validate_candidate(req.candidate_id, &req.name) {
            return Ok(Response::new(AddCandidateResponse {
                success: false,
                message: format!("Invalid candidate: {}", e.message()),
            }));
        }

        // Check if election exists and add candidate
        {
            let mut election = self.election.lock().await;
            
            if election.id != req.election_id {
                return Ok(Response::new(AddCandidateResponse {
                    success: false,
                    message: "Election not found".to_string(),
                }));
            }

            // Check if candidate ID already exists
            if election.candidates.iter().any(|c| c.id == req.candidate_id as u8) {
                return Ok(Response::new(AddCandidateResponse {
                    success: false,
                    message: "Candidate ID already exists".to_string(),
                }));
            }

            // Add candidate
            let candidate = Candidate::new(
                req.candidate_id as u8,
                Box::leak(req.name.clone().into_boxed_str())
            );
            election.candidates.push(candidate);
        }

        // Update database
        let election_clone = {
            let election = self.election.lock().await;
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

        let election = self.election.lock().await;
        
        if election.id != req.election_id {
            return Ok(Response::new(GetElectionResponse {
                success: false,
                message: "Election not found".to_string(),
                election: Some(ElectionInfo::default()),
            }));
        }

        let election_info = Self::election_to_info(&election);
        
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
        
        log::info!("Listing voters with limit: {}, offset: {}", req.limit, req.offset);

        match self.db.get_voters(req.limit, req.offset).await {
            Ok(voters) => {
                let voter_infos: Vec<VoterInfo> = voters
                    .iter()
                    .map(|v| VoterInfo {
                        name: v.reference.clone(),
                        pubkey: v.pubkey.clone(),
                        created_at: v.created_at as u64,
                    })
                    .collect();

                Ok(Response::new(ListVotersResponse {
                    success: true,
                    message: "Voters retrieved successfully".to_string(),
                    voters: voter_infos,
                    total_count: voters.len() as u32,
                }))
            }
            Err(e) => {
                log::error!("Failed to list voters: {}", e);
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
        
        log::info!("Listing elections with limit: {}, offset: {}", req.limit, req.offset);

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
}