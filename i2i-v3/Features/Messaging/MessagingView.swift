import SwiftUI

struct MessagingView: View {
    @EnvironmentObject var env: AppEnvironment
    @StateObject private var viewModel = MessagingViewModel()
    @State private var showNameEditor = false
    @State private var showRelaySettings = false
    @State private var relayURLDraft = ""
    @FocusState private var focusedField: FocusedField?

    private enum FocusedField: Hashable {
        case message
        case deviceName
        case relayURL
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.peers.isEmpty {
                    EmptyStateView(
                        title: "No Paired Devices",
                        systemImage: "person.2.slash",
                        description: "Pair a device from the Pair tab to start messaging."
                    )
                } else {
                    // Header with peer selection and status
                    VStack(spacing: 8) {
                        HStack {
                            Picker("Select Peer", selection: $viewModel.selectedPeer) {
                                ForEach(viewModel.peers) { peer in
                                    Text(peer.displayName).tag(peer as Peer?)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            Button(action: { showNameEditor = true }) {
                                Image(systemName: "pencil.circle")
                                    .font(.title3)
                            }
                            .help("Edit device name")
                        }
                        .padding()

                        if let errorMessage = viewModel.errorMessage {
                            VStack(spacing: 6) {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .multilineTextAlignment(.center)
                                Button("Go to Peers") {
                                    env.selectedTab = .peers
                                }
                                .font(.caption.bold())
                            }
                            .padding(.horizontal)
                        }

                        Picker("Transport", selection: $env.transportMode) {
                            ForEach(TransportMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        if viewModel.isSelectedPeerConnected {
                            HStack {
                                Image(systemName: "circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                                Text("Connected via \(env.transportMode.title)")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                Spacer()
                                Text(viewModel.deviceName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        } else {
                            HStack {
                                Image(systemName: "circle")
                                    .foregroundStyle(.gray)
                                    .font(.caption)
                                Text(disconnectedStatusText)
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                Spacer()
                                Text(viewModel.deviceName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        }
                    }
                    .background(Color(.systemGray6))
                    
                    // Messages
                    ScrollViewReader { proxy in
                        VStack {
                            ScrollView {
                                VStack(spacing: 12) {
                                    if viewModel.messages.isEmpty {
                                        VStack {
                                            Spacer()
                                            Text("No messages yet")
                                                .foregroundStyle(.secondary)
                                                .font(.callout)
                                            Spacer()
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    } else {
                                        ForEach(viewModel.messages) { message in
                                            messageBubble(for: message)
                                                .id(message.id)
                                        }
                                    }
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 8)
                            }
                            .scrollDismissesKeyboard(.interactively)
                            .onChange(of: viewModel.messages.count, perform: { _ in
                                if let lastMessage = viewModel.messages.last {
                                    withAnimation {
                                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                    }
                                }
                            })
                        }
                    }
                    
                    Divider()
                    
                    // Input
                    HStack(spacing: 12) {
                        TextField("Message", text: $viewModel.draft)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .message)
                            .submitLabel(.send)
                            .onSubmit {
                                sendMessage()
                            }
                        
                        Button(action: { sendMessage() }) {
                            Image(systemName: "paperplane.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.canSend)
                    }
                    .padding()
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Exit") {
                        focusedField = nil
                        env.selectedTab = .peers
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        focusedField = nil
                        relayURLDraft = env.relayURLString
                        showRelaySettings = true
                    } label: {
                        Image(systemName: "network")
                    }
                    .help("Relay settings")

                    if viewModel.isSelectedPeerConnected {
                        Button(action: { viewModel.disconnect() }) {
                            Image(systemName: "power.circle")
                                .foregroundStyle(.red)
                        }
                        .help("Disconnect")
                    } else {
                        Button(action: { viewModel.reconnect() }) {
                            Image(systemName: "arrow.clockwise.circle")
                        }
                        .help("Reconnect")
                    }
                }
            }
            .sheet(isPresented: $showNameEditor) {
                editNameSheet
            }
            .sheet(isPresented: $showRelaySettings) {
                relaySettingsSheet
            }
            .onAppear {
                viewModel.initialize(with: env)
            }
            .onChange(of: viewModel.selectedPeer?.id, perform: { _ in
                viewModel.loadMessagesForSelectedPeer()
            })
            .onChange(of: env.transportMode, perform: { _ in
                focusedField = nil
                viewModel.transportModeDidChange()
            })
        }
    }

    private func sendMessage() {
        viewModel.sendTapped()
        focusedField = nil
    }

    private var disconnectedStatusText: String {
        if env.transportMode == .relay {
            return env.isInternetAvailable ? "Relay ready" : "No internet"
        }
        return "Disconnected"
    }
    
    @ViewBuilder
    private func messageBubble(for message: Message) -> some View {
        HStack {
            if message.senderPeerId == viewModel.localDeviceId {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.body)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.body)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                }
                Spacer()
            }
        }
    }
    
    private var editNameSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Device Name")
                        .font(.headline)
                    
                    TextField("Device Name", text: $viewModel.pendingDisplayName)
                        .textFieldStyle(.roundedBorder)
                        .padding(.vertical, 8)
                        .focused($focusedField, equals: .deviceName)
                        .submitLabel(.done)
                        .onSubmit {
                            viewModel.saveDeviceName()
                            focusedField = nil
                            showNameEditor = false
                        }
                    
                    Text("This name will be shown to other devices when pairing.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                
                Spacer()
                
                Button("Save") {
                    viewModel.saveDeviceName()
                    focusedField = nil
                    showNameEditor = false
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding()
            }
            .navigationTitle("Edit Device Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        focusedField = nil
                        showNameEditor = false
                    }
                }
            }
        }
    }

    private var relaySettingsSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Relay URL")
                    .font(.headline)

                TextField("wss://ws-relay-zi5u.onrender.com/ws", text: $relayURLDraft)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .relayURL)
                    .submitLabel(.done)
                    .onSubmit {
                        saveRelaySettings()
                    }

                Text("Use a wss:// relay URL for internet messaging across different networks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Save Relay Settings") {
                    saveRelaySettings()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Relay Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        focusedField = nil
                        showRelaySettings = false
                    }
                }
            }
        }
    }

    private func saveRelaySettings() {
        focusedField = nil
        env.relayURLString = relayURLDraft
        showRelaySettings = false
        viewModel.transportModeDidChange()
    }
}
