use anyhow::Result;
use chrono::Utc;
use sqlx::{Pool, Sqlite, SqlitePool, Row};
use std::{fs, path::Path};

use crate::election::{Election, Status};
use crate::types::Candidate;

/// Database connection pool
pub struct Database {
    pool: Pool<Sqlite>,
}

/// Election record for database
#[derive(Debug)]
#[allow(dead_code)]
pub struct ElectionRecord {
    pub id: String,
    pub name: String,
    pub start_time: i64,
    pub end_time: i64,
    pub status: String,
    pub rsa_pub_key: String,
    pub created_at: i64,
    pub updated_at: i64,
}

/// Candidate record for database
#[derive(Debug)]
#[allow(dead_code)]
pub struct CandidateRecord {
    pub id: Option<i64>,
    pub election_id: String,
    pub candidate_id: i64,
    pub name: String,
    pub vote_count: i64,
}

/// Voter record for database  
#[derive(Debug)]
#[allow(dead_code)]
pub struct VoterRecord {
    pub id: Option<i64>,
    pub pubkey: String,
    pub reference: String,
    pub created_at: i64,
}

impl Database {
    /// Initialize database connection and create tables
    pub async fn new<P: AsRef<Path>>(db_path: P) -> Result<Self> {
        let db_path = db_path.as_ref();
        
        // Create database file if it doesn't exist
        if !db_path.exists() {
            log::info!("Creating new database at: {}", db_path.display());
            // Touch the file to create it
            fs::File::create(db_path)?;
        }

        let db_url = format!("sqlite://{}", db_path.display());
        let pool = SqlitePool::connect(&db_url).await?;
        
        let db = Database { pool };
        db.create_tables().await?;
        
        Ok(db)
    }

    /// Create database tables if they don't exist
    async fn create_tables(&self) -> Result<()> {
        // Create elections table
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS elections (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                start_time INTEGER NOT NULL,
                end_time INTEGER NOT NULL,
                status TEXT NOT NULL,
                rsa_pub_key TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
            )
            "#,
        )
        .execute(&self.pool)
        .await?;

