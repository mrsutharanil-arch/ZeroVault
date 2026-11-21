# ZeroVault 🛡️
### Sovereign Owner-Only Encrypted File Fortress for iOS

[![Build & Package ZeroVault](https://github.com/mrsutharanil-arch/ZeroVault/actions/workflows/ios-build.yml/badge.svg)](https://github.com/mrsutharanil-arch/ZeroVault/actions/workflows/ios-build.yml)

A hyper-secure, single-purpose iOS mobile application engineered with zero-compromise privacy principles: **one job only — to keep confidential files cryptographically sealed, viewable exclusively by the owner, with zero backups, full hardware encryption, and complete isolation from all file managers and photo galleries.**

---

## 🎯 Direct Alignment with Security Requirements

| User Requirement | Engineering Implementation in ZeroVault |
| :--- | :--- |
| **"Only one work: secure files"** | Dedicated, single-purpose architecture. No bloated social features, no cloud sync, no public gallery indexing. |
| **"Only view by owner"** | **Face ID / Touch ID** via `LocalAuthentication` (`LAContext`), hardware-bound Master PIN with PBKDF2/SHA-256 hashing. |
| **"No access to anyone else"** | • **App Switcher Privacy Curtain**: Obscures screen in multitasking view.<br>• **Screen Recording Blocker**: Detects active recording or casting.<br>• **Immediate Auto-Lock**: Wipes RAM keys the instant app is exited.<br>• **Anti-Shoulder Surfing**: Scrambled keypad layout shuffles 0–9 digits. |
| **"No backup"** | • Sets `NSURLIsExcludedFromBackupKey = true` recursively on container & every file.<br>• Disabled iCloud backup & iTunes/Finder USB backup.<br>• Air-gapped: zero network permissions, zero cloud entitlements. |
| **"Full encrypted all files"** | • **Apple CryptoKit AES-256-GCM** hardware-accelerated cipher.<br>• Unique 96-bit cryptographic nonce and 128-bit authentication tag per file.<br>• Metadata (filenames, types, sizes) encrypted inside the envelope.<br>• Master keys anchored in **iOS Secure Enclave** (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`). |
| **"No show any file manager"** | • `UIFileSharingEnabled = false` (Blocks iTunes & Finder file browsing).<br>• `LSSupportsOpeningDocumentsInPlace = false` (Blocks iOS Files app).<br>• Stored in `Application Support/.ZeroVaultStorage/` as raw UUID blobs (`.zenc`). |
| **"No show in photos"** | • **Direct In-Memory Camera**: Captures photos/videos straight to RAM using `AVFoundation`, encrypts instantly, and completely bypasses `PHPhotoLibrary` & Camera Roll. |
| **"In-Memory Decryption"** | Cleartext is **never saved to disk or temp directories**. Decrypted in RAM buffers on demand, and immediately zeroized with `secureWipe()` upon exit. |

---

## 🏗️ Architecture & Project Structure

```
ZeroVault/
├── ZeroVault.xcodeproj/
│   ├── project.pbxproj                     # Standard Xcode project file (compiles in Xcode)
│   └── xcshareddata/
│       └── xcschemes/
│           └── ZeroVault.xcscheme           # Shared build scheme for Xcode & CI/CD
├── ZeroVault/
│   ├── App/
│   │   ├── ZeroVaultApp.swift              # SwiftUI @main entrypoint & scenePhase auto-lock
│   │   ├── AppState.swift                  # Global security state & screen capture detection
│   │   └── Info.plist                      # Strict lockdown: UIFileSharingEnabled=false, No Files App
│   ├── Models/
│   │   ├── VaultFile.swift                 # In-memory file model (title, size, category, icon)
│   │   ├── VaultCategory.swift             # Filter categories (Photos, Docs, Notes, Audio)
│   │   ├── VaultSecuritySettings.swift     # Auto-lock policies, biometrics, scramble keypad
│   │   └── EncryptedEnvelope.swift         # AES-256-GCM binary container (Magic, Nonce, Tag, AAD)
│   ├── Services/
│   │   ├── CryptographyService.swift       # Apple CryptoKit AES-GCM engine & RAM secure zeroization
│   │   ├── KeychainService.swift           # Hardware-bound Keychain storage (ThisDeviceOnly)
│   │   ├── StorageSecurityService.swift    # No-backup flags, sandbox isolation & 3-pass file shredder
│   │   ├── AuthenticationService.swift     # Face ID biometrics, PIN verification & lockout timers
│   │   └── SecureCameraService.swift       # AVFoundation direct-to-RAM camera (zero Camera Roll traces)
│   ├── ViewModels/
│   │   ├── VaultViewModel.swift            # Encrypted item indexing, import, search, and shredding
│   │   ├── AuthViewModel.swift             # Lock screen controller & scrambled keypad logic
│   │   └── SecureViewerViewModel.swift     # In-memory decryptor & memory-wipe lifecycle
│   ├── Views/
│   │   ├── Auth/
│   │   │   └── LockScreenView.swift        # High-tech lock screen, biometric trigger & scrambled PIN pad
│   │   ├── Vault/
│   │   │   ├── VaultHomeView.swift         # Sovereign vault dashboard, storage metrics, category chips
│   │   │   ├── VaultFileRow.swift          # File list item with encrypted size and shred button
│   │   │   ├── AddFileMenuSheet.swift      # Import sheet (Camera, Files, Secret Notes)
│   │   │   └── StorageSecurityAuditSheet.swift # Live verification of No-Backup & Files App isolation
│   │   ├── Camera/
│   │   │   └── SecureCameraView.swift      # In-app camera capturing directly to encrypted RAM
│   │   ├── Viewer/
│   │   │   ├── SecureFileViewerContainer.swift # In-memory viewer router with automatic RAM purge
│   │   │   ├── SecureImageViewer.swift     # Zoomable RAM image
│   │   │   ├── SecurePDFViewer.swift       # RAM PDFKit document viewer
│   │   │   └── SecureTextViewer.swift      # Monospaced confidential text/note viewer
│   │   ├── Components/
│   │   │   ├── SecureOverlayShield.swift   # App Switcher & Screen Recording blackout shield
│   │   │   └── SecurityBadge.swift         # Cybersecurity status badge
│   │   └── Settings/
│   │       └── SecuritySettingsView.swift  # Auto-lock timeout, decoy PIN, panic wipe
│   └── Resources/
│       └── Assets.xcassets/                # App icon & assets
├── .github/
│   └── workflows/
│       └── ios-build.yml                   # Automated GitHub Actions workflow to build native ARM64 IPA
├── project.yml                             # XcodeGen specification
├── Package.swift                           # Swift Package Manager manifest
├── build.sh                                # One-click macOS build script
├── package_ipa.sh                          # One-click native ARM64 IPA packaging script
├── codemagic.yaml                          # Cloud CI/CD configuration
├── preview.html                            # Interactive browser simulator (iPhone 15 Pro titanium frame)
└── mobile.html                             # Mobile-responsive web simulator for on-device testing
```

---

## 🔒 Cryptographic Container Specification

Every file stored by ZeroVault is sealed in an authenticated binary envelope:

```
+----------------------------------------------------------------------------------+
|  MAGIC BYTES   | VER |    NONCE    |     TAG     | META_LEN |  ENC METADATA  |  ENC PAYLOAD  |
| "ZERO" (4 B)   | 1 B |  (12 Bytes) |  (16 Bytes) | (4 Bytes)|    (AES-GCM)   |   (AES-GCM)   |
+----------------------------------------------------------------------------------+
```

1. **Magic Bytes & Version**: `0x5A45524F` (`ZERO`) + version `0x01`.
2. **Cryptographic Nonce**: 96-bit unique cryptographically secure random nonce generated per file via `AES.GCM.Nonce()`.
3. **Authentication Tag**: 128-bit Galois Message Authentication Code tag verifying data authenticity and detecting any bit flipping or tampering.
4. **Encrypted Metadata**: The original filename, size, MIME type, and creation date are encrypted inside the envelope; an attacker inspecting raw flash memory sees only random UUIDs (e.g., `8F12B4...zenc`).
5. **Decryption Policy**: Purely in RAM. Decrypted cleartext never touches temporary disk files (`/tmp` or `Caches`).

---

## ⚡ Multi-Pass Secure File Shredder

When the owner deletes a file from ZeroVault, it does not perform a simple unlinking. It executes a **3-Pass Forensic Shred**:
1. **Pass 1**: Overwrites the physical disk blocks with cryptographically secure random noise (`SecRandomCopyBytes`).
2. **Pass 2**: Overwrites the physical disk blocks with zeroes (`0x00`).
3. **Pass 3**: Flushes file handles atomically and unlinks the inode from the file system.

---

## 🚀 Building & Installing ZeroVault

### Method 1: Automated GitHub Actions Build (Recommended)
1. Push this repository to GitHub.
2. The included `.github/workflows/ios-build.yml` will automatically build the native ARM64 `.ipa` package using Apple's macOS runners.
3. Download `ZeroVault.ipa` from the GitHub Actions Artifacts tab.

### Method 2: Local Build via macOS & Xcode
```bash
# Clone the repository
cd F:/ios/ZeroVault

# Build the Xcode project
chmod +x ./build.sh
./build.sh

# Package into installable ZeroVault.ipa
chmod +x ./package_ipa.sh
./package_ipa.sh
```

### Method 3: Sideloading to iPhone
Once you have `ZeroVault.ipa`, install it on your iPhone using any of the following tools:
* **AltStore / AltServer**: Free sideloading using your free Apple ID.
* **Sideloadly**: Fast drag-and-drop IPA installer for macOS and Windows.
* **TrollStore**: Permanent sideloading for supported iOS versions.
* **Apple Configurator / Xcode Devices**: Connect iPhone via cable and drag `ZeroVault.app` to Installed Apps.

---

## 🌐 Instant Interactive Browser Preview

ZeroVault includes a **full interactive web simulator** so you can test the owner-only vault experience right now in any web browser without waiting for an Xcode build:

* **Desktop iPhone 15 Pro Frame**: Open [`preview.html`](file:///F:/ios/ZeroVault/preview.html) in your browser.
* **Mobile-Responsive Mode**: Open [`mobile.html`](file:///F:/ios/ZeroVault/mobile.html) directly on your smartphone browser.

### Key Features to Test in the Simulator:
* **PIN Authentication**: Master PIN is `123456`.
* **Stealth Decoy PIN**: Enter `000000` to enter the decoy empty vault.
* **Dynamic Scrambled Keypad**: Notice how digits 0–9 shuffle to prevent shoulder surfing.
* **Direct Secure Camera**: Takes direct snapshots to memory and encrypts them without touching public photos.
* **Security Audit Verification**: Click the shield badge to inspect live proof of `NSURLIsExcludedFromBackupKey = true` and `UIFileSharingEnabled = false`.
* **Privacy Shield**: Test the App Switcher blackout overlay.
