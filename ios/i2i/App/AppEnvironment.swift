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
    private static let defaultRelayURLString = "ws://192.168.1.60:8080/ws"
    private static let relayURLDefaultsKey = "relayURLString"
    private static let transportModeDefaultsKey = "transportMode"

    let identityService: IdentityService
    let pairingService: PairingService
    let peerRepository: any PeerRepository
    let messageRepository: any MessageRepository
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

    init() {
        let identity = IdentityService()
        let peers = LocalPeerRepository()
        let messages = LocalMessageRepository()
        let storedRelayURL = UserDefaults.standard.string(forKey: AppEnvironment.relayURLDefaultsKey)
        let relayURLString = storedRelayURL ?? AppEnvironment.defaultRelayURLString
        let relayURL = URL(string: relayURLString) ?? URL(string: AppEnvironment.defaultRelayURLString)!
        let storedMode = UserDefaults.standard.string(forKey: AppEnvironment.transportModeDefaultsKey)
        let transportMode = storedMode.flatMap(TransportMode.init(rawValue:)) ?? .relay
        self.identityService = identity
        self.peerRepository = peers
        self.messageRepository = messages
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
        guard startedTransportMode != transportMode else { return }
        startedTransportMode = transportMode

        do {
            try await activeTransport.start()
        } catch {
            startedTransportMode = nil
            print("Failed to start transport: \(error)")
        }
    }

    func stopTransport() {
        activeTransport.stop()
        startedTransportMode = nil
    }
    
    func notifyPeerChanged() {
        peerChangeCount += 1
    }

    private func stopAllTransports() {
        localTransport.stop()
        internetRelayTransport.stop()
        startedTransportMode = nil
    }

    private func updateRelayURL() {
        guard let relayURL = URL(string: relayURLString) else {
            print("Invalid relay URL: \(relayURLString)")
            return
        }

        internetRelayTransport.updateRelayURL(relayURL)
        if transportMode == .relay {
            startedTransportMode = nil
        }
        startActiveTransportWhenAvailable()
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
