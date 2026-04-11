import Foundation
import Combine

@MainActor
final class MessagingViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var draft: String = ""
    @Published var peers: [Peer] = []
    @Published var conversations: [Conversation] = []
    @Published var selectedConversation: Conversation?
    @Published var connectedPeerIds: [String] = []
    @Published var deviceName: String = ""
    @Published var pendingDisplayName: String = ""
    @Published var errorMessage: String?
    
    var localDeviceId: UUID {
        identityService?.current?.deviceId ?? UUID()
    }

    var isSelectedConversationConnected: Bool {
        guard let conversation = selectedConversation, let peerId = conversation.peerId else { return false }
        return connectedPeerIds.contains(peerId.uuidString)
    }

    var canSend: Bool {
        guard selectedConversation != nil, !draft.isEmpty else { return false }
        if appEnvironment?.transportMode == .relay {
            return true
        }
        return isSelectedConversationConnected
    }

    private weak var identityService: IdentityService?
    private weak var peerRepository: (any PeerRepository)?
    private weak var messageRepository: (any MessageRepository)?
    private weak var conversationRepository: (any ConversationRepository)?
    private weak var transport: (any TransportProtocol)?
    private weak var appEnvironment: AppEnvironment?
    private var updateTimer: Timer?
    private var isInitialized = false

    init() {}

    func initialize(with env: AppEnvironment) {
        guard !isInitialized else {
            loadConversations()
            loadMessagesForSelectedConversation()
            updateConnectedPeers()
            return
        }
        isInitialized = true

        self.identityService = env.identityService
        self.peerRepository = env.peerRepository
        self.messageRepository = env.messageRepository
        self.conversationRepository = env.conversationRepository
        self.transport = env.activeTransport
        self.appEnvironment = env

        // Load device name
        if let name = env.identityService.current?.displayName {
            deviceName = name
            pendingDisplayName = name
        }

        // Set up message receiving
        bindMessageReceiver()

        Task {
            await env.startTransportIfNeeded()
            updateConnectedPeers()
        }

        loadConversations()
        loadMessagesForSelectedConversation()

        // Periodically update connected peer IDs
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateConnectedPeers()
            }
        }
        updateConnectedPeers()
    }
    
    func loadConversations() {
        guard let repository = conversationRepository else { return }
        let selectedConversationId = selectedConversation?.id
        conversations = repository.loadAll()

        if let selectedConversationId,
           let refreshedConversation = conversations.first(where: { $0.id == selectedConversationId }) {
            selectedConversation = refreshedConversation
        } else if selectedConversation == nil && !conversations.isEmpty {
            selectedConversation = conversations.first
        }
    }

    func loadPeers() {
        guard let repository = peerRepository else { return }
        peers = repository.loadAll()
    }

    func loadMessagesForSelectedConversation() {
        guard
            let repository = messageRepository,
            let conversation = selectedConversation
        else {
            messages = []
            return
        }

        messages = repository.loadConversation(conversationId: conversation.id)
    }

    // Legacy: for backwards compatibility
    func loadMessagesForSelectedPeer() {
        loadMessagesForSelectedConversation()
    }
    
    private func updateConnectedPeers() {
        let activeTransport = appEnvironment?.activeTransport ?? transport
        connectedPeerIds = activeTransport?.getConnectedPeerIds() ?? []
    }
    
    func selectConversation(_ conversation: Conversation) {
        selectedConversation = conversation
        loadMessagesForSelectedConversation()
    }

    // Legacy: for backwards compatibility
    func selectPeer(_ peer: Peer) {
        guard let conversation = conversations.first(where: { $0.peerId == peer.id }) else {
            return
        }
        selectConversation(conversation)
    }
    
    func disconnect() {
        appEnvironment?.stopTransport()
        connectedPeerIds = []
        print("Disconnected from chat")
    }

    func reconnect() {
        guard let appEnvironment else { return }
        transport = appEnvironment.activeTransport
        Task {
            await appEnvironment.startTransportIfNeeded()
            updateConnectedPeers()
        }
    }

    func transportModeDidChange() {
        guard let appEnvironment else { return }
        transport = appEnvironment.activeTransport
        bindMessageReceiver()
        connectedPeerIds = []

        Task {
            await appEnvironment.startTransportIfNeeded()
            updateConnectedPeers()
        }
    }

    func saveDeviceName() {
        do {
            try identityService?.updateDisplayName(pendingDisplayName)
            deviceName = pendingDisplayName
        } catch {
            print("Failed to save device name: \(error)")
        }
    }

    func sendTapped() {
        guard !draft.isEmpty, let conversation = selectedConversation, let peerId = conversation.peerId else { return }
        errorMessage = nil

        let message = Message(
            id: UUID(),
            conversationId: conversation.id,
            senderPeerId: localDeviceId,
            receiverPeerId: peerId,
            timestamp: Date(),
            body: draft,
            status: .pending
        )

        Task {
            do {
                guard let appEnvironment else { return }
                guard let peer = peerRepository?.load(id: peerId) else { return }

                await appEnvironment.startTransportIfNeeded()
                let activeTransport = appEnvironment.activeTransport
                transport = activeTransport
                try await activeTransport.send(message, to: peer)
                var sentMessage = message
                sentMessage.status = .sent
                try messageRepository?.save(sentMessage)
                messages.append(sentMessage)
                draft = ""

                // Update conversation timestamp
                var updated = conversation
                updated.lastMessageAt = Date()
                updated.updatedAt = Date()
                try conversationRepository?.save(updated)
            } catch {
                errorMessage = error.localizedDescription
                print("Failed to send message: \(error)")
            }
        }
    }

    private func handleReceivedMessage(_ message: Message) {
        do {
            try messageRepository?.save(message)
        } catch {
            print("Failed to persist received message: \(error)")
        }

        // Ensure conversation exists and update its metadata
        if let conversation = conversationRepository?.load(id: message.conversationId) {
            var updated = conversation
            updated.lastMessageAt = Date()
            updated.updatedAt = Date()
            try? conversationRepository?.save(updated)
        }

        // Only append to messages if it belongs to the currently selected conversation
        guard let conversation = selectedConversation else { return }
        if message.conversationId == conversation.id {
            messages.append(message)
        }
    }

    private func bindMessageReceiver() {
        appEnvironment?.onMessageReceived = { [weak self] message in
            Task { @MainActor in
                self?.handleReceivedMessage(message)
            }
        }
    }
    
    deinit {
        updateTimer?.invalidate()
    }
}
