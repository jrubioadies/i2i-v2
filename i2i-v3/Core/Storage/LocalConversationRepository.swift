import Foundation

final class LocalConversationRepository: ConversationRepository {
    private let fileURL: URL
    private let peerRepository: PeerRepository

    init(peerRepository: PeerRepository) {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
        fileURL = support.appendingPathComponent("conversations.json")
        self.peerRepository = peerRepository
    }

    func loadAll() -> [Conversation] {
        let conversations = loadAllFromDisk()
        return conversations.sorted { $0.updatedAt > $1.updatedAt }
    }

    func load(id: UUID) -> Conversation? {
        loadAllFromDisk().first { $0.id == id }
    }

    func save(_ conversation: Conversation) throws {
        var conversations = loadAllFromDisk()
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = conversation
        } else {
            conversations.append(conversation)
        }
        try write(conversations)
    }

    func delete(id: UUID) throws {
        var conversations = loadAllFromDisk()
        conversations.removeAll { $0.id == id }
        try write(conversations)
    }

    func loadOrCreateDirect(peerId: UUID) -> Conversation {
        // Check if a direct conversation already exists with this peer
        if let existing = loadAllFromDisk().first(where: { conv in
            conv.type == .direct && conv.peerId == peerId
        }) {
            return existing
        }

        // Create new conversation
        let peer = peerRepository.load(id: peerId)
        let now = Date()
        let conversation = Conversation(
            id: UUID(),
            type: .direct,
            displayName: peer?.displayName ?? "Unknown",
            peerId: peerId,
            groupId: nil,
            lastMessageId: nil,
            lastMessageAt: nil,
            unreadCount: 0,
            createdAt: now,
            updatedAt: now
        )

        try? save(conversation)
        return conversation
    }

    // MARK: - Private

    private func loadAllFromDisk() -> [Conversation] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([Conversation].self, from: data)) ?? []
    }

    private func write(_ conversations: [Conversation]) throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(conversations)
        try data.write(to: fileURL, options: .atomic)
    }
}
