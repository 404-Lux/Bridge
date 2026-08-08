# Bridge Architecture Overview

## System Topography

```
┌───────────────────────────────────────────┐         ┌───────────────────────────────────────────┐
│               WINDOWS HOST                │         │              IPHONE CLIENT                │
│ ┌───────────────────────────────────────┐ │         │ ┌───────────────────────────────────────┐ │
│ │          Tauri 2 Frontend             │ │         │ │            SwiftUI App                │ │
│ │          (React + TS UI)              │ │         │ │      (Main UI & Settings)             │ │
│ └───────────────────┬───────────────────┘ │         │ └───────────────────┬───────────────────┘ │
│                     │ IPC                 │         │                     │ State               │
│ ┌───────────────────┴───────────────────┐ │ Local   │ ┌───────────────────┴───────────────────┐ │
│ │            Rust Core                  │ │ Wi-Fi   │ │        Swift Native Core              │ │
│ │  - mDNS Advertiser (mdns-sd)          │ │ Network │ │  - mDNS Browser (NWBrowser)             │ │
│ │  - Tokio TCP Server (Port 44321)      │ │◄───────►│ │  - TCP Client (NWConnection)            │ │
│ │  - Win32 Clipboard (arboard/image)    │ │ (AES-   │ │  - Share Sheet Extension Target        │ │
│ │  - Resumable Chunker (64 KB)          │ │ GCM)    │ │  - AppIntents (Siri Shortcuts)          │ │
│ └───────────────────────────────────────┘ │         │ └───────────────────────────────────────┘ │
└───────────────────────────────────────────┘         └───────────────────────────────────────────┘
```

## Core Principles
1. **Local-First Boundary:** All communication takes place strictly over the local Wi-Fi / LAN subnet.
2. **Zero Cloud:** No servers, no user accounts, no external databases.
3. **Transient Processing:** Clipboard content and transcoded images exist in volatile RAM memory during transport.
