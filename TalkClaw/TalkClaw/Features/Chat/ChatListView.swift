import SwiftUI
import SharedModels

struct ChatListView: View {
    @EnvironmentObject var appState: AppState
    @State private var navigationPath = NavigationPath()
    @State private var isInitializing = true
    @State private var errorMessage: String?
    @State private var renamingSession: SessionDTO?
    @State private var renameText = ""
    @State private var showArchived = false
    @State private var searchText = ""
    @State private var searchResults: [SearchResultDTO] = []
    @State private var isSearchingGlobal = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                if isInitializing {
                    ProgressView()
                        .tint(Theme.Colors.accent)
                } else if !searchText.isEmpty {
                    searchResultsList
                } else {
                    sessionList
                }
            }
            .searchable(text: $searchText, prompt: "Search messages…")
            .onChange(of: searchText) { _, query in
                searchTask?.cancel()
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    searchResults = []
                    isSearchingGlobal = false
                    return
                }
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    await performGlobalSearch(query: query)
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
                let _ = await appState.ensureSession()
                isInitializing = false
            }
            .onChange(of: appState.pushNavigationSessionId) { _, sessionId in
                guard let sessionId else { return }
                appState.pushNavigationSessionId = nil
                if let session = appState.sessions.first(where: { $0.id == sessionId }) {
                    navigationPath = NavigationPath()
                    navigationPath.append(session)
                }
            }
        }
    }

    private var sessionList: some View {
        List {
            if let errorMessage {
                Text(errorMessage)
                    .font(Theme.Typography.footnote)
                    .foregroundStyle(Theme.Colors.error)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if !pinnedSessions.isEmpty {
                Section {
                    sessionRows(pinnedSessions)
                } header: {
                    Text("Pinned").font(Theme.Typography.caption).foregroundStyle(Theme.Colors.textTertiary)
                }
            }

            Section {
                sessionRows(recentSessions)
            } header: {
                if !pinnedSessions.isEmpty {
                    Text("Recent").font(Theme.Typography.caption).foregroundStyle(Theme.Colors.textTertiary)
                }
            }

            if !archivedSessions.isEmpty {
                Section(isExpanded: $showArchived) {
                    sessionRows(archivedSessions)
                } header: {
                    Text("Archived").font(Theme.Typography.caption).foregroundStyle(Theme.Colors.textTertiary)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await appState.loadSessions()
        }
        .alert("Rename Chat", isPresented: Binding(
            get: { renamingSession != nil },
            set: { if !$0 { renamingSession = nil } }
        )) {
            TextField("Title", text: $renameText)
            Button("Save") { renameSession() }
            Button("Cancel", role: .cancel) { renamingSession = nil }
        }
    }

    @ViewBuilder
    private func sessionRows(_ sessions: [SessionDTO]) -> some View {
        ForEach(sessions) { session in
            NavigationLink(value: session) {
                SessionRowView(
                    session: session,
                    onDelete: { deleteSession(session) },
                    onPin: { pinSession(session) }
                )
            }
            .buttonStyle(SessionRowButtonStyle())
            .listRowBackground(
                Group {
                    if appState.activeSessionIds.contains(session.id) {
                        Color.clear.glassCard(cornerRadius: Theme.Radius.md)
                    } else {
                        Color.clear
                    }
                }
            )
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    deleteSession(session)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                Button {
                    archiveSession(session)
                } label: {
                    Label(
                        session.isArchived ? "Unarchive" : "Archive",
                        systemImage: session.isArchived ? "tray.and.arrow.up" : "archivebox"
                    )
                }
                .tint(Theme.Colors.warning)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    pinSession(session)
                } label: {
                    Label(
                        session.isPinned ? "Unpin" : "Pin",
                        systemImage: session.isPinned ? "pin.slash" : "pin"
                    )
                }
                .tint(Theme.Colors.accent)
            }
            .contextMenu {
                Button {
                    renamingSession = session
                    renameText = session.title ?? ""
                } label: {
                    Label("Rename", systemImage: "pencil")
                }

                Button {
                    pinSession(session)
                } label: {
                    Label(
                        session.isPinned ? "Unpin" : "Pin",
                        systemImage: session.isPinned ? "pin.slash" : "pin"
                    )
                }

                Button {
                    archiveSession(session)
                } label: {
                    Label(
                        session.isArchived ? "Unarchive" : "Archive",
                        systemImage: session.isArchived ? "tray.and.arrow.up" : "archivebox"
                    )
                }

                Divider()

                Button(role: .destructive) {
                    deleteSession(session)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var searchResultsList: some View {
        Group {
            if isSearchingGlobal && searchResults.isEmpty {
                ProgressView()
                    .tint(Theme.Colors.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty {
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(Theme.Colors.textTertiary)
                    Text("No results")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(groupedSearchResults, id: \.sessionTitle) { group in
                        Section {
                            ForEach(group.results, id: \.message.id) { result in
                                Button {
                                    navigateToSearchResult(result)
                                } label: {
                                    SearchResultRow(result: result, query: searchText)
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        } header: {
                            Text(group.sessionTitle)
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textTertiary)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private struct SearchGroup {
        let sessionTitle: String
        let results: [SearchResultDTO]
    }

    private var groupedSearchResults: [SearchGroup] {
        let grouped = Dictionary(grouping: searchResults) { $0.sessionTitle ?? "Untitled" }
        return grouped.map { SearchGroup(sessionTitle: $0.key, results: $0.value) }
            .sorted { $0.results.first?.message.createdAt ?? .distantPast > $1.results.first?.message.createdAt ?? .distantPast }
    }

    private func performGlobalSearch(query: String) async {
        isSearchingGlobal = true
        do {
            if let client = appState.getAPIClient() {
                searchResults = try await client.globalSearch(query: query)
            }
        } catch {
            print("Search failed: \(error)")
        }
        isSearchingGlobal = false
    }

    private func navigateToSearchResult(_ result: SearchResultDTO) {
        // Find the session matching this result and navigate to it
        if let session = appState.sessions.first(where: { $0.id == result.message.sessionId }) {
            navigationPath.append(session)
        }
    }

    private func sortedByDate(_ sessions: [SessionDTO]) -> [SessionDTO] {
        sessions.sorted {
            ($0.lastMessageAt ?? $0.createdAt) > ($1.lastMessageAt ?? $1.createdAt)
        }
    }

    private var pinnedSessions: [SessionDTO] {
        sortedByDate(appState.sessions.filter { $0.isPinned && !$0.isArchived })
    }

    private var recentSessions: [SessionDTO] {
        sortedByDate(appState.sessions.filter { !$0.isPinned && !$0.isArchived })
    }

    private var archivedSessions: [SessionDTO] {
        sortedByDate(appState.sessions.filter { $0.isArchived })
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

    private func pinSession(_ session: SessionDTO) {
        Task {
            let update = UpdateSessionRequest(isPinned: !session.isPinned)
            let _ = try? await appState.getAPIClient()?.updateSession(id: session.id, update: update)
            await appState.loadSessions()
        }
    }

    private func renameSession() {
        guard let session = renamingSession else { return }
        let newTitle = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newTitle.isEmpty else { return }
        Task {
            let update = UpdateSessionRequest(title: newTitle)
            let _ = try? await appState.getAPIClient()?.updateSession(id: session.id, update: update)
            await appState.loadSessions()
        }
        renamingSession = nil
    }

    private func archiveSession(_ session: SessionDTO) {
        Task {
            let update = UpdateSessionRequest(isArchived: !session.isArchived)
            let _ = try? await appState.getAPIClient()?.updateSession(id: session.id, update: update)
            await appState.loadSessions()
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

// MARK: - Search Result Row

private struct SearchResultRow: View {
    let result: SearchResultDTO
    let query: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: result.message.role == .user ? "person.fill" : "brain")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Colors.textTertiary)

                Text(result.message.role == .user ? "You" : "Assistant")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)

                Spacer()

                Text(result.message.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textDisabled)
            }

            Text(highlightedPreview)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineLimit(2)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, Theme.Spacing.sm)
    }

    private var highlightedPreview: AttributedString {
        let text = result.message.searchableText
        // Get a snippet around the match
        let lowered = text.lowercased()
        let queryLowered = query.lowercased()
        guard let range = lowered.range(of: queryLowered) else {
            return AttributedString(String(text.prefix(150)))
        }

        let matchStart = lowered.distance(from: lowered.startIndex, to: range.lowerBound)
        let snippetStart = max(0, matchStart - 40)
        let startIdx = text.index(text.startIndex, offsetBy: snippetStart)
        let endIdx = text.index(startIdx, offsetBy: min(150, text.distance(from: startIdx, to: text.endIndex)))
        var snippet = String(text[startIdx..<endIdx])
        if snippetStart > 0 { snippet = "…" + snippet }
        if endIdx < text.endIndex { snippet += "…" }

        var attributed = AttributedString(snippet)
        // Bold the matching part
        if let attrRange = attributed.range(of: query, options: .caseInsensitive) {
            attributed[attrRange].font = .system(size: 16, weight: .semibold)
            attributed[attrRange].foregroundColor = UIColor(Theme.Colors.textPrimary)
        }
        return attributed
    }
}

// MARK: - Session Row Button Style

private struct SessionRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(Theme.Anim.fast, value: configuration.isPressed)
    }
}
