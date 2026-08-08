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
                        self?.state = .disconnected
                    }
                } else {
                    self?.state = .networkUnavailable
                }
            }
        }
        pathMonitor?.start(queue: DispatchQueue.global(qos: .utility))
    }

    public func startDiscovery() {
        guard state != .connected && state != .authenticating else { return }

        state = .discovering
        let parameters = NWParameters.tcp
        browser = NWBrowser(for: .bonjour(type: "_bridge._tcp", domain: "local."), using: parameters)

        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            if let result = results.first {
                self?.connect(to: result.endpoint)
            }
        }

        browser?.start(queue: DispatchQueue.global(qos: .utility))
    }

    public func connect(to endpoint: NWEndpoint) {
        lastEndpoint = endpoint
        state = isReconnecting ? .reconnecting : .connecting

        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveIdle = 5

        let parameters = NWParameters(tls: nil, tcp: tcpOptions)
        connection = NWConnection(to: endpoint, using: parameters)

        connection?.stateUpdateHandler = { [weak self] newState in
            DispatchQueue.main.async {
                switch newState {
                case .ready:
                    self?.state = .authenticating
                    self?.performECDHHandshake()
                case .failed(let error):
                    self?.handleFailure(reason: error.localizedDescription)
                case .cancelled:
                    self?.state = .disconnected
                default:
                    break
                }
            }
        }

        connection?.start(queue: DispatchQueue.global(qos: .utility))
    }

    private func performECDHHandshake() {
        ephemeralPrivateKey = Curve25519.KeyAgreement.PrivateKey()
        guard let pubKeyData = ephemeralPrivateKey?.publicKey.rawRepresentation else { return }

        var packet = Data([0x01]) // Handshake Init
        packet.append(pubKeyData)

        sendData(packet)
        receiveHandshakeResponse()
    }

    private func receiveHandshakeResponse() {
        connection?.receive(minimumIncompleteLength: 33, maximumLength: 33) { [weak self] data, _, isComplete, error in
            guard let self = self, let data = data, data.count == 33, data[0] == 0x02 else {
                self?.handleFailure(reason: "Handshake failed")
                return
            }

            let serverPubKeyData = data.subdata(in: 1..<33)
            do {
                let serverPubKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: serverPubKeyData)
                if let ephemeralPrivateKey = self.ephemeralPrivateKey {
                    let sharedSecret = try ephemeralPrivateKey.sharedSecretFromKeyAgreement(with: serverPubKey)
                    let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
                        using: SHA256.self,
                        salt: "BridgeHandshakeSalt".data(using: .utf8)!,
                        sharedInfo: Data(),
                        outputByteCount: 32
                    )
                    CryptoHelper.shared.setSymmetricKey(symmetricKey)
                    DispatchQueue.main.async {
                        self.state = .connected
                        self.reconnectAttempt = 0
                        self.isReconnecting = false
                        self.logPrivacySafeEvent(action: "CONNECTED", detail: "Session established")
                        self.startListening()
                    }
                }
            } catch {
                self.handleFailure(reason: "Crypto Error: \(error.localizedDescription)")
            }
        }
    }

    private func startListening() {
        connection?.receive(minimumIncompleteLength: 4, maximumLength: 10 * 1024 * 1024) { [weak self] data, _, isComplete, error in
            guard let self = self, let data = data, error == nil else {
                self?.handleFailure(reason: "Connection lost")
                return
            }

            self.handleIncomingPacket(data)
            if self.state == .connected {
                self.startListening()
            }
        }
    }

    private func handleIncomingPacket(_ data: Data) {
        guard data.count > 1 else { return }
        let packetType = data[0]
        let payload = data.subdata(in: 1..<data.count)

        switch packetType {
        case 0x03: // Clipboard Payload
            if let decrypted = CryptoHelper.shared.decrypt(payload),
               let text = String(data: decrypted, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.lastReceivedClipboard = text
                    UIPasteboard.general.string = text
                    self.sendLocalNotification(title: "Clipboard Synced", body: text)
                }
            }
        default:
            break
        }
    }

    public func sendClipboard(_ text: String) {
        guard state == .connected else { return }
        guard let textData = text.data(using: .utf8),
              let encrypted = CryptoHelper.shared.encrypt(textData) else { return }

        var packet = Data([0x03])
        packet.append(encrypted)
        sendData(packet)
        lastSentClipboard = text
    }

    public func sendPhotoData(_ imageData: Data) {
        guard state == .connected else { return }
        guard let encrypted = CryptoHelper.shared.encrypt(imageData) else { return }

        var packet = Data([0x04]) // Photo Payload
        packet.append(encrypted)
        sendData(packet)
    }

    private func sendData(_ data: Data) {
        connection?.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error = error {
                self?.handleFailure(reason: "Send Error: \(error.localizedDescription)")
            }
        })
    }

    private func sendLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private func triggerReconnection() {
        guard !isReconnecting else { return }
        isReconnecting = true
        reconnectAttempt += 1

        let delay = min(pow(2.0, Double(reconnectAttempt)), 30.0)
        logPrivacySafeEvent(action: "RECONNECTING", detail: "Attempt \(reconnectAttempt) in \(Int(delay))s")

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
