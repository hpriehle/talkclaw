import SwiftUI

struct DashboardView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                VStack(spacing: Theme.Spacing.lg) {
                    Spacer()

                    VStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 48))
                            .foregroundStyle(Theme.Colors.textTertiary)

                        Text("Dashboard")
                            .font(Theme.Typography.title)
                            .foregroundStyle(Theme.Colors.textPrimary)

                        Text("Widgets will appear here once the widget engine is built. Ask your AI to create widgets and they'll populate this dashboard.")
                            .font(Theme.Typography.subhead)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Theme.Spacing.xl)
                    }
                    .padding(Theme.Spacing.xl)
                    .glassCard()

                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
            .navigationTitle("Dashboard")
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}
