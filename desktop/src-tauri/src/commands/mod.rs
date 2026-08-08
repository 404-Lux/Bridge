use crate::clipboard::win_clipboard::WinClipboard;
use crate::filesystem::sanitizer::Sanitizer;
use crate::security::identity::{IdentityStore, LocalIdentity};
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct FileItem {
    pub name: String,
    pub path: String,
    pub size: u64,
}

#[tauri::command]
pub fn get_local_identity() -> Result<LocalIdentity, String> {
    Ok(IdentityStore::get_or_create_identity())
}

#[tauri::command]
pub fn send_clipboard_to_iphone(text: String) -> Result<bool, String> {
    WinClipboard::set_text(&text)?;
    Ok(true)
}

#[tauri::command]
pub fn copy_text_to_clipboard(text: String) -> Result<bool, String> {
    WinClipboard::set_text(&text)?;
    Ok(true)
}

#[tauri::command]
pub fn get_received_files() -> Result<Vec<FileItem>, String> {
    let download_dir = Sanitizer::resolve_download_path("test").parent().unwrap().to_path_buf();
    let mut files = Vec::new();

    if let Ok(entries) = std::fs::read_dir(download_dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_file() && !path.extension().map_or(false, |ext| ext == "tmp") {
                let name = path.file_name().unwrap_or_default().to_string_lossy().to_string();
                let meta = path.metadata().ok();
                let size = meta.map(|m| m.len()).unwrap_or(0);
                files.push(FileItem {
                    name,
                    path: path.to_string_lossy().to_string(),
                    size,
                });
            }
        }
    }

    Ok(files)
}
