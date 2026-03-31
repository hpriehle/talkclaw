import SwiftUI
import SharedModels

struct MessageBubbleView: View {
    let message: MessageDTO

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.sm) {
            if isUser { Spacer(minLength: 60) }

            // AI avatar
            if !isUser {
                Circle()
                    .fill(Theme.Colors.accentDim)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.Colors.accent)
                    }
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 2) {
                contentView
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isUser
                            ? AnyShapeStyle(Theme.Colors.bubbleSent)
                            : AnyShapeStyle(Theme.Colors.bubbleReceived),
                        in: bubbleShape
                    )
                    .if(!isUser) { $0.liquidGlass(in: bubbleShape) }

                Text(message.createdAt, style: .time)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }

    private var bubbleShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Radius.bubble)
    }

    @ViewBuilder
    private var contentView: some View {
        switch message.content {
        case .text(let text):
            Text(text)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.bubbleText)
                .textSelection(.enabled)

        case .code(let language, let content):
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text(language.uppercased())
                        .font(Theme.Typography.caption.bold())
                        .foregroundStyle(Theme.Colors.accent)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = content
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }

                Divider()
                    .background(Theme.Colors.separator)

                Text(content)
                    .font(Theme.Typography.mono)
                    .foregroundStyle(Theme.Colors.bubbleText)
                    .textSelection(.enabled)
            }

        case .system(let text):
            Text(text)
                .font(Theme.Typography.footnote)
                .foregroundStyle(Theme.Colors.textSecondary)
                .italic()

        case .error(let text):
            Label(text, systemImage: "exclamationmark.triangle")
                .font(Theme.Typography.footnote)
                .foregroundStyle(Theme.Colors.error)

        case .image(_, let caption):
            VStack {
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(Theme.Colors.surface3)
                    .frame(height: 200)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }

                if let caption {
                    Text(caption)
                        .font(Theme.Typography.footnote)
                        .foregroundStyle(Theme.Colors.bubbleText)
                }
            }

        case .file(let name, _, let size):
            HStack {
                Image(systemName: "doc.fill")
                    .foregroundStyle(Theme.Colors.accent)
                VStack(alignment: .leading) {
                    Text(name)
                        .font(Theme.Typography.subhead.bold())
                        .foregroundStyle(Theme.Colors.bubbleText)
                    Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
    }
}
