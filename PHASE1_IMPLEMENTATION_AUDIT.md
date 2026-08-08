# Project Bridge — Phase 1 Implementation Audit

**Document Version:** 1.0  
**Phase:** Phase 1 MVP Pre-Implementation Audit  
**Target Environment:** Windows 11/10 (Tauri 2 / Rust) ↔ Physical iPhone (Swift / iOS 16+) over Local LAN  
**Operating Budget:** ₱0 (Zero Budget / Open Source Infrastructure)

---

## 1. Executive Summary
This audit evaluates the codebase following the completion of PoC 0 through PoC 4. The underlying core networking (`Network.framework` on iOS), cryptographic security (`CryptoKit` Curve25519 ECDH + AES-256-GCM with Keychain persistence), and build workflow (`macos-14` GitHub Actions CI + `xcodegen`) have been thoroughly validated. 

However, the existing codebase contains temporary PoC UI layers and scaffolded/mocked Rust Tauri IPC commands. This audit maps existing assets against Phase 1 MVP requirements, outlines necessary refactoring, and establishes a strict 10-milestone execution sequence.

---

## 2. Current Repository Audit Matrix

| Module / Component | File Location | Current Status | Action Required for Phase 1 MVP |
| :--- | :--- | :--- | :--- |
| **iOS Crypto Core** | `ios/BridgeCompanion/Networking/CryptoHelper.swift` | **VERIFIED / WORKING** | Keychain identity storage, Curve25519 ECDH, HKDF-SHA256, AES-256-GCM nonces working. Keep & modularize into `Security/`. |
| **iOS Network Engine** | `ios/BridgeCompanion/Networking/NetworkManager.swift` | **WORKING (Needs Refactor)** | Working mDNS, TCP framing, 9-state machine, backoff engine. Refactor into modular `Networking/` & `Transfers/` services. |
| **iOS Siri Shortcut Intent**| `ios/BridgeCompanion/AppIntents/BridgeAppIntent.swift` | **VERIFIED / WORKING** | Native iOS 16+ `AppIntent` working. Connect to unified transfer manager. |
| **iOS UI Layer** | `ios/BridgeCompanion/Views/MainView.swift` | **SCAFFOLDED (PoC 3 UI)** | Upgrade to full Phase 1 SwiftUI interface (Connection Card, Quick Actions, Recent Items, Progress, Diagnostic Overlay). |
| **iOS QR Scanner** | `ios/BridgeCompanion/Views/PairingQRScannerView.swift` | **VERIFIED / WORKING** | Working `AVCaptureSession` QR scanner. Move to `Pairing/`. |
| **iOS XcodeGen Spec** | `ios/project.yml` | **VERIFIED / WORKING** | Mac-less Xcode project generator. Add Share Sheet Extension target definition. |
| **GitHub Actions CI** | `.github/workflows/ios-build.yml` | **VERIFIED / WORKING** | Automated macOS runner `.ipa` build pipeline. Keep as-is. |
| **Windows Desktop UI** | `desktop/src/App.tsx` | **MOCKED (PoC 3 UI)** | Replace mock state with real Tauri IPC listeners, transfer progress list, drag-and-drop dropzone, and system tray integration. |
| **Windows Tauri Backend**| `desktop/src-tauri/src/main.rs` | **MOCKED (Scaffold)** | Replace dummy Tauri commands with modular Rust engine (`network/`, `security/`, `transfer/`, `clipboard/`, `filesystem/`). |
| **Windows Rust Cargo** | `desktop/src-tauri/Cargo.toml` | **CONFIGURED** | Add Win32 clipboard support (`clipboard-master` / `arboard`) and `image` decoding crate. |

---

## 3. Key Architecture Alignment & Refactoring Strategy

