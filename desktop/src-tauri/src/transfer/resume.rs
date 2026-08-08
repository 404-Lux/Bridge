use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Mutex;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ResumeCheckpoint {
    pub transfer_id: String,
    pub filename: String,
    pub total_size: u64,
    pub sha256: String,
    pub last_received_chunk: u64,
    pub temp_path: PathBuf,
}

pub struct ResumeStore {
    checkpoints: Mutex<HashMap<String, ResumeCheckpoint>>,
}

impl ResumeStore {
    pub fn new() -> Self {
        Self {
            checkpoints: Mutex::new(HashMap::new()),
        }
    }

    pub fn update_checkpoint(&self, checkpoint: ResumeCheckpoint) {
        if let Ok(mut lock) = self.checkpoints.lock() {
            lock.insert(checkpoint.transfer_id.clone(), checkpoint);
        }
    }

    pub fn get_checkpoint(&self, transfer_id: &str) -> Option<ResumeCheckpoint> {
        if let Ok(lock) = self.checkpoints.lock() {
            return lock.get(transfer_id).cloned();
        }
        None
    }

    pub fn remove_checkpoint(&self, transfer_id: &str) {
        if let Ok(mut lock) = self.checkpoints.lock() {
            lock.remove(transfer_id);
        }
    }
}
