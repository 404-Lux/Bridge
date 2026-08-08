import Foundation

public enum ConnectionState: String, Equatable {
    case disconnected
    case discovering
    case connecting
    case authenticating
    case connected
    case reconnecting
    case networkUnavailable
    case pairingRequired
    case error
}