### Windows Host Modular Structure (`desktop/src-tauri/src/`):
```text
src-tauri/src/
├── main.rs                   <-- Tauri Builder, State & Command Registries
├── commands/                 <-- Tauri IPC Handlers (pairing, transfer, clipboard)
│   ├── pairing.rs
│   ├── transfer.rs
│   └── clipboard.rs
├── network/                  <-- Networking Engine
│   ├── discovery.rs          <-- mdns-sd Advertiser (_bridge._tcp.local)
│   ├── listener.rs           <-- Tokio TCP Socket Server (Port 44321)
│   └── protocol.rs           <-- 64 KB Binary Frame Encoder/Decoder
├── security/                 <-- Cryptography & Identity Store
│   ├── identity.rs           <-- Persistent Device Identity & Win Credential Store
│   └── cipher.rs             <-- Curve25519 ECDH + AES-256-GCM Session Cipher
├── transfer/                 <-- Resumable File & Photo Transfer Manager
│   ├── manager.rs            <-- Transfer Queue & Progress Emitter
│   ├── chunker.rs            <-- 64 KB Sequential Disk Streaming
│   ├── resume.rs             <-- .bridge.tmp Checkpoint Resume Engine
│   └── integrity.rs          <-- SHA-256 Verification & Path Sanitizer
└── clipboard/
    └── win_clipboard.rs      <-- Win32 OS Clipboard Hook & DShow/PNG Image Writer
```

### iOS Companion App Modular Structure (`ios/BridgeCompanion/`):
```text
BridgeCompanion/
├── App/                      <-- BridgeApp.swift
├── AppIntents/               <-- BridgeAppIntent.swift (Siri Shortcut / Action Button)
├── Networking/               <-- NetworkManager.swift (NWBrowser & NWConnection)
├── Security/                 <-- CryptoHelper.swift (CryptoKit & Keychain)
├── Transfers/                <-- TransferManager.swift (64 KB Chunk Streaming & Resume)
├── Photos/                   <-- PhotoManager.swift (PhotosPicker & Original/JPEG Transcode)
├── Pairing/                  <-- PairingQRScannerView.swift
└── Views/                    <-- MainView.swift & Component Views
```

---

## 4. Phase 1 MVP Feature Map & Implementation Order

```
[ Milestone 1: Core Architecture & Package Setup ]
       │
       ▼
[ Milestone 2: mDNS Discovery, QR Pairing & State Machine ]
       │
       ▼
[ Milestone 3: Explicit Clipboard (Text Push, Notification, Share Sheet, App Intent) ]
       │
       ▼
[ Milestone 4: Photo Transfer (PhotosPicker, Original/JPEG Mode, Progress Bar) ]
       │
       ▼
[ Milestone 5: Resumable File Transfer (64KB Chunking, SHA-256, Drag & Drop) ]
       │
       ▼
[ Milestone 6: iOS Share Sheet Extension Integration ]
       │
       ▼
[ Milestone 7: Signature Feature — Photo-to-Windows-Clipboard (Ctrl+V Instant Paste) ]
       │
       ▼
[ Milestone 8: Resumable Checkpoint Recovery & Offline Handling ]
       │
       ▼
[ Milestone 9: Desktop System Tray, Notifications & Human-Readable Error Strings ]
       │
       ▼
[ Milestone 10: End-to-End Testing & Phase 1 MVP Documentation ]
```

---

## 5. Non-Negotiable Security & Privacy Rules for Implementation
1. **Zero Secret Exposure:** No private keys, session tokens, or raw clipboard/file contents in source code or system logs.
2. **Path Traversal Shield:** All Windows destination paths strictly sanitized against `../`, `..\`, null bytes, and reserved characters. Files saved exclusively to `%USERPROFILE%\Downloads\Bridge\`.
3. **Transient RAM Processing:** Clipboard text and image conversions executed in volatile RAM without disk logging.
4. **Local Network Boundary:** 100% peer-to-peer over LAN. Loss of internet connection must never disrupt LAN operation.

---

> [!NOTE]
> **Audit Status:** Complete. Ready to execute Milestone 1 through Milestone 10 sequentially.
