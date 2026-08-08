use serde::{Deserialize, Serialize};
use std::fs::{File, OpenOptions};
use std::io::{Read, Seek, SeekFrom, Write};
use std::path::Path;

pub const CHUNK_SIZE: usize = 65536; // 64 KB

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct TransferHeader {
    pub transfer_id: String,
    pub filename: String,
    pub mime_type: String,
    pub total_size: u64,
    pub sha256: String,
    pub chunk_size: usize,
    pub total_chunks: u64,
    pub is_photo_clipboard: bool,
}

pub struct Chunker;

impl Chunker {
    /// Reads a 64 KB chunk at specific index from a file
    pub fn read_chunk(path: &Path, chunk_index: u64) -> Result<Vec<u8>, std::io::Error> {
        let mut file = File::open(path)?;
        let offset = chunk_index * (CHUNK_SIZE as u64);
        file.seek(SeekFrom::Start(offset))?;

        let mut buffer = vec![0u8; CHUNK_SIZE];
        let bytes_read = file.read(&mut buffer)?;
        buffer.truncate(bytes_read);
        Ok(buffer)
    }

    /// Writes a 64 KB chunk at specific index into .bridge.tmp file
    pub fn write_chunk(temp_path: &Path, chunk_index: u64, data: &[u8]) -> Result<(), std::io::Error> {
        let mut file = OpenOptions::new()
            .create(true)
            .write(true)
            .open(temp_path)?;

        let offset = chunk_index * (CHUNK_SIZE as u64);
        file.seek(SeekFrom::Start(offset))?;
        file.write_all(data)?;
        file.flush()?;
        Ok(())
    }

    /// Calculates total 64 KB chunks for a given file size
    pub fn calculate_total_chunks(total_size: u64) -> u64 {
        if total_size == 0 {
            1
        } else {
            (total_size + (CHUNK_SIZE as u64) - 1) / (CHUNK_SIZE as u64)
        }
    }
}
