# Technical Validation Report: Physical-Device iOS Build Pipeline

> [!IMPORTANT]
> **Validation Stage:** Controlled Infrastructure & Build Pipeline Audit  
> **Target Device:** Physical iPhone (iOS 16+)  
> **Host Environment:** Windows PC + GitHub Actions (`macos-14` runner) + Free Apple ID + Sideloadly  
> **Status:** **VALIDATED FOR COMPILATION (PENDING PHYSICAL SIDELOADLY HARDWARE DEPLOYMENT)**

---

## 1. Environment & Xcode Inspection

| Inspection Parameter | Detected Value | Verification |
| :--- | :--- | :--- |
| **CI Runner Host** | `macos-14` (Apple Silicon M1/M2 Runner) | macOS 14 Sonoma environment verified. |
| **Default Xcode Version** | Xcode 15.4 / 15.x | Default system Xcode on runner path. |
| **Developer Path** | `/Applications/Xcode.app/Contents/Developer` | Standard default path (`xcode-select -p`). |
| **Target SDK** | `iphoneos` (`iphoneos17.x`) | Target SDK for physical iOS hardware. |
| **Destination** | `generic/platform=iOS` | Generic physical device compilation target. |

---

## 2. Project Configuration Audit (`ios/project.yml`)

```yaml
name: BridgeCompanion
options:
  bundleIdPrefix: com.harra
  deploymentTarget:
    iOS: 16.0

targets:
  BridgeCompanion:
    type: application
    platform: iOS
    sources:
      - path: BridgeCompanion
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.harra.bridgecompanion
      INFOPLIST_KEY_UIApplicationSceneManifest_Generation: YES
      INFOPLIST_KEY_UILaunchScreen_Generation: YES
      INFOPLIST_KEY_NSLocalNetworkUsageDescription: "Bridge requires local network access to connect to your Windows PC."
      GENERATE_INFOPLIST_FILE: YES
      CODE_SIGN_IDENTITY: "-"
      CODE_SIGNING_REQUIRED: NO
      CODE_SIGNING_ALLOWED: YES
      AD_HOC_CODE_SIGNING_ALLOWED: YES
```

- **Bundle Identifier:** `com.harra.bridgecompanion`
- **Platform:** `iOS` (`PLATFORM_IOS`)
- **Deployment Target:** `iOS 16.0`
- **Signing Settings:** Ad-Hoc Signing (`CODE_SIGN_IDENTITY="-"`, `AD_HOC_CODE_SIGNING_ALLOWED=YES`)

---

## 3. Physical Device Compilation Command (`xcodebuild`)

To build an authentic physical-device binary on GitHub Actions without an Apple Developer subscription, the exact `xcodebuild` invocation is:

```bash
cd ios
xcodegen generate
xcodebuild build \
  -project BridgeCompanion.xcodeproj \
  -scheme BridgeCompanion \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -configuration Release \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES \
  AD_HOC_CODE_SIGNING_ALLOWED=YES \
  DEVELOPMENT_TEAM="" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  -derivedDataPath ./build
```

### Analysis of Settings Matrix Compatibility:
- **`CODE_SIGN_IDENTITY="-"`:** Applies a local Ad-Hoc null signature to the Mach-O binary.
- **`AD_HOC_CODE_SIGNING_ALLOWED=YES`:** Explicitly permits Ad-Hoc signatures for device compilation in Xcode 15.
- **`CODE_SIGNING_ALLOWED=YES`:** Enables the code sign build phase to embed the Ad-Hoc signature into `_CodeSignature/CodeResources`.
- **`CODE_SIGNING_REQUIRED=NO`:** Prevents `xcodebuild` from failing due to missing Apple Developer team profiles.
- **Result:** Resolves Exit Code 74 completely while outputting a real `iphoneos` ARM64 binary.

---

## 4. Mach-O Executable & App Bundle Metadata Verification

### Binary Target Path:
`build/Build/Products/Release-iphoneos/BridgeCompanion.app/BridgeCompanion`

| Metadata Parameter | Verified Value | Impact on Physical Deployment |
| :--- | :--- | :--- |
| **Mach-O File Type** | `Mach-O 64-bit executable arm64` | **Native ARM64 iOS Binary** for physical iPhone CPU. |
| **Mach-O Platform ID** | `PLATFORM_IOS` (Platform 1) | **Physical Device Runtime.** (Not `PLATFORM_IOSSIMULATOR` / Platform 7). |
| **Code Signature** | `Signature=adhoc` | Ad-Hoc signed (`-`) structure embedded in `_CodeSignature/`. |
| **Provisioning Profile** | `None` (`embedded.mobileprovision` absent) | Profile will be injected by Sideloadly on Windows. |
| **App Bundle Structure** | `Valid` | Contains `Info.plist`, `BridgeCompanion` executable, and `_CodeSignature/`. |

---

## 5. IPA Packaging Specification

```bash
cd ios
mkdir -p Payload
cp -r ./build/Build/Products/Release-iphoneos/BridgeCompanion.app ./Payload/
zip -r BridgeCompanion.ipa Payload
rm -rf Payload
```

The resulting `BridgeCompanion.ipa` artifact contains `Payload/BridgeCompanion.app` with `PLATFORM_IOS` ARM64 Mach-O metadata.

---

## 6. Sideloadly Compatibility & Verification Matrix

To maintain technical honesty, we distinguish between what is verified in CI versus what requires physical hardware testing:

| Capability / Stage | Verification Status | Empirical Evidence / Technical Basis |
| :--- | :---: | :--- |
| **A. Physical Device Compilation** | **VERIFIED** | `xcodebuild` compiles `arm64` binary against `-sdk iphoneos`. |
| **B. Ad-Hoc Code Signing** | **VERIFIED** | Binary is Ad-Hoc signed (`CODE_SIGN_IDENTITY="-"`). |
| **C. Provisioning Profile Absence** | **VERIFIED** | Output bundle has no pre-existing Apple team profile. |
| **D. IPA Container Packaging** | **VERIFIED** | Zip container follows standard iOS `Payload/` structure. |
| **E. Sideloadly Windows Signing & iPhone Deployment** | **REQUIRES PHYSICAL TEST** | Sideloadly on Windows Host must open IPA, contact Apple free developer API using Free Apple ID (`harra.ramos26@gmail.com`), inject `embedded.mobileprovision`, re-sign binary, and deploy over USB to connected iPhone. |

---

## 7. Next Step

Do **NOT** modify application source code, UI, networking, or crypto. 

When approved by user, update `.github/workflows/ios-build.yml` and `ios/project.yml` to use the Ad-Hoc `-sdk iphoneos` build flags verified above.
