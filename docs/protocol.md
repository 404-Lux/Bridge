# Bridge Binary Protocol Specification

## Frame Header (Binary Envelope)

Every packet sent over TCP uses a 64 KB chunk binary framing structure:

```text
┌────────────────────────┬───────────────────┬──────────────────────┬───────────────────────────────┐
│ 4 Bytes: Frame Length  │ 1 Byte: Type ID   │ 12 Bytes: GCM Nonce  │ Payload Ciphertext + 16B Tag  │
└────────────────────────┴───────────────────┴──────────────────────┴───────────────────────────────┘
```

## Frame Types

| Type ID | Name | Description |
| :--- | :--- | :--- |
| `0x01` | `TransferHeader` | Metadata frame (`transferID`, `filename`, `totalSize`, `sha256`, `totalChunks`, `isPhotoClipboard`) |
| `0x02` | `ChunkData` | 64 KB binary data frame + 64-bit monotonic chunk index |
| `0x03` | `ChunkAck` | Receiver acknowledgment frame (`transferID`, `receivedChunkIndex`) |
| `0x04` | `TransferCancel` | Cancellation frame (`transferID`, `reason`) |
| `0x05` | `ClipboardText` | Plaintext clipboard frame |