        // Create candidates table
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS candidates (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                election_id TEXT NOT NULL,
                candidate_id INTEGER NOT NULL,
                name TEXT NOT NULL,
                vote_count INTEGER DEFAULT 0,
                FOREIGN KEY (election_id) REFERENCES elections(id),
                UNIQUE(election_id, candidate_id)
            )
            "#,
        )
        .execute(&self.pool)
        .await?;


        // Create used_tokens table to track used tokens per election
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS used_tokens (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                election_id TEXT NOT NULL,
                token_hash TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                FOREIGN KEY (election_id) REFERENCES elections(id),
                UNIQUE(election_id, token_hash)
            )
            "#,
        )
        .execute(&self.pool)
        .await?;

        // Create election_voters table to track authorized voters per election
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS election_voters (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                election_id TEXT NOT NULL,
                voter_pubkey TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                FOREIGN KEY (election_id) REFERENCES elections(id),
                UNIQUE(election_id, voter_pubkey)
            )
            "#,
        )
        .execute(&self.pool)
        .await?;

        log::info!("Database tables created successfully");
        Ok(())
    }

    /// Insert or update an election
    pub async fn upsert_election(&self, election: &Election) -> Result<()> {
        let now = Utc::now().timestamp();
        let status_str = match election.status {
            Status::Open => "open",
            Status::InProgress => "in-progress",
            Status::Finished => "finished", 
            Status::Canceled => "canceled",
        };

        // Check if election exists
        let exists = sqlx::query("SELECT 1 FROM elections WHERE id = ?")
            .bind(&election.id)
            .fetch_optional(&self.pool)
            .await?
            .is_some();

        if exists {
            // Update existing election
            sqlx::query(
                r#"
                UPDATE elections 
                SET name = ?, start_time = ?, end_time = ?, status = ?, 
                    rsa_pub_key = ?, updated_at = ?
                WHERE id = ?
                "#,
            )
            .bind(&election.name)
            .bind(election.start_time as i64)
            .bind(election.end_time as i64)
            .bind(status_str)
            .bind(&election.rsa_pub_key)
            .bind(now)
            .bind(&election.id)
            .execute(&self.pool)
            .await?;

            log::info!("Updated election {} in database", election.id);
        } else {
            // Insert new election
            sqlx::query(
                r#"
                INSERT INTO elections 
                (id, name, start_time, end_time, status, rsa_pub_key, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                "#,
            )
            .bind(&election.id)
            .bind(&election.name)
            .bind(election.start_time as i64)
            .bind(election.end_time as i64)
            .bind(status_str)
            .bind(&election.rsa_pub_key)
            .bind(now)
            .bind(now)
            .execute(&self.pool)
            .await?;

            log::info!("Inserted new election {} into database", election.id);
        }

        // Insert/update candidates
        self.upsert_candidates(&election.id, &election.candidates).await?;

        Ok(())
    }

    /// Insert or update candidates for an election
    pub async fn upsert_candidates(&self, election_id: &str, candidates: &[Candidate]) -> Result<()> {
        for candidate in candidates {
            sqlx::query(
                r#"
                INSERT INTO candidates (election_id, candidate_id, name, vote_count)
                VALUES (?, ?, ?, 0)
                ON CONFLICT(election_id, candidate_id) DO UPDATE SET
                name = excluded.name
                "#,
            )
            .bind(election_id)
            .bind(candidate.id as i64)
            .bind(&candidate.name)
            .execute(&self.pool)
            .await?;
        }

        log::debug!("Upserted {} candidates for election {}", candidates.len(), election_id);
        Ok(())
    }

    /// Update candidate vote counts
    pub async fn update_vote_counts(&self, election_id: &str, vote_counts: &[(u8, u32)]) -> Result<()> {
        for (candidate_id, count) in vote_counts {
            sqlx::query(
                "UPDATE candidates SET vote_count = ? WHERE election_id = ? AND candidate_id = ?"
            )
            .bind(*count as i64)
            .bind(election_id)
            .bind(*candidate_id as i64)
            .execute(&self.pool)
            .await?;
        }

        log::info!("Updated vote counts for election {}", election_id);
        Ok(())
    }


    /// Get all elections
    #[allow(dead_code)]
    pub async fn get_elections(&self, limit: u32, offset: u32) -> Result<Vec<ElectionRecord>> {
        let limit = if limit == 0 { 100 } else { limit.min(1000) }; // Default limit, max 1000
        
        let rows = sqlx::query("SELECT * FROM elections ORDER BY start_time DESC LIMIT ? OFFSET ?")
            .bind(limit as i64)
            .bind(offset as i64)
            .fetch_all(&self.pool)
            .await?;

        let elections = rows
            .into_iter()
            .map(|row| ElectionRecord {
                id: row.get("id"),
                name: row.get("name"),
                start_time: row.get("start_time"),
                end_time: row.get("end_time"),
                status: row.get("status"),
                rsa_pub_key: row.get("rsa_pub_key"),
                created_at: row.get("created_at"),
                updated_at: row.get("updated_at"),
            })
            .collect();

        Ok(elections)
    }

    /// Get candidates for an election
    #[allow(dead_code)]
    pub async fn get_candidates(&self, election_id: &str) -> Result<Vec<CandidateRecord>> {
        let rows = sqlx::query(
            "SELECT * FROM candidates WHERE election_id = ? ORDER BY candidate_id"
        )
        .bind(election_id)
        .fetch_all(&self.pool)
        .await?;

        let candidates = rows
            .into_iter()
            .map(|row| CandidateRecord {
                id: Some(row.get("id")),
                election_id: row.get("election_id"),
                candidate_id: row.get("candidate_id"),
                name: row.get("name"),
                vote_count: row.get("vote_count"),
            })
            .collect();

        Ok(candidates)
    }


    /// Load all elections from database
    pub async fn load_all_elections(&self) -> Result<Vec<ElectionRecord>> {
        let rows = sqlx::query("SELECT * FROM elections ORDER BY created_at DESC")
            .fetch_all(&self.pool)
            .await?;

        let elections = rows
            .into_iter()
            .map(|row| ElectionRecord {
                id: row.get("id"),
                name: row.get("name"),
                start_time: row.get("start_time"),
                end_time: row.get("end_time"),
                status: row.get("status"),
                rsa_pub_key: row.get("rsa_pub_key"),
                created_at: row.get("created_at"),
                updated_at: row.get("updated_at"),
            })
            .collect();

        Ok(elections)
    }

    /// Load authorized voters for an election
    pub async fn load_election_voters(&self, election_id: &str) -> Result<Vec<String>> {
        let rows = sqlx::query(
            "SELECT voter_pubkey FROM election_voters WHERE election_id = ?"
        )
        .bind(election_id)
        .fetch_all(&self.pool)
        .await?;

        let voters = rows
            .into_iter()
            .map(|row| row.get("voter_pubkey"))
            .collect();

        Ok(voters)
    }

    /// Load used tokens for an election
    pub async fn load_used_tokens(&self, election_id: &str) -> Result<Vec<String>> {
        let rows = sqlx::query(
            "SELECT token_hash FROM used_tokens WHERE election_id = ?"
        )
        .bind(election_id)
        .fetch_all(&self.pool)
        .await?;

        let tokens = rows
            .into_iter()
            .map(|row| row.get("token_hash"))
            .collect();

        Ok(tokens)
    }

    /// Save authorized voters for an election
    pub async fn save_election_voters(&self, election_id: &str, voters: &[String]) -> Result<()> {
        let now = chrono::Utc::now().timestamp();
        
        for voter in voters {
            sqlx::query(
                r#"
                INSERT INTO election_voters (election_id, voter_pubkey, created_at)
                VALUES (?, ?, ?)
                ON CONFLICT(election_id, voter_pubkey) DO NOTHING
                "#,
            )
            .bind(election_id)
            .bind(voter)
            .bind(now)
            .execute(&self.pool)
            .await?;
        }

        log::debug!("Saved {} authorized voters for election {}", voters.len(), election_id);
        Ok(())
    }

    /// Save used token for an election
    pub async fn save_used_token(&self, election_id: &str, token_hash: &str) -> Result<()> {
        let now = chrono::Utc::now().timestamp();
        
        sqlx::query(
            r#"
            INSERT INTO used_tokens (election_id, token_hash, created_at)
            VALUES (?, ?, ?)
            ON CONFLICT(election_id, token_hash) DO NOTHING
            "#,
        )
        .bind(election_id)
        .bind(token_hash)
        .bind(now)
        .execute(&self.pool)
        .await?;

        log::debug!("Saved used token for election {}", election_id);
        Ok(())
    }
}