import Foundation

struct Conversation: Identifiable, Codable, Hashable {
    let id: UUID
    var type: ConversationType
    var displayName: String
    let peerId: UUID?  // For 1:1 conversations; nil for groups
    let groupId: UUID?  // For group conversations; nil for 1:1
    var lastMessageId: UUID?
    var lastMessageAt: Date?
    var unreadCount: Int = 0
    let createdAt: Date
    var updatedAt: Date

    enum ConversationType: String, Codable {
        case direct    // 1:1 conversation
        case group     // Group conversation (future)
    }

    // MARK: - Convenience

    /// For 1:1 conversations, returns the peer's display name
    /// For groups, returns the custom group name
    var title: String { displayName }
}
