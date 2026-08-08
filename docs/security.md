# Bridge Security & Privacy Model

## Cryptographic Specification
- **Key Agreement:** Curve25519 Elliptic-Curve Diffie-Hellman (ECDH) via Apple `CryptoKit` on iOS and `ring` on Rust.
- **Session Derivation:** HKDF-SHA256 deriving 256-bit symmetric session key (`bridge-session-salt`).
- **Authenticated Encryption:** AES-256-GCM authenticated encryption.
- **Replay Protection:** 64-bit monotonic sequence counter embedded in nonces. Replayed frames trigger socket teardown.

## Privacy Rules
1. **No Plaintext Logging:** Private keys, session secrets, and clipboard text are NEVER written to logs.
2. **Path Traversal Defense:** Filenames sanitized on Windows. Downloads saved strictly to `%USERPROFILE%\Downloads\Bridge\`.
