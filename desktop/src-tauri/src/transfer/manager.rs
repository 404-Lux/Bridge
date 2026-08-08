use crate::clipboard::win_clipboard::WinClipboard;
use crate::filesystem::sanitizer::Sanitizer;
use crate::transfer::chunker::{Chunker, TransferHeader};
use crate::transfer::integrity::Integrity;
use crate::transfer::resume::{ResumeCheckpoint, ResumeStore};

use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::sync::Arc;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub enum TransferStatus {
    Queued,
    Transferring { progress_pct: f32, current_chunk: u64 },
    Verifying,
    Completed { final_path: String },
    PhotoCopiedToClipboard,
    Failed { reason: String },
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct TransferState {
    pub transfer_id: String,
    pub filename: String,
    pub total_size: u64,
    pub status: TransferStatus,
}

pub struct TransferManager {
    resume_store: Arc<ResumeStore>,
}

impl TransferManager {
    pub fn new() -> Self {
        Self {
            resume_store: Arc::new(ResumeStore::new()),
        }
    }

    /// Handles incoming 64 KB binary chunk
    pub fn process_incoming_chunk(
        &self,
        header: &TransferHeader,
        chunk_index: u64,
        chunk_data: &[u8],
    ) -> Result<TransferStatus, String> {
        let temp_path = Sanitizer::resolve_temp_path(&header.filename);

        Chunker::write_chunk(&temp_path, chunk_index, chunk_data)
            .map_err(|e| format!("Disk write error: {}", e))?;

        self.resume_store.update_checkpoint(ResumeCheckpoint {
            transfer_id: header.transfer_id.clone(),
            filename: header.filename.clone(),
            total_size: header.total_size,
            sha256: header.sha256.clone(),
            last_received_chunk: chunk_index,
            temp_path: temp_path.clone(),
        });

        let progress_pct = ((chunk_index + 1) as f32 / header.total_chunks as f32) * 100.0;

        if chunk_index + 1 >= header.total_chunks {
            let final_path = Sanitizer::resolve_download_path(&header.filename);

            if !Integrity::verify_integrity(&temp_path, &header.sha256) {
                std::fs::remove_file(&temp_path).ok();
                self.resume_store.remove_checkpoint(&header.transfer_id);
                return Err("SHA-256 integrity verification failed".to_string());
            }

            // Handle Photo-to-Clipboard signature feature
            if header.is_photo_clipboard {
                if let Ok(bytes) = std::fs::read(&temp_path) {
                    if WinClipboard::set_image_bytes(&bytes).is_ok() {
                        std::fs::remove_file(&temp_path).ok();
                        self.resume_store.remove_checkpoint(&header.transfer_id);
                        return Ok(TransferStatus::PhotoCopiedToClipboard);
                    }
                }
            }

            std::fs::rename(&temp_path, &final_path)
                .map_err(|e| format!("Failed to finalize file: {}", e))?;

            self.resume_store.remove_checkpoint(&header.transfer_id);
            Ok(TransferStatus::Completed {
                final_path: final_path.to_string_lossy().to_string(),
            })
        } else {
            Ok(TransferStatus::Transferring {
                progress_pct,
                current_chunk: chunk_index,
            })
        }
    }
}
