import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showDisconnectAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                List {
                    Section("Server") {
                        LabeledContent("URL", value: appState.serverURL)
                        LabeledContent("Status") {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(appState.connectionStatus == .connected
                                          ? Theme.Colors.success
                                          : Theme.Colors.error)
                                    .frame(width: 8, height: 8)
                                Text(appState.connectionStatus.rawValue.capitalized)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                        }
                    }
                    .listRowBackground(Theme.Colors.surface2)

                    Section("Account") {
                        if let user = appState.currentUser {
                            LabeledContent("Email", value: user.email)
                            if let name = user.displayName {
                                LabeledContent("Name", value: name)
                            }
                        }
                    }
                    .listRowBackground(Theme.Colors.surface2)

                    Section {
                        Button("Disconnect", role: .destructive) {
                            showDisconnectAlert = true
                        }
                    }
                    .listRowBackground(Theme.Colors.surface2)

                    Section("About") {
                        LabeledContent("Version", value: "0.1.0")
                        LabeledContent("Build", value: "Phase 1 MVP")
                    }
                    .listRowBackground(Theme.Colors.surface2)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .toolbarBackground(.hidden, for: .navigationBar)
            .alert("Disconnect?", isPresented: $showDisconnectAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Disconnect", role: .destructive) {
                    appState.disconnect()
                }
            } message: {
                Text("This will remove your server connection. You can reconnect later.")
            }
        }
    }
}
