import Foundation
import Network

enum AppTab: Hashable {
    case identity
    case pairing
    case peers
    case messages
}

enum TransportMode: String, CaseIterable, Identifiable {
    case local
    case relay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .local: return "Local"
        case .relay: return "Relay"
        }
    }
}

/// Shared service container. Injected as @EnvironmentObject from i2iApp.
@MainActor
final class AppEnvironment: ObservableObject {
    private static let defaultRelayURLString = "wss://ws-relay-zi5u.onrender.com/ws"
    private static let relayURLDefaultsKey = "relayURLString"
    private static let transportModeDefaultsKey = "transportMode"

    let identityService: IdentityService
    let pairingService: PairingService
    let peerRepository: any PeerRepository
    let messageRepository: any MessageRepository
    let conversationRepository: any ConversationRepository
    let localTransport: MultipeerTransport
    let internetRelayTransport: InternetRelayTransport

    var activeTransport: any TransportProtocol {
        switch transportMode {
        case .local: return localTransport
        case .relay: return internetRelayTransport
        }
    }

    var onMessageReceived: ((Message) -> Void)?
    
    @Published var peerChangeCount = 0
    @Published var selectedTab: AppTab = .identity
    @Published var transportMode: TransportMode {
        didSet {
            guard oldValue != transportMode else { return }
            UserDefaults.standard.set(transportMode.rawValue, forKey: AppEnvironment.transportModeDefaultsKey)
            stopAllTransports()
            startActiveTransportWhenAvailable()
        }
    }
    @Published var relayURLString: String {
        didSet {
            relayURLString = AppEnvironment.normalizeRelayURLString(relayURLString)
            guard oldValue != relayURLString else { return }
            UserDefaults.standard.set(relayURLString, forKey: AppEnvironment.relayURLDefaultsKey)
            updateRelayURL()
        }
    }
    @Published private(set) var isInternetAvailable = true
    @Published private(set) var didBootstrap = false
    @Published private(set) var bootstrapError: String?
    private let pathMonitor = NWPathMonitor()
    private let pathMonitorQueue = DispatchQueue(label: "i2i.network-monitor")
    private var hasBootstrapped = false
    private var startedTransportMode: TransportMode?
    private var startingTransportMode: TransportMode?
    private var transportGeneration = 0

    init() {
        let identity = IdentityService()
        let peers = LocalPeerRepository()
        let conversations = LocalConversationRepository(peerRepository: peers)
        let messages = LocalMessageRepository(conversationRepository: conversations)
        let storedRelayURL = UserDefaults.standard.string(forKey: AppEnvironment.relayURLDefaultsKey)
        let relayURLString = Self.normalizeRelayURLString(storedRelayURL ?? AppEnvironment.defaultRelayURLString)
        let relayURL = URL(string: relayURLString) ?? URL(string: AppEnvironment.defaultRelayURLString)!
        let storedMode = UserDefaults.standard.string(forKey: AppEnvironment.transportModeDefaultsKey)
        let transportMode = storedMode.flatMap(TransportMode.init(rawValue:)) ?? .relay
        self.identityService = identity
        self.peerRepository = peers
        self.messageRepository = messages
        self.conversationRepository = conversations
        self.pairingService = PairingService(identityService: identity, peerRepository: peers)
        self.localTransport = MultipeerTransport(identityService: identity)
        self.internetRelayTransport = InternetRelayTransport(
            identityService: identity,
            peerRepository: peers,
            relayURL: relayURL
        )
        self.transportMode = transportMode
        self.relayURLString = relayURLString

        configureTransportCallbacks()
    }

    func bootstrap() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true

        do {
            try identityService.loadOrCreate()
            bootstrapError = nil
        } catch {
            bootstrapError = error.localizedDescription
            print("Failed to load or create identity: \(error)")
        }

        didBootstrap = true
        startNetworkMonitoring()
        startActiveTransportWhenAvailable()
    }

    func startTransportIfNeeded() async {
        let mode = transportMode
        let generation = transportGeneration
        guard startedTransportMode != mode, startingTransportMode != mode else { return }
        startingTransportMode = mode
        defer {
            if startingTransportMode == mode {
                startingTransportMode = nil
            }
        }

        do {
            let transport = transport(for: mode)
            try await transport.start()
            guard transportGeneration == generation, transportMode == mode else {
                transport.stop()
                return
            }
            startedTransportMode = mode
        } catch {
            print("Failed to start transport: \(error)")
            return
        }
    }

    func stopTransport() {
        transportGeneration += 1
        activeTransport.stop()
        startedTransportMode = nil
        startingTransportMode = nil
    }
    
    func notifyPeerChanged() {
        peerChangeCount += 1
    }

    private func stopAllTransports() {
        transportGeneration += 1
        localTransport.stop()
        internetRelayTransport.stop()
        startedTransportMode = nil
        startingTransportMode = nil
    }

    private func transport(for mode: TransportMode) -> any TransportProtocol {
        switch mode {
        case .local: return localTransport
        case .relay: return internetRelayTransport
        }
    }

    private func updateRelayURL() {
        guard let relayURL = URL(string: relayURLString) else {
            print("Invalid relay URL: \(relayURLString)")
            return
        }

        transportGeneration += 1
        internetRelayTransport.updateRelayURL(relayURL)
        if transportMode == .relay {
            startedTransportMode = nil
            startingTransportMode = nil
        }
        startActiveTransportWhenAvailable()
    }

    private static func normalizeRelayURLString(_ rawURLString: String) -> String {
        var value = rawURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return defaultRelayURLString }

        if value.hasPrefix("http://") {
            value = "wss://" + value.dropFirst("http://".count)
        } else if value.hasPrefix("https://") {
            value = "wss://" + value.dropFirst("https://".count)
        } else if value.hasPrefix("ws://ws-relay-zi5u.onrender.com") {
            value = "wss://" + value.dropFirst("ws://".count)
        }

        if value == "wss://ws-relay-zi5u.onrender.com" || value == "wss://ws-relay-zi5u.onrender.com/" {
            return "wss://ws-relay-zi5u.onrender.com/ws"
        }

        return value
    }

    private func configureTransportCallbacks() {
        localTransport.onMessageReceived = { [weak self] message in
            Task { @MainActor in
                self?.handleIncomingMessage(message)
            }
        }
        internetRelayTransport.onMessageReceived = { [weak self] message in
            Task { @MainActor in
                self?.handleIncomingMessage(message)
            }
        }
    }

    private func handleIncomingMessage(_ message: Message) {
        do {
            try messageRepository.save(message)
        } catch {
            print("Failed to persist incoming message: \(error)")
        }

        onMessageReceived?(message)
    }

    private func startNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                self.isInternetAvailable = path.status == .satisfied
                self.startActiveTransportWhenAvailable()
            }
        }
        pathMonitor.start(queue: pathMonitorQueue)
    }

    private func startActiveTransportWhenAvailable() {
        guard didBootstrap else { return }
        guard transportMode != .relay || isInternetAvailable else { return }

        Task {
            await startTransportIfNeeded()
        }
    }
}
