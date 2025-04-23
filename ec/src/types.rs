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