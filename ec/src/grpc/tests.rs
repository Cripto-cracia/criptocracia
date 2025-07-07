#[cfg(test)]
mod admin_service_tests {
    use super::super::admin::AdminServiceImpl;
    use super::super::admin_proto::admin_service_server::AdminService;
    use super::super::admin_proto::*;
    use crate::database::Database;
    use crate::election::Election;
    use crate::types::Candidate;
    use std::collections::HashMap;
    use std::sync::Arc;
    use tempfile::NamedTempFile;
    use tokio::sync::Mutex;
    use tonic::Request;
    use nostr_sdk::{Client, Keys};

    async fn create_test_service() -> (AdminServiceImpl, NamedTempFile, String) {
        // Create temporary database
        let temp_file = NamedTempFile::new().unwrap();
        let db = Arc::new(Database::new(temp_file.path()).await.unwrap());

        // Create test election
        let candidates = vec![Candidate::new(1, "Alice"), Candidate::new(2, "Bob")];
        let election = Election::new(
            "Test Election".to_string(),
            candidates,
            1234567890,
            3600,
            "test_rsa_key".to_string(),
        );
        let election_id = election.id.clone();
        
        // Save election to database first
        db.upsert_election(&election).await.unwrap();
        
        // Create elections HashMap
        let mut elections = HashMap::new();
        elections.insert(election_id.clone(), election);
        let elections = Arc::new(Mutex::new(elections));
        
        // Create mock Nostr client and keys for testing
        let keys = Keys::generate();
        let client = Client::new(keys.clone());
        
        let service = AdminServiceImpl::new(
            db,
            elections,
            "test_rsa_key".to_string(),
            Arc::new(client),
            Arc::new(keys),
        );
        
        (service, temp_file, election_id)
    }

    #[tokio::test]
    async fn test_add_voter_success() {
        let (service, _temp_file, election_id) = create_test_service().await;

        let request = Request::new(AddVoterRequest {
            name: "Test Voter".to_string(),
            pubkey: "00001001063e6bf1b28f6514ac651afef7f51b2a792f0416a5e8273daa9eea6e".to_string(),
            election_id: election_id.clone(),
        });

        let response = service.add_voter(request).await.unwrap();
        let inner = response.into_inner();

        assert!(inner.success);
        assert_eq!(inner.message, "Voter added to election successfully");
        assert!(!inner.voter_id.is_empty());
    }

    #[tokio::test]
    async fn test_add_voter_empty_name() {
        let (service, _temp_file, election_id) = create_test_service().await;

        let request = Request::new(AddVoterRequest {
            name: "".to_string(),
            pubkey: "00001001063e6bf1b28f6514ac651afef7f51b2a792f0416a5e8273daa9eea6e".to_string(),
            election_id: election_id.clone(),
        });

        let response = service.add_voter(request).await.unwrap();
        let inner = response.into_inner();

        assert!(!inner.success);
        assert_eq!(inner.message, "Voter name cannot be empty");
        assert!(inner.voter_id.is_empty());
    }

    #[tokio::test]
    async fn test_add_voter_invalid_pubkey() {
        let (service, _temp_file, election_id) = create_test_service().await;

        let request = Request::new(AddVoterRequest {
            name: "Test Voter".to_string(),
            pubkey: "invalid_key".to_string(),
            election_id: election_id.clone(),
        });

        let response = service.add_voter(request).await.unwrap();
        let inner = response.into_inner();

        assert!(!inner.success);
        assert!(inner.message.contains("Invalid voter public key"));
        assert!(inner.voter_id.is_empty());
    }

    #[tokio::test]
    async fn test_add_election_success() {
        let (service, _temp_file, _election_id) = create_test_service().await;

        let candidates = vec![
            CandidateInfo {
                id: 1,
                name: "Candidate A".to_string(),
                vote_count: 0,
            },
            CandidateInfo {
                id: 2,
                name: "Candidate B".to_string(),
                vote_count: 0,
            },
        ];

        let request = Request::new(AddElectionRequest {
            name: "New Test Election".to_string(),
            start_time: 1234567890,
            duration: 3600,
            candidates,
        });

        let response = service.add_election(request).await.unwrap();
        let inner = response.into_inner();

        assert!(inner.success);
        assert_eq!(inner.message, "Election added successfully");
        assert!(!inner.election_id.is_empty());
    }

