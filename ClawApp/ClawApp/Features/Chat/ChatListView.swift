import SwiftUI
import SharedModels

struct ChatListView: View {
    @EnvironmentObject var appState: AppState
    @State private var navigationPath = NavigationPath()
    @State private var isInitializing = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                if isInitializing {
                    ProgressView()
                        .tint(Theme.Colors.accent)
                } else {
                    sessionList
                }
            }
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: SessionDTO.self) { session in
                ChatDetailView(session: session)
                    .onAppear { appState.recordSessionOpened(session.id) }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        createNewChat()
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.Colors.accent)
                    }
                }
            }
            .task {
                let target = await appState.ensureSession()
                isInitializing = false
                navigationPath.append(target)
            }
        }
    }

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.sm) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(Theme.Typography.footnote)
                        .foregroundStyle(Theme.Colors.error)
                        .padding(.horizontal, Theme.Spacing.md)
                }

                ForEach(sortedSessions) { session in
                    NavigationLink(value: session) {
                        SessionRowView(session: session) {
                            deleteSession(session)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.sm)
        }
        .refreshable {
            await appState.loadSessions()
        }
    }

    private var sortedSessions: [SessionDTO] {
        appState.sessions.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            let dateA = a.lastMessageAt ?? a.createdAt
            let dateB = b.lastMessageAt ?? b.createdAt
            return dateA > dateB
        }
    }

    private func createNewChat() {
        Task {
            errorMessage = nil
            do {
                let session = try await appState.createSession()
                navigationPath.append(session)
                appState.recordSessionOpened(session.id)
            } catch {
                errorMessage = "Failed to create chat: \(error.localizedDescription)"
            }
        }
    }

    private func deleteSession(_ session: SessionDTO) {
        Task {
            try? await appState.getAPIClient()?.deleteSession(id: session.id)
            await appState.loadSessions()
            // If we deleted all sessions, ensure one exists
            if appState.sessions.isEmpty {
                let target = await appState.ensureSession()
                navigationPath.append(target)
            }
        }
    }
}
