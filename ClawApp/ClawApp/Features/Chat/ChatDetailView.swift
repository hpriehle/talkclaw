import SwiftUI
import SharedModels

struct ChatDetailView: View {
    @EnvironmentObject var appState: AppState
    let session: SessionDTO

    @State private var messages: [MessageDTO] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var isWaitingForResponse = false
    @State private var streamingText = ""
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.md) {
                            ForEach(messages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                            }

                            if isWaitingForResponse && !streamingText.isEmpty {
                                StreamingBubbleView(text: streamingText)
                                    .id("streaming-bubble")
                            } else if isWaitingForResponse {
                                StreamingIndicator()
                                    .id("streaming")
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.md)
                        .padding(.bottom, Theme.Spacing.xl)
                    }
                    .onChange(of: messages.count) {
                        withAnimation {
                            if let lastId = messages.last?.id {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: streamingText) {
                        if isWaitingForResponse {
                            withAnimation {
                                proxy.scrollTo("streaming-bubble", anchor: .bottom)
                            }
                        }
                    }
                }

                MessageComposer(text: $inputText, isDisabled: isWaitingForResponse) {
                    sendMessage()
                }
            }
        }
        .navigationTitle(session.title ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await loadMessages()
        }
        .onReceive(NotificationCenter.default.publisher(for: .chatDelta)) { notification in
            guard let delta = notification.userInfo?["delta"] as? WSMessage.ChatDeltaPayload,
                  delta.sessionId == session.id else { return }
            streamingText += delta.delta
        }
        .onReceive(NotificationCenter.default.publisher(for: .chatComplete)) { notification in
            guard let message = notification.userInfo?["message"] as? MessageDTO,
                  message.sessionId == session.id else { return }
            streamingText = ""
            isWaitingForResponse = false
            messages.append(message)
        }
        .alert("Send Failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func loadMessages() async {
        guard let client = appState.getAPIClient() else { return }
        isLoading = true
        do {
            let response = try await client.getMessages(sessionId: session.id)
            messages = response.items
        } catch {
            print("Failed to load messages: \(error)")
        }
        isLoading = false
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""

        let userMsg = MessageDTO(
            id: UUID(),
            sessionId: session.id,
            role: .user,
            content: .text(text)
        )
        messages.append(userMsg)
        isWaitingForResponse = true
        streamingText = ""

        Task {
            guard let client = appState.getAPIClient() else { return }
            do {
                let _ = try await client.sendMessage(sessionId: session.id, content: text)
            } catch {
                print("Failed to send message: \(error)")
                errorMessage = error.localizedDescription
                isWaitingForResponse = false
            }
        }
    }
}

// MARK: - Streaming Views

struct StreamingBubbleView: View {
    let text: String

    var body: some View {
        HStack {
            Text(text)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.bubbleText)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
                .background(Theme.Colors.surface3, in: RoundedRectangle(cornerRadius: Theme.Radius.bubble))
                .liquidGlass(in: RoundedRectangle(cornerRadius: Theme.Radius.bubble))

            Spacer()
        }
    }
}

struct StreamingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Theme.Colors.textSecondary)
                        .frame(width: 7, height: 7)
                        .scaleEffect(animating ? 1.3 : 0.7)
                        .animation(
                            .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.Colors.surface3, in: RoundedRectangle(cornerRadius: Theme.Radius.bubble))
            .liquidGlass(in: RoundedRectangle(cornerRadius: Theme.Radius.bubble))

            Spacer()
        }
        .onAppear { animating = true }
    }
}
