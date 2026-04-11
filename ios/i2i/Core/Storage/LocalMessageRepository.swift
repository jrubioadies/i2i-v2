import Foundation

final class LocalMessageRepository: MessageRepository {
    private let fileURL: URL
    private let conversationRepository: ConversationRepository

    init(conversationRepository: ConversationRepository) {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
        fileURL = support.appendingPathComponent("messages.json")
        self.conversationRepository = conversationRepository
    }

    // Legacy: load messages for a peer pair, auto-creating conversation if needed
    func loadConversation(localPeerId: UUID, remotePeerId: UUID) -> [Message] {
        let conversation = conversationRepository.loadOrCreateDirect(peerId: remotePeerId)
        return loadConversation(conversationId: conversation.id)
    }

    // New: load messages by conversationId
    func loadConversation(conversationId: UUID) -> [Message] {
        loadAll()
            .filter { $0.conversationId == conversationId }
            .sorted { $0.timestamp < $1.timestamp }
    }

    func save(_ message: Message) throws {
        var messages = loadAll()
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index] = message
        } else {
            messages.append(message)
        }
        try write(messages)
    }

    private func loadAll() -> [Message] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([Message].self, from: data)) ?? []
    }

    private func write(_ messages: [Message]) throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(messages)
        try data.write(to: fileURL, options: .atomic)
    }
}
