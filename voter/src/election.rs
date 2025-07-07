use nostr_sdk::event::Event;

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum Status {
    Open,
    InProgress,
    Finished,
    Canceled,
}

#[derive(Debug, serde::Deserialize, Clone)]
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
    pub rsa_pub_key: String,
}

impl Election {
    pub fn new(
        id: String,
        name: String,
        candidates: Vec<Candidate>,
        start_time: u64,
        duration: u64,
        rsa_pub_key: String,
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
            rsa_pub_key,
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

    pub fn parse_result_event(event: &Event) -> Result<Vec<(u8, u32)>, anyhow::Error> {
        let data = event.content.clone();
        let results: Result<Vec<(u8, u32)>, serde_json::Error> = serde_json::from_str(&data);

        let results = match results {
            Ok(r) => r,
            Err(e) => {
                return Err(anyhow::anyhow!("Failed to parse results event: {}", e));
            }
        };

        Ok(results)
    }
}

#[derive(Debug, serde::Serialize, serde::Deserialize)]
pub struct Message {
    pub id: String,
    /// 1: Token request, 2: Vote
    pub kind: u8,
    pub payload: String,
    /// Election ID for election-specific validation
    pub election_id: Option<String>,
}

impl Message {
    pub fn new(id: String, kind: u8, payload: String) -> Self {
        Self { id, kind, payload, election_id: None }
    }

    pub fn new_with_election(id: String, kind: u8, payload: String, election_id: String) -> Self {
        Self { id, kind, payload, election_id: Some(election_id) }
    }

    pub fn from_json(json: &str) -> Result<Self, serde_json::Error> {
        serde_json::from_str(json)
    }

    pub fn as_json(&self) -> String {
        serde_json::to_string(self).unwrap()
    }
}
