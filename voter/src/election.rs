pub enum Status {
    Open,
    InProgress,
    Finished,
    Canceled,
}
pub struct Candidate {
    pub id: u8,
    pub name: &'static str,
}

impl Candidate {
    pub fn new(id: u8, name: &'static str) -> Self {
        Self { id, name }
    }
}

pub struct Election {
    pub id: String,
    pub name: String,
    pub candidate: Vec<Candidate>,
    pub start_time: u64,
    pub end_time: u64,
    pub status: Status,
}