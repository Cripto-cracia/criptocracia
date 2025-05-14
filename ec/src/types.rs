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
    pub payload: String,
}

impl Message {
    pub fn new(id: String, kind: u8, payload: String) -> Self {
        Self { id, kind, payload }
    }

    pub fn from_json(json: &str) -> Result<Self, serde_json::Error> {
        serde_json::from_str(json)
    }

    pub fn as_json(&self) -> String {
        serde_json::to_string(self).unwrap()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_candidate_new_and_eq() {
        let a = Candidate::new(5, "X");
        let b = Candidate { id: 5, name: "X" };
        assert_eq!(a, b);
    }

    #[test]
    fn test_message_json_roundtrip() {
        let msg = Message::new("abc".into(), 2, "payload".into());
        let json = msg.as_json();
        let parsed = Message::from_json(&json).expect("debe parsear bien");
        assert_eq!(parsed.id, "abc");
        assert_eq!(parsed.kind, 2);
        assert_eq!(parsed.payload, "payload");
    }
}