    #[tokio::test]
    async fn test_add_election_empty_name() {
        let (service, _temp_file, _election_id) = create_test_service().await;

        let request = Request::new(AddElectionRequest {
            name: "".to_string(),
            start_time: 1234567890,
            duration: 3600,
            candidates: vec![],
        });

        let response = service.add_election(request).await.unwrap();
        let inner = response.into_inner();

        assert!(!inner.success);
        assert!(inner.message.contains("Invalid election name"));
        assert!(inner.election_id.is_empty());
    }

    #[tokio::test]
    async fn test_add_election_no_candidates() {
        let (service, _temp_file, _election_id) = create_test_service().await;

        let request = Request::new(AddElectionRequest {
            name: "Test Election".to_string(),
            start_time: 1234567890,
            duration: 3600,
            candidates: vec![],
        });

        let response = service.add_election(request).await.unwrap();
        let inner = response.into_inner();

        assert!(!inner.success);
        assert_eq!(inner.message, "Election must have at least one candidate");
        assert!(inner.election_id.is_empty());
    }

    #[tokio::test]
    async fn test_add_candidate_success() {
        let (service, _temp_file, election_id) = create_test_service().await;

        let request = Request::new(AddCandidateRequest {
            election_id,
            candidate_id: 3,
            name: "New Candidate".to_string(),
        });

        let response = service.add_candidate(request).await.unwrap();
        let inner = response.into_inner();

        assert!(inner.success);
        assert_eq!(inner.message, "Candidate added successfully");
    }

    #[tokio::test]
    async fn test_add_candidate_election_not_found() {
        let (service, _temp_file, _election_id) = create_test_service().await;

        let request = Request::new(AddCandidateRequest {
            election_id: "nonexistent_election".to_string(),
            candidate_id: 3,
            name: "New Candidate".to_string(),
        });

        let response = service.add_candidate(request).await.unwrap();
        let inner = response.into_inner();

        assert!(!inner.success);
        assert_eq!(inner.message, "Election not found");
    }

    #[tokio::test]
    async fn test_add_candidate_duplicate_id() {
        let (service, _temp_file, election_id) = create_test_service().await;

        let request = Request::new(AddCandidateRequest {
            election_id,
            candidate_id: 1, // This ID already exists in the test election
            name: "Duplicate Candidate".to_string(),
        });

        let response = service.add_candidate(request).await.unwrap();
        let inner = response.into_inner();

        assert!(!inner.success);
        assert_eq!(inner.message, "Candidate ID already exists");
    }

    #[tokio::test]
    async fn test_get_election_success() {
        let (service, _temp_file, election_id) = create_test_service().await;

        let request = Request::new(GetElectionRequest { election_id });

        let response = AdminService::get_election(&service, request).await.unwrap();
        let inner = response.into_inner();

        assert!(inner.success);
        assert_eq!(inner.message, "Election retrieved successfully");
        assert!(inner.election.is_some());

        let election_info = inner.election.unwrap();
        assert_eq!(election_info.name, "Test Election");
        assert_eq!(election_info.candidates.len(), 2);
    }

    #[tokio::test]
    async fn test_get_election_not_found() {
        let (service, _temp_file, _election_id) = create_test_service().await;

        let request = Request::new(GetElectionRequest {
            election_id: "nonexistent_election".to_string(),
        });

        let response = AdminService::get_election(&service, request).await.unwrap();
        let inner = response.into_inner();

        assert!(!inner.success);
        assert_eq!(inner.message, "Election not found");
    }

    #[tokio::test]
    async fn test_list_voters() {
        let (service, _temp_file, election_id) = create_test_service().await;

        // Add some test voters to the election first
        let voter_pubkeys = vec![
            "00001001063e6bf1b28f6514ac651afef7f51b2a792f0416a5e8273daa9eea6e".to_string(),
            "3f55f3701e9b00dce27ab6cce6cf487fd5c4ba48f46d475926ebf916d53a9db1".to_string(),
        ];
        service.get_db().save_election_voters(&election_id, &voter_pubkeys).await.unwrap();

        let request = Request::new(ListVotersRequest {
            limit: 10,
            offset: 0,
            election_id: election_id.clone(),
        });

        let response = service.list_voters(request).await.unwrap();
        let inner = response.into_inner();

        assert!(inner.success);
        assert_eq!(inner.message, "Voters retrieved successfully");
        assert_eq!(inner.voters.len(), 2);
    }

    #[tokio::test]
    async fn test_list_elections() {
        let (service, _temp_file, _election_id) = create_test_service().await;

        // The service already has one test election
        let request = Request::new(ListElectionsRequest {
            limit: 10,
            offset: 0,
        });

        let response = service.list_elections(request).await.unwrap();
        let inner = response.into_inner();

        assert!(inner.success);
        assert_eq!(inner.message, "Elections retrieved successfully");
        // Note: This might be 0 if the election wasn't saved to DB in the test setup
        // Note: This might be 0 if the election wasn't saved to DB in the test setup
        // Removed useless comparison: assert!(inner.total_count >= 0);
    }

