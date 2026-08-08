# Bridge — iPhone ↔ Windows Companion System

Bridge is a zero-budget, local-first companion system designed to make an iPhone and Windows PC work together seamlessly as a unified workspace.

Inspired by the useful interactions of Apple Continuity, Bridge operates **100% locally over your Wi-Fi network** without requiring cloud servers, user accounts, paid APIs, subscriptions, or a Mac.

---

## Key Features (Phase 1 MVP)

- **QR-Code Local Pairing:** Secure Trust-on-First-Use (TOFU) device pairing over local Wi-Fi.
- **Automatic Reconnection:** Saved Keychain & Credential Manager keys re-authenticate previously paired devices seamlessly.
- **Resumable File Transfer:** 64 KB chunk binary streaming over TCP with SHA-256 integrity verification.
- **Photo Transfer:** Select single/batch photos on iPhone and transfer directly to Windows `Downloads/Bridge`.
- **Signature Feature — Photo-to-Windows-Clipboard:** Snap or select a photo on iPhone and immediately paste it into Windows with `Ctrl+V` (< 60ms latency!).
- **Explicit Clipboard Exchange:** Windows → iPhone push notifications and iPhone → Windows via iOS Share Sheet Extension, Siri Shortcuts, or in-app buttons.
- **Windows Drag-and-Drop:** Drag files into the Windows app to stream them directly to your iPhone.
- **Privacy-First Architecture:** Zero cloud logging, RAM-only transient clipboard handling, and path-traversal protection.

---

## Technology Stack

- **Windows Desktop:** Tauri 2.0, Rust, React 18, TypeScript, Tailwind CSS, `mdns-sd`, `tokio`, `arboard`, `image`.
- **iPhone Companion:** Swift 5.10, SwiftUI, `Network.framework`, `CryptoKit`, `Keychain`, `PhotosPicker`, `AppIntents`.
- **Build Infrastructure:** GitHub Actions `macos-14` runners + `xcodegen` (₱0 budget workflow).

---

## Project Documentation

- [Architecture Overview](docs/architecture.md)
- [Binary Protocol Specification](docs/protocol.md)
- [Security & Privacy Model](docs/security.md)
- [iOS Platform Boundaries & Reality Audit](docs/ios-limitations.md)
- [Testing & Validation Strategy](docs/testing.md)
- [Phase 1 MVP Report](PHASE1_MVP_REPORT.md)

---

## License

MIT License. Open-Source and Free Forever.
