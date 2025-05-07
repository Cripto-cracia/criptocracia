use anyhow::Result;
use blind_rsa_signatures::PublicKey as RSAPublicKey;
use chrono::Local;
use fern::Dispatch;
use std::fs;
use std::path::Path;

/// Initialize logger function
pub fn setup_logger(level: &str) -> Result<(), fern::InitError> {
    let log_level = match level.to_lowercase().as_str() {
        "trace" => log::LevelFilter::Trace,
        "debug" => log::LevelFilter::Debug,
        "info" => log::LevelFilter::Info,
        "warn" => log::LevelFilter::Warn,
        "error" => log::LevelFilter::Error,
        _ => log::LevelFilter::Info, // Default to Info for invalid values
    };
    Dispatch::new()
        .format(|out, message, record| {
            out.finish(format_args!(
                "[{}] [{}] - {}",
                Local::now().format("%Y-%m-%d %H:%M:%S"),
                record.level(),
                message
            ))
        })
        .level(log_level)
        .chain(fern::log_file("app.log")?) // Guarda en logs/app.log
        .apply()?;
    Ok(())
}

/// Loads RSA public key from PEM files and converts it
/// to the `blind-rsa-signatures` type.
pub fn load_ec_pubkey<P: AsRef<Path>>(pub_path: P) -> Result<RSAPublicKey> {
    let pub_pem = fs::read_to_string(pub_path)?;

    // Parse the PEM to RSA
    Ok(RSAPublicKey::from_pem(&pub_pem)?)
}
