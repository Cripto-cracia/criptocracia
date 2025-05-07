use anyhow::Result;
use blind_rsa_signatures::{PublicKey as RSAPublicKey, SecretKey as RSASecretKey};
use chrono::Local;
use fern::Dispatch;
use std::fs;
use std::path::Path;

/// Loads RSA keys from two PEM files and converts them
/// to the `blind-rsa-signatures` types.
pub fn load_keys<P: AsRef<Path>>(
    priv_path: P,
    pub_path: P,
) -> Result<(RSAPublicKey, RSASecretKey)> {
    let priv_pem = fs::read_to_string(priv_path)?;
    let pub_pem = fs::read_to_string(pub_path)?;

    // Parse the PEM to RSA objects
    let sk = RSASecretKey::from_pem(&priv_pem)?;
    let pk = RSAPublicKey::from_pem(&pub_pem)?;

    Ok((pk, sk))
}

/// Initialize logger function
pub fn setup_logger(level: log::LevelFilter) -> Result<(), fern::InitError> {
    Dispatch::new()
        .format(|out, message, record| {
            out.finish(format_args!(
                "[{}] [{}] - {}",
                Local::now().format("%Y-%m-%d %H:%M:%S"),
                record.level(),
                message
            ))
        })
        .level(level)
        .chain(fern::log_file("app.log")?)
        .apply()?;
    Ok(())
}
