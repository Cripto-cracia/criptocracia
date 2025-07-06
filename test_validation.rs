// Direct test of validation logic
use nostr_sdk::PublicKey;

fn validate_voter_pubkey(pubkey: &str) -> Result<(), String> {
    println!("DEBUG: Validating pubkey: '{}'", pubkey);
    println!("DEBUG: Length: {}", pubkey.len());
    
    if pubkey.is_empty() {
        return Err("Voter public key cannot be empty".to_string());
    }
    
    // Use Nostr SDK to validate the format (same as election.rs does)
    if pubkey.starts_with("npub") {
        println!("DEBUG: Validating as npub format");
        if let Err(e) = PublicKey::parse(pubkey) {
            println!("DEBUG: npub validation failed: {}", e);
            return Err("Invalid npub format".to_string());
        }
    } else {
        println!("DEBUG: Validating as hex format");
        if let Err(e) = PublicKey::from_hex(pubkey) {
            println!("DEBUG: Hex validation failed: {}", e);
            return Err("Invalid hex pubkey format".to_string());
        }
    }

    println!("DEBUG: Pubkey validation successful");
    Ok(())
}

fn main() {
    let test_npub = "npub1qqqqqxkw2lgd59lurptz73jc43ksjwevezahh4zg20gvr9hzf2wq8nzqyl";
    let test_hex = "00001001063e6bf1b28f6514ac651afef7f51b2a792f0416a5e8273daa9eea6e";
    
    println!("Testing npub:");
    match validate_voter_pubkey(test_npub) {
        Ok(()) => println!("✅ npub validation passed"),
        Err(e) => println!("❌ npub validation failed: {}", e),
    }
    
    println!("\nTesting hex:");
    match validate_voter_pubkey(test_hex) {
        Ok(()) => println!("✅ hex validation passed"),
        Err(e) => println!("❌ hex validation failed: {}", e),
    }
}