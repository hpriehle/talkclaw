import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            Tab("Chat", systemImage: "bubble.left.and.bubble.right.fill") {
                ChatTab()
            }

            Tab("Dashboard", systemImage: "square.grid.2x2.fill") {
                DashboardView()
            }

            Tab("Files", systemImage: "folder.fill") {
                FileBrowserView()
            }

            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
        .tint(Theme.Colors.accent)
    }
}

/// Resolves the current session then shows the messenger directly — no session list.
struct ChatTab: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                if let session = appState.currentSession {
                    ChatDetailView(session: session)
                } else {
                    ProgressView()
                        .tint(Theme.Colors.accent)
                }
            }
        }
        .task {
            if appState.currentSession == nil {
                let session = await appState.ensureSession()
                appState.currentSession = session
            }
        }
    }
}
