import SwiftUI
import SharedModels

struct SessionRowView: View {
    let session: SessionDTO
    let onDelete: (() -> Void)?

    init(session: SessionDTO, onDelete: (() -> Void)? = nil) {
        self.session = session
        self.onDelete = onDelete
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Theme.Colors.accentDim)
                    .frame(width: 44, height: 44)

                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.Colors.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    if session.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.accent)
                    }
                    Text(session.title ?? "New Chat")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    if let lastMessage = session.lastMessageAt {
                        Text(lastMessage, style: .relative)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                }

                Text("Tap to continue")
                    .font(Theme.Typography.subhead)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
            }

            if session.unreadCount > 0 {
                Text("\(session.unreadCount)")
                    .font(Theme.Typography.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(Theme.Colors.accent, in: Capsule())
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .strokeBorder(Theme.Colors.borderSubtle, lineWidth: 1)
        )
        .contextMenu {
            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}