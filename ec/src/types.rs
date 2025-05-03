use serde::{Deserialize, Serialize};

/// The candidates are represented by numbers
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash, Serialize, Deserialize)]
pub struct Candidate {
    pub id: u8,
    pub name: &'static str,
}

impl Candidate {
    pub fn new(id: u8, name: &'static str) -> Self {
        Self { id, name }
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Voter {
    pub name: String,
    pub pubkey: String,
}

#[derive(Debug, serde::Serialize, serde::Deserialize)]
pub struct Message {
    pub id: String,
    /// 1: Token request, 2: Vote
    pub kind: u8,
    pub content: String,
}

impl Message {
    pub fn new(id: String, kind: u8, content: String) -> Self {
        Self { id, kind, content }
    }

    pub fn from_json(json: &str) -> Result<Self, serde_json::Error> {
        serde_json::from_str(json)
    }

    pub fn as_json(&self) -> String {
        serde_json::to_string(self).unwrap()
    }
}
