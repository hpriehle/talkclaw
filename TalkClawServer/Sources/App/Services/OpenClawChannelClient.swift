import Vapor

struct OpenClawChannelClient {
    let channelURL: String
    let webhookSecret: String
    let logger: Logger
    let client: Client

    /// POST the user's message to the OpenClaw channel plugin.
    /// Responses come back asynchronously via the webhook endpoint.
    func sendToChannel(sessionId: UUID, content: String) async throws {
        guard !channelURL.isEmpty else {
            logger.warning("OPENCLAW_CHANNEL_URL not configured — message not sent to AI")
            return
        }

        let payload = ChannelOutboundPayload(
            sessionId: sessionId,
            content: content,
            context: .init(
                channel: "talkclaw",
                provider: "talkclaw",
                surface: "talkclaw",
                chatId: "talkclaw:session-\(sessionId.uuidString.lowercased())"
            )
        )

        for attempt in 1...2 {
            do {
                let response = try await client.post(URI(string: channelURL)) { req in
                    req.headers.add(name: "Authorization", value: "Bearer \(webhookSecret)")
                    req.headers.contentType = .json
                    try req.content.encode(payload)
                }
                guard response.status == .ok || response.status == .accepted else {
                    throw ChannelError.badStatus(response.status)
                }
                return
            } catch {
                if attempt == 1 {
                    logger.warning("Channel POST failed (attempt 1), retrying in 2s: \(error)")
                    try? await Task.sleep(for: .seconds(2))
                } else {
                    throw error
                }
            }
        }
    }

    enum ChannelError: Error, LocalizedError {
        case badStatus(HTTPStatus)
        var errorDescription: String? {
            switch self {
            case .badStatus(let s): return "Channel returned \(s)"
            }
        }
    }
}

struct ChannelOutboundPayload: Content {
    let sessionId: UUID
    let content: String
    let context: ChannelContext

    struct ChannelContext: Content {
        let channel: String
        let provider: String
        let surface: String
        let chatId: String

        enum CodingKeys: String, CodingKey {
            case channel, provider, surface
            case chatId = "chat_id"
        }
    }
}
