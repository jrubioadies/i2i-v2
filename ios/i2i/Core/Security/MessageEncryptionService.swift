import CryptoKit
import Foundation

enum MessageEncryptionService {
    static func encrypt(_ plaintext: String, for peer: Peer) throws -> String {
        guard let peerPublicKey = peer.encryptionPublicKey else {
            throw EncryptionError.missingPeerEncryptionKey
        }

        let localPrivateKey = try KeyStore.loadEncryptionPrivateKey(tag: KeyStore.encryptionPrivateKeyTag)
        let remotePublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerPublicKey)
        let symmetricKey = try deriveSymmetricKey(localPrivateKey: localPrivateKey, remotePublicKey: remotePublicKey)
        let sealedBox = try ChaChaPoly.seal(Data(plaintext.utf8), using: symmetricKey)
        return sealedBox.combined.base64EncodedString()
    }

    static func decrypt(_ ciphertext: String, from senderDeviceId: UUID, peers: [Peer]) throws -> String {
        guard let peer = peers.first(where: { $0.id == senderDeviceId }),
              let peerPublicKey = peer.encryptionPublicKey else {
            throw EncryptionError.missingPeerEncryptionKey
        }

        let localPrivateKey = try KeyStore.loadEncryptionPrivateKey(tag: KeyStore.encryptionPrivateKeyTag)
        let remotePublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerPublicKey)
        let symmetricKey = try deriveSymmetricKey(localPrivateKey: localPrivateKey, remotePublicKey: remotePublicKey)

        guard let sealedData = Data(base64Encoded: ciphertext) else {
            throw EncryptionError.invalidCiphertext
        }

        let sealedBox = try ChaChaPoly.SealedBox(combined: sealedData)
        let decryptedData = try ChaChaPoly.open(sealedBox, using: symmetricKey)

        guard let plaintext = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.invalidPlaintext
        }

        return plaintext
    }

    private static func deriveSymmetricKey(
        localPrivateKey: Curve25519.KeyAgreement.PrivateKey,
        remotePublicKey: Curve25519.KeyAgreement.PublicKey
    ) throws -> SymmetricKey {
        let sharedSecret = try localPrivateKey.sharedSecretFromKeyAgreement(with: remotePublicKey)
        return sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data("i2i-relay-v1".utf8),
            sharedInfo: Data("message-body".utf8),
            outputByteCount: 32
        )
    }

    enum EncryptionError: Error, LocalizedError {
        case missingPeerEncryptionKey
        case invalidCiphertext
        case invalidPlaintext

        var errorDescription: String? {
            switch self {
            case .missingPeerEncryptionKey:
                return "Relay encryption key missing. Delete this peer and pair again using a freshly generated QR from the updated app."
            case .invalidCiphertext:
                return "The encrypted message is not valid."
            case .invalidPlaintext:
                return "The decrypted message could not be read."
            }
        }
    }
}
