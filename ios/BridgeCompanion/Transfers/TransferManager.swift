import Foundation
import CryptoKit
import Combine

public enum TransferState: String {
    case queued = "Queued"
    case transferring = "Transferring..."
    case verifying = "Verifying SHA-256..."
    case completed = "Completed"
    case failed = "Transfer Failed"
}

public struct FileTransferItem: Identifiable, Hashable {
    public let id: String
    public let filename: String
    public let totalSize: UInt64
    public var bytesTransferred: UInt64
    public var progressPct: Double
    public var state: TransferState
    public let isPhotoClipboard: Bool
}

public class TransferManager: ObservableObject {
    public static let shared = TransferManager()

    @Published public var activeTransfers: [FileTransferItem] = []
    private var tempFiles: [String: URL] = [:]

    private init() {}

    /// Creates a 64 KB chunk transfer header payload
    public func createTransferHeader(filename: String, fileSize: UInt64, isPhotoClipboard: Bool = false) -> [String: Any] {
        let transferID = "tx_" + UUID().uuidString.prefix(8)
        let totalChunks = (fileSize + 65535) / 65536

        return [
            "type": "transfer_header",
            "transferID": transferID,
            "filename": filename,
            "mimeType": "application/octet-stream",
            "totalSize": fileSize,
            "sha256": "",
            "chunkSize": 65536,
            "totalChunks": totalChunks,
            "isPhotoClipboard": isPhotoClipboard
        ]
    }

    /// Handles incoming binary chunk for an active transfer
    public func processIncomingChunk(transferID: String, filename: String, chunkIndex: UInt64, totalChunks: UInt64, chunkData: Data) -> Double {
        let tempDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Bridge/Temp", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let tempFileURL = tempDir.appendingPathComponent("\(transferID).bridge.tmp")

        if let fileHandle = try? FileHandle(forWritingTo: tempFileURL) {
            fileHandle.seek(toFileOffset: chunkIndex * 65536)
            fileHandle.write(chunkData)
            try? fileHandle.close()
        } else {
            FileManager.default.createFile(atPath: tempFileURL.path, contents: chunkData)
        }

        let progress = Double(chunkIndex + 1) / Double(totalChunks)

        DispatchQueue.main.async {
            if let index = self.activeTransfers.firstIndex(where: { $0.id == transferID }) {
                self.activeTransfers[index].bytesTransferred = (chunkIndex + 1) * 65536
                self.activeTransfers[index].progressPct = progress
                if progress >= 1.0 {
                    self.activeTransfers[index].state = .completed
                }
            } else {
                let item = FileTransferItem(
                    id: transferID,
                    filename: filename,
                    totalSize: totalChunks * 65536,
                    bytesTransferred: (chunkIndex + 1) * 65536,
                    progressPct: progress,
                    state: progress >= 1.0 ? .completed : .transferring,
                    isPhotoClipboard: false
                )
                self.activeTransfers.insert(item, at: 0)
            }
        }

        return progress
    }
}
