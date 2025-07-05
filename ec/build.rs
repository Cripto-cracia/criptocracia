use std::env;
use std::path::PathBuf;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
    
    tonic_build::configure()
        .build_server(true)
        .build_client(true)
        .file_descriptor_set_path(out_dir.join("admin_descriptor.bin"))
        .compile(
            &["proto/admin.proto"],
            &["proto"]
        )?;
    
    // Tell Cargo to recompile if the proto files change
    println!("cargo:rerun-if-changed=proto/admin.proto");
    
    Ok(())
}