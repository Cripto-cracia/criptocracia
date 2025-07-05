pub mod admin;
pub mod server;
#[cfg(test)]
mod tests;

// Include the generated protobuf code
pub mod admin_proto {
    tonic::include_proto!("admin");
}