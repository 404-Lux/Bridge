# iOS Platform Boundaries & Reality Audit

## Categorization of iOS Capabilities

| Capability | Status | Platform Reality & Technical Boundary |
| :--- | :---: | :--- |
| **Foreground Pasteboard Write** | **SUPPORTED** | Immediate background update without prompt when app is active. |
| **Share Sheet Extension** | **SUPPORTED** | User selects item → Share → Bridge. Transfers data in background without opening app. |
| **Siri Shortcuts / App Intents** | **SUPPORTED** | Native iOS 16+ `AppIntent` triggered via Action Button or widget. |
| **Automatic Background Clipboard**| **NOT POSSIBLE** | **Apple strictly blocks background pasteboard reading.** App uses local push notification fallback. |
| **ReplayKit Screen Streaming** | **DEFERRED** | Hard **50 MB RAM ceiling** enforced by iOS kernel on Broadcast Extensions. |
| **Wireless Webcam** | **DEFERRED** | Windows Virtual Camera driver registration requires paid kernel signing certs ($99–$300/yr). |
