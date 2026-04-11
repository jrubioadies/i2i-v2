import Foundation

struct RelayEnvelope: Codable {
    let type: String
    let messageId: UUID
    let senderDeviceId: UUID
    let receiverDeviceId: UUID
    let timestamp: Date
    let body: String
    let bodyEncoding: String
}

struct RelayRegistration: Codable {
    let type: String
    let deviceId: UUID
    let publicKey: Data
    let timestamp: Int64
    let signature: Data
}

struct RelayDeliveryReceipt: Codable {
    let type: String
    let messageId: UUID?
    let status: String?
    let receiverDeviceId: UUID?
}
