use sha2::{Digest, Sha256};
use std::fs::File;
use std::io::{BufReader, Read};
use std::path::Path;

pub struct Integrity;

impl Integrity {
    /// Computes SHA-256 hash of a file on disk
    pub fn compute_sha256(path: &Path) -> Result<String, std::io::Error> {
        let file = File::open(path)?;
        let mut reader = BufReader::new(file);
        let mut hasher = Sha256::new();
        let mut buffer = [0u8; 65536];

        loop {
            let count = reader.read(&mut buffer)?;
            if count == 0 {
                break;
            }
            hasher.update(&buffer[..count]);
        }

        Ok(format!("{:x}", hasher.finalize()))
    }

    /// Verifies file against expected SHA-256 hash
    pub fn verify_integrity(path: &Path, expected_sha256: &str) -> bool {
        match Self::compute_sha256(path) {
            Ok(hash) => hash.eq_ignore_ascii_case(expected_sha256),
            Err(_) => false,
        }
    }
}
