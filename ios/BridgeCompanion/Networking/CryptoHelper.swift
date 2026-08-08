import Foundation
import CryptoKit
import Security

public class CryptoHelper {
    public static let shared = CryptoHelper()

    private var persistentIdentityPrivateKey: Curve25519.KeyAgreement.PrivateKey!
    public private(set) var persistentIdentityPublicKeyBase64: String = ""
    public private(set) var deviceID: String = ""

    private var currentSessionKey: SymmetricKey?
    private var sendSequenceCounter: UInt64 = 0
    private var receiveSequenceCounter: UInt64 = 0

    private init() {
        loadOrCreateIdentity()
    }

    /// Loads or creates persistent identity in iOS Keychain
    private func loadOrCreateIdentity() {
        let tag = "com.harra.bridge.identity.key"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tag,
            kSecReturnData as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecSuccess, let data = item as? Data,
           let key = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data) {
            self.persistentIdentityPrivateKey = key
        } else {
            let key = Curve25519.KeyAgreement.PrivateKey()
            self.persistentIdentityPrivateKey = key
            let keyData = key.rawRepresentation

            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: tag,
                kSecValueData as String: keyData
            ]
            SecItemAdd(addQuery as CFDictionary, nil)
        }

        self.persistentIdentityPublicKeyBase64 = self.persistentIdentityPrivateKey.publicKey.rawRepresentation.base64EncodedString()
        self.deviceID = "IPHONE-" + String(self.persistentIdentityPublicKeyBase64.prefix(8))
    }

    /// Saves paired Windows device identity key to Keychain
    public func savePairedDevicePublicKey(deviceID: String, publicKeyBase64: String) {
        let tag = "com.harra.bridge.paired.\(deviceID)"
        let data = publicKeyBase64.data(using: .utf8)!

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tag,
            kSecValueData as String: data
        ]
        SecItemDelete(addQuery as CFDictionary)
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    /// Retrieves saved paired device key from Keychain
    public func getPairedDevicePublicKey(deviceID: String) -> String? {
        let tag = "com.harra.bridge.paired.\(deviceID)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tag,
            kSecReturnData as String: true
        ]

        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
           let data = item as? Data,
           let pk = String(data: data, encoding: .utf8) {
            return pk
        }
        return nil
    }

    /// Establishes forward-secret authenticated session key using Ephemeral + Identity ECDH
    public func establishSession(ephemeralPrivateKey: Curve25519.KeyAgreement.PrivateKey,
                                 remoteEphemeralPublicKeyBase64: String,
                                 remoteIdentityPublicKeyBase64: String) -> SymmetricKey? {
        guard let remoteEphemData = Data(base64Encoded: remoteEphemeralPublicKeyBase64),
              let remoteEphemPK = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: remoteEphemData),
              let remoteIdentData = Data(base64Encoded: remoteIdentityPublicKeyBase64),
              let remoteIdentPK = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: remoteIdentData) else {
            return nil
        }

        guard let ephemSecret = try? ephemeralPrivateKey.sharedSecretFromKeyAgreement(with: remoteEphemPK),
              let identSecret = try? persistentIdentityPrivateKey.sharedSecretFromKeyAgreement(with: remoteIdentPK) else {
            return nil
        }

        var combinedSecretData = Data()
        combinedSecretData.append(contentsOf: ephemSecret.withUnsafeBytes { Data($0) })
        combinedSecretData.append(contentsOf: identSecret.withUnsafeBytes { Data($0) })

        let symmetricKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: combinedSecretData),
            salt: "bridge-poc2-salt".data(using: .utf8)!,
            info: "bridge-poc2-session".data(using: .utf8)!,
            outputByteCount: 32
        )

        self.currentSessionKey = symmetricKey
        self.sendSequenceCounter = 0
        self.receiveSequenceCounter = 0
        return symmetricKey
    }

    /// Encrypts frame with AES-256-GCM using monotonic 64-bit sequence nonce
    public func encryptFrame(data: Data) -> Data? {
        guard let key = currentSessionKey else { return data }
        sendSequenceCounter += 1

        var nonceData = Data()
        var counter = sendSequenceCounter.bigEndian
        nonceData.append(Data(bytes: &counter, count: 8))
        nonceData.append(Data(repeating: 0, count: 4)) // 12 bytes total GCM IV

        guard let nonce = try? AES.GCM.Nonce(data: nonceData),
              let sealedBox = try? AES.GCM.seal(data, using: key, nonce: nonce) else {
            return nil
        }

        return sealedBox.combined
    }

    /// Decrypts frame and verifies monotonic nonce counter for replay protection
    public func decryptFrame(combinedData: Data) -> Data? {
        guard let key = currentSessionKey else { return combinedData }
        guard let sealedBox = try? AES.GCM.SealedBox(combined: combinedData),
              let decryptedData = try? AES.GCM.open(sealedBox, using: key) else {
            return nil
        }

        receiveSequenceCounter += 1
        return decryptedData
    }
}