    #[tokio::test]
    async fn test_validation_candidate_id_zero() {
        let (service, _temp_file, election_id) = create_test_service().await;

        let request = Request::new(AddCandidateRequest {
            election_id,
            candidate_id: 0, // Invalid ID
            name: "Test Candidate".to_string(),
        });

        let response = service.add_candidate(request).await.unwrap();
        let inner = response.into_inner();

        assert!(!inner.success);
        assert!(
            inner
                .message
                .contains("Candidate ID must be greater than 0")
        );
    }

    #[tokio::test]
    async fn test_validation_candidate_id_too_large() {
        let (service, _temp_file, election_id) = create_test_service().await;

        let request = Request::new(AddCandidateRequest {
            election_id,
            candidate_id: 256, // Too large
            name: "Test Candidate".to_string(),
        });

        let response = service.add_candidate(request).await.unwrap();
        let inner = response.into_inner();

        assert!(!inner.success);
        assert!(inner.message.contains("Candidate ID must be less than 256"));
    }

    #[tokio::test]
    async fn test_validation_empty_candidate_name() {
        let (service, _temp_file, election_id) = create_test_service().await;

        let request = Request::new(AddCandidateRequest {
            election_id,
            candidate_id: 5,
            name: "".to_string(), // Empty name
        });

        let response = service.add_candidate(request).await.unwrap();
        let inner = response.into_inner();

        assert!(!inner.success);
        assert!(inner.message.contains("Candidate name cannot be empty"));
    }

    #[tokio::test]
    async fn test_cancel_election_success() {
        let (service, _temp_file, election_id) = create_test_service().await;

        let request = Request::new(CancelElectionRequest {
            election_id: election_id.clone(),
        });

        let response = service.cancel_election(request).await.unwrap();
        let inner = response.into_inner();

        assert!(inner.success);
        assert_eq!(inner.message, "Election canceled successfully");

        // Verify the election status was updated in memory
        let elections_guard = service.get_elections().lock().await;
        let election = elections_guard.get(&election_id).unwrap();
        assert_eq!(election.status, crate::election::Status::Canceled);
    }

    #[tokio::test]
    async fn test_cancel_election_not_found() {
        let (service, _temp_file, _election_id) = create_test_service().await;

        let request = Request::new(CancelElectionRequest {
            election_id: "nonexistent_election".to_string(),
        });

        let response = service.cancel_election(request).await.unwrap();
        let inner = response.into_inner();

        assert!(!inner.success);
        assert_eq!(inner.message, "Election not found");
    }

    #[tokio::test]
    async fn test_cancel_election_empty_id() {
        let (service, _temp_file, _election_id) = create_test_service().await;

        let request = Request::new(CancelElectionRequest {
            election_id: "".to_string(),
        });

        let response = service.cancel_election(request).await.unwrap();
        let inner = response.into_inner();

        assert!(!inner.success);
        assert_eq!(inner.message, "Election ID cannot be empty");
    }

    #[tokio::test]
    async fn test_cancel_election_already_canceled() {
        let (service, _temp_file, election_id) = create_test_service().await;

        // First cancel the election
        let request1 = Request::new(CancelElectionRequest {
            election_id: election_id.clone(),
        });
        let response1 = service.cancel_election(request1).await.unwrap();
        assert!(response1.into_inner().success);

        // Try to cancel it again
        let request2 = Request::new(CancelElectionRequest {
            election_id: election_id.clone(),
        });
        let response2 = service.cancel_election(request2).await.unwrap();
        let inner = response2.into_inner();

        assert!(!inner.success);
        assert_eq!(inner.message, "Election is already canceled");
    }

    #[tokio::test]
    async fn test_cancel_election_database_update() {
        let (service, _temp_file, election_id) = create_test_service().await;

        let request = Request::new(CancelElectionRequest {
            election_id: election_id.clone(),
        });

        let response = service.cancel_election(request).await.unwrap();
        let inner = response.into_inner();

        assert!(inner.success);

        // Verify the election was updated in the database
        let election_records = service.get_db().load_all_elections().await.unwrap();
        let canceled_election = election_records
            .iter()
            .find(|e| e.id == election_id)
            .unwrap();
        assert_eq!(canceled_election.status, "canceled");
    }
}
