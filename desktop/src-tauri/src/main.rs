// Prevents additional console window on Windows in release
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod clipboard;
mod commands;
mod filesystem;
mod security;
mod transfer;

use commands::*;

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            get_local_identity,
            send_clipboard_to_iphone,
            copy_text_to_clipboard,
            get_received_files,
        ])
        .run(tauri::generate_context!())
        .expect("error while running Bridge Tauri application");
}
