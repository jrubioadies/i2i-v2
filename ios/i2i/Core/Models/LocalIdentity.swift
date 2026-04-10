import Foundation

struct LocalIdentity: Codable {
    let deviceId: UUID
    var displayName: String
    let createdAt: Date
    let publicKey: Data
    var encryptionPublicKey: Data?
    // privateKey lives in Keychain only – never stored here
}
