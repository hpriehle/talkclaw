import Vapor
import Fluent
import SharedModels
import Foundation
import AsyncHTTPClient
import NIOCore
import NIOHTTP1

struct OpenClawChannelClient: Sendable {
    let baseURL: String
    let token: String
    let webhookSecret: String
    let logger: Logger
    let httpClient: HTTPClient

    /// Sends a user message to the OpenClaw gateway webhook.
    /// The response comes back asynchronously via POST /api/v1/sessions/{id}/messages
    /// from the OpenClaw TalkClaw channel plugin.
    func sendChat(
        sessionId: UUID,
        content: String,
        manager: ClientWSManager,
        db: Database
    ) async {
        guard !baseURL.isEmpty else {
            logger.warning("OPENCLAW_URL not configured — message not sent to AI")
            return
        }

        // Build widget inventory for agent context
        let widgetInventory = await buildWidgetInventory(db: db)

        var payload: [String: Any] = [
            "sessionId": sessionId.uuidString.lowercased(),
            "content": content,
            "secret": webhookSecret
        ]
        if !widgetInventory.isEmpty {
            payload["widgets"] = widgetInventory
        }
        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else {
            logger.error("Failed to serialize webhook payload")
            return
        }

        do {
            var request = HTTPClientRequest(url: "\(baseURL)/webhook/talkclaw")
            request.method = .POST
            request.headers.add(name: "Content-Type", value: "application/json")
            request.body = .bytes(ByteBuffer(data: bodyData))

            let response = try await httpClient.execute(request, timeout: .seconds(30))

            guard (200..<300).contains(Int(response.status.code)) else {
                logger.error("OpenClaw webhook returned HTTP \(response.status.code)")
                await manager.sendToSession(
                    .error(.init(code: Int(response.status.code), message: "AI backend returned HTTP \(response.status.code)")),
                    sessionId: sessionId, logger: logger
                )
                return
            }

            logger.info("Message sent to OpenClaw webhook for session \(sessionId)")

            // Auto-title the session from the first user message
            try? await autoTitleIfNeeded(sessionId: sessionId, db: db, manager: manager)

        } catch {
            logger.error("OpenClaw webhook error: \(error)")
            await manager.sendToSession(
                .error(.init(code: 500, message: "Failed to send message to AI: \(error.localizedDescription)")),
                sessionId: sessionId, logger: logger
            )
        }
    }

    /// Build a lightweight widget inventory for the agent context.
    private func buildWidgetInventory(db: Database) async -> [[String: Any]] {
        guard let widgets = try? await Widget.query(on: db).all() else { return [] }
        return widgets.compactMap { widget -> [String: Any]? in
            guard let id = widget.id else { return nil }
            var entry: [String: Any] = [
                "slug": widget.slug,
                "title": widget.title,
                "description": widget.description,
                "surface": widget.surface,
                "version": widget.version
            ]
            if let sessionId = widget.createdBySession {
                entry["createdBySession"] = sessionId.uuidString.lowercased()
            }
            return entry
        }
    }

    private func autoTitleIfNeeded(
        sessionId: UUID,
        db: Database,
        manager: ClientWSManager
    ) async throws {
        guard let session = try await Session.find(sessionId, on: db),
              session.title == nil || session.title?.isEmpty == true else {
            return
        }
        let firstUserMsg = try await Message.query(on: db)
            .filter(\.$session.$id == sessionId)
            .filter(\.$role == "user")
            .sort(\.$createdAt, .ascending)
            .first()
        if let firstMsg = firstUserMsg, let text = firstMsg.textContent {
            session.title = String(text.prefix(50))
            try await session.save(on: db)
            let lastMsg = try await Message.query(on: db)
                .filter(\.$session.$id == sessionId)
                .sort(\.$createdAt, .descending)
                .first()
            let preview: String? = try lastMsg.map { msg in
                let content = try JSONDecoder().decode(MessageContent.self, from: msg.contentJSON)
                return String(content.previewText.prefix(100))
            }
            await manager.sendToSession(
                .sessionUpdated(session.toDTO(lastMessagePreview: preview)),
                sessionId: sessionId, logger: logger
            )
        }
    }
}
