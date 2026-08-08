use std::path::{Path, PathBuf};

pub struct Sanitizer;

impl Sanitizer {
    /// Sanitizes remote filename preventing path traversal attacks
    pub fn sanitize_filename(raw_name: &str) -> String {
        let clean_basename = Path::new(raw_name)
            .file_name()
            .and_then(|os_str| os_str.to_str())
            .unwrap_or("unnamed_file");

        let sanitized: String = clean_basename
            .chars()
            .map(|c| match c {
                '/' | '\\' | ':' | '*' | '?' | '"' | '<' | '>' | '|' | '\0' => '_',
                c if c.is_control() => '_',
                c => c,
            })
            .collect();

        if sanitized.trim().is_empty() || sanitized == "." || sanitized == ".." {
            "bridge_transferred_file".to_string()
        } else {
            sanitized
        }
    }

    /// Resolves target download path in %USERPROFILE%\Downloads\Bridge
    pub fn resolve_download_path(filename: &str) -> PathBuf {
        let clean_name = Self::sanitize_filename(filename);
        let download_dir = dirs_next::download_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join("Bridge");

        std::fs::create_dir_all(&download_dir).ok();
        download_dir.join(clean_name)
    }

    /// Resolves temporary file path (.bridge.tmp)
    pub fn resolve_temp_path(filename: &str) -> PathBuf {
        let mut target = Self::resolve_download_path(filename);
        let mut temp_name = target.file_name().unwrap_or_default().to_os_string();
        temp_name.push(".bridge.tmp");
        target.set_file_name(temp_name);
        target
    }
}
