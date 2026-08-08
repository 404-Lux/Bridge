import Foundation
import AppIntents
import UIKit

@available(iOS 16.0, *)
struct SendClipboardIntent: AppIntent {
    static var title: LocalizedStringResource = "Send Clipboard to Windows PC"
    static var description = IntentDescription("Sends your current iPhone clipboard to your paired Windows PC via Bridge.")

    func perform() async throws -> some IntentResult {
        if let currentClipboard = await MainActor.run(body: { UIPasteboard.general.string }),
           !currentClipboard.isEmpty {
            NetworkManager.shared.sendClipboardPayload(text: currentClipboard)
            return .result()
        }
        return .result()
    }
}
