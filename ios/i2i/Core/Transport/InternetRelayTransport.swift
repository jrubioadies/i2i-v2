import Foundation

final class InternetRelayTransport: NSObject, TransportProtocol {
    var onMessageReceived: ((Message) -> Void)?

    private let identityService: IdentityService
    private let peerRepository: any PeerRepository
    private var relayURL: URL
    private var webSocketTask: URLSessionWebSocketTask?
    private var isStarted = false
    private var shouldReconnect = false
    private var reconnectAttempts = 0
    private var connectedPeerIds = Set<String>()

    init(identityService: IdentityService, peerRepository: any PeerRepository, relayURL: URL) {
        self.identityService = identityService
        self.peerRepository = peerRepository
        self.relayURL = relayURL
        super.init()
    }

    func updateRelayURL(_ relayURL: URL) {
        guard relayURL != self.relayURL else { return }
        stop()
        self.relayURL = relayURL
    }

    func start() async throws {
        guard !isStarted else { return }
        guard let localIdentity = identityService.current else {
            throw InternetRelayError.identityNotLoaded
        }

        let task = URLSession.shared.webSocketTask(with: relayURL)
        webSocketTask = task
        isStarted = true
        shouldReconnect = true
        reconnectAttempts = 0
        task.resume()

        try await register(deviceId: localIdentity.deviceId)
        receiveNextMessage()
        print("[InternetRelayTransport] Connected to relay: \(relayURL.absoluteString)")
    }

    func stop() {
        shouldReconnect = false
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isStarted = false
        reconnectAttempts = 0
        connectedPeerIds.removeAll()
    }

    func send(_ message: Message, to peer: Peer) async throws {
        guard let webSocketTask else {
            throw InternetRelayError.notStarted
        }

        let envelope = RelayEnvelope(
            type: "message",
            messageId: message.id,
            senderDeviceId: message.senderPeerId,
            receiverDeviceId: message.receiverPeerId,
            timestamp: message.timestamp,
            body: try MessageEncryptionService.encrypt(message.body, for: peer),
            bodyEncoding: "chacha20poly1305-base64"
        )

        let data = try JSONEncoder().encode(envelope)
        guard let json = String(data: data, encoding: .utf8) else {
            throw InternetRelayError.encodingFailed
        }

        try await webSocketTask.send(.string(json))
        connectedPeerIds.insert(peer.id.uuidString)
        print("[InternetRelayTransport] Message sent via relay to \(peer.displayName)")
    }

    func getConnectedPeerIds() -> [String] {
        Array(connectedPeerIds)
    }

    private func register(deviceId: UUID) async throws {
        guard let webSocketTask else {
            throw InternetRelayError.notStarted
        }

        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let signingKey = try KeyStore.loadPrivateKey(tag: KeyStore.privateKeyTag)
        let signedPayload = registrationSigningPayload(deviceId: deviceId, timestamp: timestamp)
        let signature = try signingKey.signature(for: signedPayload)
        let registration = RelayRegistration(
            type: "register",
            deviceId: deviceId,
            publicKey: signingKey.publicKey.rawRepresentation,
            timestamp: timestamp,
            signature: signature
        )
        let data = try JSONEncoder().encode(registration)
        guard let json = String(data: data, encoding: .utf8) else {
            throw InternetRelayError.encodingFailed
        }

        try await webSocketTask.send(.string(json))
    }

    private func registrationSigningPayload(deviceId: UUID, timestamp: Int64) -> Data {
        Data("\(deviceId.uuidString)|\(timestamp)".utf8)
    }

    private func receiveNextMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let message):
                self.handle(message)
                self.receiveNextMessage()
            case .failure(let error):
                self.isStarted = false
                print("[InternetRelayTransport] Receive failed: \(error)")
                self.scheduleReconnect()
            }
        }
    }

    private func scheduleReconnect() {
        guard shouldReconnect else { return }
        reconnectAttempts += 1
        let delaySeconds = min(Double(reconnectAttempts * 2), 20)
        print("[InternetRelayTransport] Reconnecting in \(delaySeconds)s")

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delaySeconds) { [weak self] in
            guard let self, self.shouldReconnect else { return }

            Task {
                do {
                    self.isStarted = false
                    try await self.start()
                } catch {
                    self.isStarted = false
                    print("[InternetRelayTransport] Reconnect failed: \(error)")
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func handle(_ webSocketMessage: URLSessionWebSocketTask.Message) {
        guard case .string(let json) = webSocketMessage,
              let data = json.data(using: .utf8) else {
            return
        }

        if let envelope = try? JSONDecoder().decode(RelayEnvelope.self, from: data),
           envelope.type == "message" {
            connectedPeerIds.insert(envelope.senderDeviceId.uuidString)
            let plaintext: String
            do {
                plaintext = try MessageEncryptionService.decrypt(
                    envelope.body,
                    from: envelope.senderDeviceId,
                    peers: peerRepository.loadAll()
                )
            } catch {
                print("[InternetRelayTransport] Failed to decrypt relay message: \(error)")
                return
            }

            onMessageReceived?(
                Message(
                    id: envelope.messageId,
                    senderPeerId: envelope.senderDeviceId,
                    receiverPeerId: envelope.receiverDeviceId,
                    timestamp: envelope.timestamp,
                    body: plaintext,
                    status: .received
                )
            )
            return
        }

        if let receipt = try? JSONDecoder().decode(RelayDeliveryReceipt.self, from: data) {
            if receipt.status == "delivered_to_relay" || receipt.status == "queued_offline" {
                reconnectAttempts = 0
            }
            print("[InternetRelayTransport] Relay event: \(receipt.type) \(receipt.status ?? "")")
        }
    }

    enum InternetRelayError: Error {
        case identityNotLoaded
        case notStarted
        case encodingFailed
    }
}
