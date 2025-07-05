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
    let priv_path = priv_path.as_ref();
    let pub_path = pub_path.as_ref();

    // Check if private key file exists
    if !priv_path.exists() {
        return Err(anyhow::anyhow!(
            "Required file not found: {}\nPlease ensure the RSA private key file is in the specified directory.",
            priv_path.display()
        ));
    }

    // Check if public key file exists
    if !pub_path.exists() {
        return Err(anyhow::anyhow!(
            "Required file not found: {}\nPlease ensure the RSA public key file is in the specified directory.",
            pub_path.display()
        ));
    }

    let priv_pem = fs::read_to_string(priv_path)
        .map_err(|e| anyhow::anyhow!("Failed to read private key file {}: {}", priv_path.display(), e))?;
    let pub_pem = fs::read_to_string(pub_path)
        .map_err(|e| anyhow::anyhow!("Failed to read public key file {}: {}", pub_path.display(), e))?;

    // Parse the PEM to RSA objects
    let sk = RSASecretKey::from_pem(&priv_pem)
        .map_err(|e| anyhow::anyhow!("Failed to parse private key from {}: {}", priv_path.display(), e))?;
    let pk = RSAPublicKey::from_pem(&pub_pem)
        .map_err(|e| anyhow::anyhow!("Failed to parse public key from {}: {}", pub_path.display(), e))?;

    Ok((pk, sk))
}

/// Validates that all required files exist in the specified directory
pub fn validate_required_files<P: AsRef<Path>>(app_dir: P) -> Result<()> {
    let app_dir = app_dir.as_ref();
    let mut missing_files = Vec::new();
    
    let required_files = [
        ("ec_private.pem", "RSA private key"),
        ("ec_public.pem", "RSA public key"),
        ("voters_pubkeys.json", "authorized voters list"),
    ];
    
    for (filename, description) in &required_files {
        let file_path = app_dir.join(filename);
        if !file_path.exists() {
            missing_files.push(format!("  - {} ({}): {}", filename, description, file_path.display()));
        }
    }
    
    if !missing_files.is_empty() {
        return Err(anyhow::anyhow!(
            "Required files not found in directory: {}\n\nMissing files:\n{}\n\nPlease ensure all required files are in the specified directory.",
            app_dir.display(),
            missing_files.join("\n")
        ));
    }
    
    Ok(())
}

/// Initialize logger function
pub fn setup_logger<P: AsRef<Path>>(level: log::LevelFilter, log_file_path: P) -> Result<(), fern::InitError> {
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
        .chain(fern::log_file(log_file_path)?)
        .apply()?;
    Ok(())
}
