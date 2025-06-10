use anyhow::Result;
use base64::engine::{Engine, general_purpose};
use blind_rsa_signatures::PublicKey as RSAPublicKey;
use chrono::Local;
use fern::Dispatch;

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

/// Loads RSA public key from Base64 enconded der public key and converts it
/// to the `blind-rsa-signatures` type.
pub fn get_ec_pubkey(b64_pubkey: &str) -> Result<RSAPublicKey> {
    let pub_der = general_purpose::STANDARD.decode(b64_pubkey)?;

    Ok(RSAPublicKey::from_der(&pub_der)?)
}
