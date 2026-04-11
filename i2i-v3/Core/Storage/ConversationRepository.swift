import Foundation

protocol ConversationRepository {
    func loadAll() -> [Conversation]
    func load(id: UUID) -> Conversation?
    func save(_ conversation: Conversation) throws
    func delete(id: UUID) throws
    func loadOrCreateDirect(peerId: UUID) -> Conversation
}
