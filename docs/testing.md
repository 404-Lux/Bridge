# Bridge Physical Testing Strategy

## Mandatory End-to-End Test Matrix

| Category | Test Case | Target Result |
| :--- | :--- | :--- |
| **Pairing** | Initial QR Scan & Identity Persist | QR code scanned; Keychain and Credential Manager save trusted keys. |
| **Reconnection** | App Foreground & Wi-Fi Reconnect | Disconnected session recovers automatically in < 500ms without rescanning QR. |
| **Clipboard** | Win → iOS & iOS → Win Share Sheet | Plaintext transfers over encrypted socket in < 25ms. |
| **Photos** | Photo-to-Windows-Clipboard (Ctrl+V) | Image streams to PC, decodes to DIB in RAM, and pastes directly via Ctrl+V (<60ms). |
| **Files** | 64 KB Binary Resumable Chunking | 1GB file streams with SHA-256 integrity verification; resumes after network drop. |
