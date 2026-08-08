import Foundation

public struct DiagnosticLog: Identifiable {
    public let id: UUID
    public let timestamp: String
    public let deviceID: String
    public let stateTransition: String
    public let reason: String
    public let attempt: Int
    public let delay: String

    public init(
        id: UUID = UUID(),
        timestamp: String,
        deviceID: String,
        stateTransition: String,
        reason: String,
        attempt: Int,
        delay: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.deviceID = deviceID
        self.stateTransition = stateTransition
        self.reason = reason
        self.attempt = attempt
        self.delay = delay
    }
}
