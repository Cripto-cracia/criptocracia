use anyhow::Result;
use nostr_sdk::{Client, Keys};
use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::sync::Mutex;
use tonic::transport::Server;

use crate::database::Database;
use crate::election::Election;
use crate::grpc::admin::AdminServiceImpl;
use crate::grpc::admin_proto::admin_service_server::AdminServiceServer;

/// gRPC server configuration
pub struct GrpcServer {
    pub port: u16,
    pub addr: SocketAddr,
}

impl GrpcServer {
    /// Create a new gRPC server instance
    pub fn new(port: u16) -> Self {
        let addr = SocketAddr::from(([127, 0, 0, 1], port));
        Self { port, addr }
    }

    /// Start the gRPC server
    pub async fn start(
        &self,
        db: Arc<Database>,
        elections: Arc<Mutex<HashMap<String, Election>>>,
        rsa_public_key: String,
        client: Arc<Client>,
        keys: Arc<Keys>,
    ) -> Result<()> {
        let admin_service = AdminServiceImpl::new(db, elections, rsa_public_key, client, keys);
        
        log::info!("Starting gRPC server on {}", self.addr);
        
        Server::builder()
            .add_service(AdminServiceServer::new(admin_service))
            .serve(self.addr)
            .await
            .map_err(|e| anyhow::anyhow!("gRPC server failed: {}", e))?;
        
        Ok(())
    }
}

impl Default for GrpcServer {
    fn default() -> Self {
        Self::new(50001)
    }
}