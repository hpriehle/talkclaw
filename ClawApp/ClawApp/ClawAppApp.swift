import SwiftUI
import SwiftData

@main
struct ClawAppApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isConnected {
                    MainTabView()
                        .environmentObject(appState)
                } else {
                    ServerSetupView()
                        .environmentObject(appState)
                }
            }
            .preferredColorScheme(.dark)
        }
        .modelContainer(for: [CachedSession.self, CachedMessage.self])
    }
}