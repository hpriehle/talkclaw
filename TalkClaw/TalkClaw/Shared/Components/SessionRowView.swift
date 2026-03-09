import SwiftUI
import SharedModels

struct SessionRowView: View {
    @EnvironmentObject var appState: AppState
    let session: SessionDTO
    let onDelete: (() -> Void)?
    let onPin: (() -> Void)?

    init(session: SessionDTO, onDelete: (() -> Void)? = nil, onPin: (() -> Void)? = nil) {
        self.session = session
        self.onDelete = onDelete
        self.onPin = onPin
    }

    private var isUnread: Bool { session.unreadCount > 0 }
    private var isActive: Bool { appState.activeSessionIds.contains(session.id) }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            StatusCircle(isActive: isActive, isUnread: isUnread)

            VStack(alignment: .leading, spacing: 3) {
                // Title row
                HStack(alignment: .center) {
                    if session.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.Colors.accent)
                    }

                    Text(session.title ?? "New Chat")
                        .font(.system(size: 16, weight: isUnread ? .semibold : .medium))
                        .foregroundStyle(isUnread ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                        .lineLimit(1)

                    Spacer()

                    if let lastMessage = session.lastMessageAt {
                        Text(formatTimestamp(lastMessage))
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textDisabled)
                    }
                }

                // Message preview or typing indicator
                if isActive {
                    RowTypingIndicator()
                } else {
                    previewLabel
                        .font(.system(size: 14, weight: isUnread ? .medium : .regular))
                        .foregroundStyle(isUnread ? Theme.Colors.textSecondary : Theme.Colors.textTertiary)
                        .lineLimit(2)
                        .lineSpacing(2)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 13)
    }

    @ViewBuilder
    private var previewLabel: some View {
        let raw = session.lastMessagePreview ?? "No messages yet"
        switch raw {
        case let s where s.hasPrefix("[Image"):
            Label("Photo", systemImage: "photo")
        case let s where s.hasPrefix("[") && s.hasSuffix("]"):
            Label(String(s.dropFirst().dropLast()), systemImage: "doc")
        default:
            Text(raw.strippingMarkdown)
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(.dateTime.month(.defaultDigits).day())
        }
    }
}

// MARK: - Status Circle

private struct StatusCircle: View {
    let isActive: Bool
    let isUnread: Bool
    @State private var pulsing = false

    private var dotColor: Color {
        if isActive { return Theme.Colors.success }
        if isUnread { return Theme.Colors.accent }
        return Theme.Colors.textTertiary
    }

    var body: some View {
        Circle()
            .fill(Theme.Colors.surface4)
            .frame(width: 42, height: 42)
            .overlay(
                Circle()
                    .fill(dotColor)
                    .frame(width: 12, height: 12)
                    .scaleEffect(isActive && pulsing ? 1.3 : 1.0)
                    .animation(
                        isActive
                            ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                            : .default,
                        value: pulsing
                    )
            )
            .overlay(
                Circle()
                    .strokeBorder(Theme.Colors.borderSubtle, lineWidth: 1.5)
            )
            .animation(Theme.Anim.smooth, value: isActive)
            .animation(Theme.Anim.smooth, value: isUnread)
            .onChange(of: isActive) { _, active in
                pulsing = active
            }
    }
}

// MARK: - Row Typing Indicator

private struct RowTypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Theme.Colors.success)
                    .frame(width: 5, height: 5)
                    .scaleEffect(animating ? 1.3 : 0.7)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.15),
                        value: animating
                    )
            }

            Spacer()
        }
        .frame(height: 18)
        .onAppear { animating = true }
    }
}
