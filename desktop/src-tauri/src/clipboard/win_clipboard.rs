use arboard::{Clipboard, ImageData};
use image::GenericImageView;

pub struct WinClipboard;

impl WinClipboard {
    /// Reads plaintext from Windows Clipboard
    pub fn get_text() -> Result<String, String> {
        let mut clipboard = Clipboard::new().map_err(|e| e.to_string())?;
        clipboard.get_text().map_err(|e| e.to_string())
    }

    /// Sets plaintext on Windows Clipboard
    pub fn set_text(text: &str) -> Result<(), String> {
        let mut clipboard = Clipboard::new().map_err(|e| e.to_string())?;
        clipboard.set_text(text.to_string()).map_err(|e| e.to_string())
    }

    /// Sets image bytes (JPEG/PNG/HEIC transcoded) directly on Windows Clipboard
    pub fn set_image_bytes(image_bytes: &[u8]) -> Result<(), String> {
        let img = image::load_from_memory(image_bytes).map_err(|e| e.to_string())?;
        let (width, height) = img.dimensions();
        let rgba = img.to_rgba8().into_raw();

        let image_data = ImageData {
            width: width as usize,
            height: height as usize,
            bytes: rgba.into(),
        };

        let mut clipboard = Clipboard::new().map_err(|e| e.to_string())?;
        clipboard.set_image(image_data).map_err(|e| e.to_string())
    }
}
