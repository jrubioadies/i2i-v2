import SwiftUI

struct ConversationListView: View {
    @StateObject var viewModel: MessagingViewModel

    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.conversations.isEmpty {
                    emptyStateView
                } else {
                    conversationsList
                }
            }
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    navigationOptions
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("No Conversations")
                .font(.headline)

            Text("Pair with a device to start messaging")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private var conversationsList: some View {
        List {
            ForEach(viewModel.conversations) { conversation in
                NavigationLink(
                    destination: MessagingDetailView(
                        viewModel: viewModel,
                        conversation: conversation
                    )
                ) {
                    ConversationRowView(conversation: conversation)
                }
            }
        }
        .listStyle(.inset)
    }

    private var navigationOptions: some View {
        Menu {
            Button(action: {
                // TODO: Add new conversation action
            }) {
                Label("New Conversation", systemImage: "square.and.pencil")
            }
            .disabled(viewModel.peers.isEmpty)
        } label: {
            Image(systemName: "plus")
        }
    }
}

struct ConversationRowView: View {
    let conversation: Conversation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(conversation.displayName)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if let lastMessageAt = conversation.lastMessageAt {
                    Text(formatDate(lastMessageAt))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Text("Last message preview")
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(2)
        }
        .contentShape(Rectangle())
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        } else {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }
}

struct MessagingDetailView: View {
    @StateObject var viewModel: MessagingViewModel
    let conversation: Conversation

    var body: some View {
        VStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(
                                message: message,
                                isFromCurrentUser: message.senderPeerId == viewModel.localDeviceId
                            )
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages) { _ in
                    if let lastMessageId = viewModel.messages.last?.id {
                        withAnimation {
                            scrollProxy.scrollTo(lastMessageId, anchor: .bottom)
                        }
                    }
                }
            }

            messagingInputView
        }
        .navigationTitle(conversation.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.selectConversation(conversation)
        }
    }

    private var messagingInputView: some View {
        HStack(spacing: 12) {
            TextField("Message", text: $viewModel.draft)
                .textFieldStyle(.roundedBorder)

            Button(action: viewModel.sendTapped) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(viewModel.canSend ? .blue : .gray)
            }
            .disabled(!viewModel.canSend)
        }
        .padding()
    }
}

struct MessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool

    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer() }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading) {
                Text(message.body)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(isFromCurrentUser ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(isFromCurrentUser ? .white : .black)
                    .cornerRadius(12)

                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            if !isFromCurrentUser { Spacer() }
        }
    }
}
