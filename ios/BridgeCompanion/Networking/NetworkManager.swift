import Foundation
import Network
import Combine
import CryptoKit
import UIKit
import UserNotifications

public class NetworkManager: ObservableObject {
    public static let shared = NetworkManager()

    @Published public var state: ConnectionState = .disconnected
    @Published public var connectedDeviceName: String = ""
    @Published public var lastSentClipboard: String = ""
    @Published public var lastReceivedClipboard: String = ""
    @Published public var diagnosticLogs: [DiagnosticLog] = []

    private var pathMonitor: NWPathMonitor?
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var lastEndpoint: NWEndpoint?

    private var reconnectAttempt = 0
    private var isReconnecting = false
    private var ephemeralPrivateKey: Curve25519.KeyAgreement.PrivateKey?

    private init() {
        setupPathMonitor()
        requestNotificationPermission()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func setupPathMonitor() {
        pathMonitor = NWPathMonitor()
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    if self?.state == .networkUnavailable {
                        self?.logPrivacySafeEvent(action: "NETWORK_RESTORED", detail: "wifi_available")
                        self?.state = .disconnected
                        self?.triggerReconnection()
                    }
                } else {
                    self?.logPrivacySafeEvent(action: "NETWORK_LOST", detail: "interface_down")
                    self?.state = .networkUnavailable
                    self?.connection?.cancel()
                }
            }
        }
        let queue = DispatchQueue(label: "BridgePathQueue")
        pathMonitor?.start(queue: queue)
    }

    public func startDiscovery() {
        guard state != .connected && state != .authenticating else { return }

        state = .discovering
        logPrivacySafeEvent(action: "DISCOVERY_START", detail: "_bridge._tcp.local")

        let descriptor = NWBrowser.Descriptor.bonjour(type: "_bridge._tcp", domain: "local.")
        let parameters = NWParameters.tcp

        browser = NWBrowser(for: descriptor, using: parameters)
        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            if let firstResult = results.first {
                DispatchQueue.main.async {
                    self?.connect(to: firstResult.endpoint)
                }
            }
        }

        browser?.start(queue: .main)
    }

    public func connect(to endpoint: NWEndpoint) {
        self.lastEndpoint = endpoint
        state = isReconnecting ? .reconnecting : .connecting
        logPrivacySafeEvent(action: "CONNECT_INIT", detail: "tcp_socket")

        let parameters = NWParameters.tcp
        connection = NWConnection(to: endpoint, using: parameters)

        connection?.stateUpdateHandler = { [weak self] newState in
            DispatchQueue.main.async {
                switch newState {
                case .ready:
                    self?.state = .authenticating
                    self?.performSessionHandshake()
                case .failed(let error):
                    self?.handleFailure(reason: error.localizedDescription)
                case .cancelled:
                    self?.handleFailure(reason: "cancelled")
                default:
                    break
                }
            }
        }

        connection?.start(queue: .main)
    }

    private func performSessionHandshake() {
        let ephemKey = Curve25519.KeyAgreement.PrivateKey()
        self.ephemeralPrivateKey = ephemKey

        let handshakePayload: [String: Any] = [
            "type": "handshake_v2",
            "senderID": CryptoHelper.shared.deviceID,
            "senderIdentityPK": CryptoHelper.shared.persistentIdentityPublicKeyBase64,
            "senderEphemeralPK": ephemKey.publicKey.rawRepresentation.base64EncodedString()
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: handshakePayload) {
            sendRawFrame(jsonData)
        }

        startReceivingFrames()
    }

    /// Transmits text payload safely over encrypted session
    public func sendClipboardPayload(text: String) {
        guard state == .connected else { return }

        let payloadSize = text.utf8.count
        let payload: [String: Any] = [
            "type": "clipboard",
            "contentType": "text/plain",
            "content": text,
            "timestamp": Date().timeIntervalSince1970
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let encryptedData = CryptoHelper.shared.encryptFrame(data: jsonData) else { return }

        sendRawFrame(encryptedData)

        DispatchQueue.main.async {
            self.lastSentClipboard = text
            self.logPrivacySafeEvent(action: "CLIPBOARD_SENT", detail: "size=\(payloadSize)B | type=text/plain")
        }
    }

    private func sendRawFrame(_ data: Data) {
        var length = UInt32(data.count).bigEndian
        var frame = Data(bytes: &length, count: 4)
        frame.append(data)

        connection?.send(content: frame, completion: .contentProcessed({ _ in }))
    }

    private func startReceivingFrames() {
        connection?.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] lengthData, _, isComplete, error in
            guard let lengthData = lengthData, lengthData.count == 4 else {
                if isComplete || error != nil { self?.handleFailure(reason: "socket_closed") }
                return
            }

            let payloadLength = lengthData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            self?.connection?.receive(minimumIncompleteLength: Int(payloadLength), maximumLength: Int(payloadLength)) { payloadData, _, _, _ in
                if let payloadData = payloadData {
                    self?.handleIncomingPayload(payloadData)
                }
                self?.startReceivingFrames()
            }
        }
    }

    private func handleIncomingPayload(_ data: Data) {
        var processedData = data
        if state == .connected {
            guard let decrypted = CryptoHelper.shared.decryptFrame(combinedData: data) else {
                handleFailure(reason: "decryption_failed")
                return
            }
            processedData = decrypted
        }

        guard let json = try? JSONSerialization.jsonObject(with: processedData) as? [String: Any],
              let type = json["type"] as? String else { return }

        DispatchQueue.main.async {
            switch type {
            case "handshake_v2_ack":
                if let hostID = json["senderID"] as? String,
                   let hostIdentPK = json["senderIdentityPK"] as? String,
                   let hostEphemPK = json["senderEphemeralPK"] as? String,
                   let ephemKey = self.ephemeralPrivateKey {

                    _ = CryptoHelper.shared.establishSession(
                        ephemeralPrivateKey: ephemKey,
                        remoteEphemeralPublicKeyBase64: hostEphemPK,
                        remoteIdentityPublicKeyBase64: hostIdentPK
                    )

                    self.connectedDeviceName = hostID
                    self.state = .connected
                    self.reconnectAttempt = 0
                    self.isReconnecting = false
                    self.logPrivacySafeEvent(action: "SESSION_ESTABLISHED", detail: "device=\(hostID)")
                }

            case "clipboard":
                if let content = json["content"] as? String {
                    let size = content.utf8.count
                    self.lastReceivedClipboard = content
                    self.logPrivacySafeEvent(action: "CLIPBOARD_RECEIVED", detail: "size=\(size)B | type=text/plain")

                    if UIApplication.shared.applicationState == .active {
                        UIPasteboard.general.string = content
                    } else {
                        self.triggerLocalNotification(contentPreview: content)
                    }
                }
            default:
                break
            }
        }
    }

    private func triggerLocalNotification(contentPreview: String) {
        let content = UNMutableNotificationContent()
        content.title = "Copied from Windows PC"
        content.body = contentPreview.count > 40 ? String(contentPreview.prefix(40)) + "..." : contentPreview
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func triggerReconnection() {
        guard lastEndpoint != nil && !isReconnecting else { return }
        isReconnecting = true
        reconnectAttempt += 1

        let delay = min(15.0, 1.0 * pow(1.5, Double(reconnectAttempt - 1)))
        state = .reconnecting
        logPrivacySafeEvent(action: "RECONNECT_RETRY", detail: "attempt=\(reconnectAttempt) | delay=\(delay)s")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            if let endpoint = self?.lastEndpoint {
                self?.connect(to: endpoint)
            }
        }
    }

    private func handleFailure(reason: String) {
        state = .disconnected
        logPrivacySafeEvent(action: "DISCONNECTED", detail: "reason=\(reason)")
        connection?.cancel()
        triggerReconnection()
    }

    private func logPrivacySafeEvent(action: String, detail: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())

        let log = DiagnosticLog(
            timestamp: timestamp,
            deviceID: CryptoHelper.shared.deviceID,
            stateTransition: action,
            reason: detail,
            attempt: reconnectAttempt,
            delay: "0s"
        )
        DispatchQueue.main.async {
            self.diagnosticLogs.insert(log, at: 0)
            if self.diagnosticLogs.count > 25 { self.diagnosticLogs.removeLast() }
        }
    }
}
