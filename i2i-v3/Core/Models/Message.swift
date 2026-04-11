import Foundation

struct Message: Identifiable, Codable, Hashable {
    let id: UUID
    let conversationId: UUID  // Links message to a conversation (1:1 or group)
    let senderPeerId: UUID
    let receiverPeerId: UUID  // For 1:1 conversations; for groups, may be nil or group ID
    let timestamp: Date
    let body: String
    var status: Status

    enum Status: String, Codable {
        case pending
        case sent
        case received
    }
}
