import SwiftUI
import SharedModels
import MarkdownUI

struct MessageBubbleView: View {
    @EnvironmentObject var appState: AppState
    let message: MessageDTO
    @State private var showCopied = false

    private var isUser: Bool { message.role == .user }

    var body: some View {
        if isUser {
            userBubble
        } else {
            aiMessage
        }
    }

    // MARK: - User bubble (right-aligned, accent background)

    private var userBubble: some View {
        HStack {
            Spacer(minLength: 60)

            VStack(alignment: .trailing, spacing: 2) {
                userContent
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.Colors.bubbleSent, in: bubbleShape)

                Text(message.createdAt, style: .time)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
    }

    // MARK: - AI message (full-width, no bubble)

    private var aiMessage: some View {
        VStack(alignment: .leading, spacing: 4) {
            aiContent
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: Theme.Spacing.sm) {
                Text(message.createdAt, style: .time)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)

                Button {
                    if case .text(let text) = message.content {
                        UIPasteboard.general.string = text
                    }
                    withAnimation(.easeInOut(duration: 0.2)) { showCopied = true }
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        withAnimation(.easeInOut(duration: 0.2)) { showCopied = false }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12))
                        if showCopied {
                            Text("Copied")
                                .font(Theme.Typography.caption)
                        }
                    }
                    .foregroundStyle(showCopied ? Theme.Colors.success : Theme.Colors.textTertiary)
                }
            }
        }
    }

    private var bubbleShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Radius.bubble)
    }

    // MARK: - User content

    @ViewBuilder
    private var userContent: some View {
        switch message.content {
        case .text(let text):
            Text(text)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.bubbleText)
                .textSelection(.enabled)
        default:
            sharedContent
        }
    }

    // MARK: - AI content

    @ViewBuilder
    private var aiContent: some View {
        switch message.content {
        case .text(let text):
            Markdown(text)
                .markdownTheme(.claw)
                .textSelection(.enabled)
        default:
            sharedContent
        }
    }

    // MARK: - Shared content (code, system, error, image, file)

    @ViewBuilder
    private var sharedContent: some View {
        switch message.content {
        case .text:
            EmptyView() // handled above

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

        case .image(let url, let caption):
            VStack(alignment: .leading) {
                if url.scheme == "placeholder" {
                    // Optimistic local placeholder while uploading
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .fill(Theme.Colors.surface3)
                        .frame(height: 200)
                        .overlay {
                            ProgressView()
                                .tint(Theme.Colors.accent)
                        }
                } else {
                    AuthenticatedImage(
                        url: url,
                        serverURL: appState.serverURL,
                        apiKey: appState.apiKey
                    )
                    .frame(maxWidth: 280, maxHeight: 300)
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

        case .widget(let payload):
            WidgetBubbleView(payload: payload)
        }
    }
}

// MARK: - Authenticated Image

/// Loads images from the server with Bearer token auth.
/// Handles both relative paths (/api/v1/files/...) and full URLs.
/// Uses an in-memory cache to avoid re-fetching on scroll.
private struct AuthenticatedImage: View {
    let url: URL
    let serverURL: String
    let apiKey: String
    @State private var image: UIImage?
    @State private var failed = false

    private static let cache = NSCache<NSURL, UIImage>()

    private var resolvedURL: URL? {
        if url.host != nil { return url }
        guard var base = URL(string: serverURL) else { return nil }
        base.appendPathComponent(url.path)
        return base
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
            } else if failed {
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(Theme.Colors.surface3)
                    .frame(height: 200)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
            } else {
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(Theme.Colors.surface3)
                    .frame(height: 200)
                    .overlay { ProgressView().tint(Theme.Colors.accent) }
            }
        }
        .task { await loadImage() }
    }

    private func loadImage() async {
        guard let resolved = resolvedURL else { failed = true; return }

        // Check cache first
        if let cached = Self.cache.object(forKey: resolved as NSURL) {
            image = cached
            return
        }

        var request = URLRequest(url: resolved)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let uiImage = UIImage(data: data) else {
                failed = true
                return
            }
            Self.cache.setObject(uiImage, forKey: resolved as NSURL)
            image = uiImage
        } catch {
            failed = true
        }
    }
}
