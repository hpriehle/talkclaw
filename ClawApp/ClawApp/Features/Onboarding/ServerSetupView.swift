import SwiftUI

struct ServerSetupView: View {
    @EnvironmentObject var appState: AppState
    @State private var serverURL = ""
    @State private var apiKey = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Theme.Colors.background,
                    Color(hex: "0A0A1A"),
                    Theme.Colors.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Ambient glow
            Circle()
                .fill(Theme.Colors.accentGlow)
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(y: -100)

            VStack(spacing: Theme.Spacing.xl) {
                Spacer()

                // Logo
                VStack(spacing: Theme.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.accentDim)
                            .frame(width: 80, height: 80)
                        Image(systemName: "bubble.left.and.text.bubble.right.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Theme.Colors.accent)
                    }
                    .liquidGlass(in: Circle())

                    Text("ClawApp")
                        .font(Theme.Typography.largeTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text("Connect to your OpenClaw server")
                        .font(Theme.Typography.subhead)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                // Form card
                VStack(spacing: Theme.Spacing.lg) {
                    // Server URL
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("SERVER URL")
                            .font(Theme.Typography.caption.bold())
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .kerning(1.2)

                        TextField("https://your-server.com", text: $serverURL)
                            .textFieldStyle(.plain)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .tint(Theme.Colors.accent)
                            .textContentType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                    }

                    // API Key
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("API KEY")
                            .font(Theme.Typography.caption.bold())
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .kerning(1.2)

                        SecureField("Enter your API key", text: $apiKey)
                            .textFieldStyle(.plain)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .tint(Theme.Colors.accent)
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(Theme.Typography.footnote)
                            .foregroundStyle(Theme.Colors.error)
                    }

                    // Connect button
                    Button(action: connect) {
                        HStack {
                            if isConnecting {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            }
                            Text(isConnecting ? "Connecting..." : "Connect")
                                .font(Theme.Typography.headline)
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(
                            canConnect
                                ? Theme.Colors.accent
                                : Theme.Colors.surface3,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.md)
                        )
                        .animation(Theme.Anim.smooth, value: canConnect)
                    }
                    .disabled(!canConnect || isConnecting)
                }
                .padding(Theme.Spacing.lg)
                .background(Theme.Colors.surface2.opacity(0.7))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl))
                .liquidGlass(in: RoundedRectangle(cornerRadius: Theme.Radius.xl))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.xl)
                        .strokeBorder(Theme.Colors.borderDefault, lineWidth: 1)
                )
                .padding(.horizontal, Theme.Spacing.md)

                Spacer()
                Spacer()
            }
        }
    }

    private var canConnect: Bool {
        !serverURL.isEmpty && !apiKey.isEmpty
    }

    private func connect() {
        isConnecting = true
        errorMessage = nil

        Task {
            do {
                try await appState.connect(serverURL: serverURL, apiKey: apiKey)
            } catch {
                errorMessage = error.localizedDescription
            }
            isConnecting = false
        }
    }
}
