import Vapor
import Fluent
import SharedModels
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct OpenClawChannelClient: Sendable {
    let baseURL: String
    let token: String
    let logger: Logger

    /// Sends a user message to the OpenClaw gateway and streams the response
    /// back to iOS clients via WebSocket in real time.
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

        let messageId = UUID()
        let sessionKey = "talkclaw:dm:\(sessionId.uuidString.lowercased())"

        // Build the request
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            logger.error("Invalid OPENCLAW_URL: \(baseURL)")
            await manager.sendToSession(
                .error(.init(code: 500, message: "Invalid AI backend URL")),
                sessionId: sessionId, logger: logger
            )
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sessionKey, forHTTPHeaderField: "x-openclaw-session-key")

        let body: [String: Any] = [
            "model": "openclaw:main",
            "messages": [["role": "user", "content": content]],
            "stream": true
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                logger.error("OpenClaw returned HTTP \(status)")
                await manager.sendToSession(
                    .error(.init(code: status, message: "AI backend returned HTTP \(status)")),
                    sessionId: sessionId, logger: logger
                )
                return
            }

            var accumulatedText = ""

            for try await line in bytes.lines {
                guard line.hasPrefix("data: ") else { continue }
                let payload = String(line.dropFirst(6))

                if payload == "[DONE]" {
                    break
                }

                guard let data = payload.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let delta = choices.first?["delta"] as? [String: Any],
                      let content = delta["content"] as? String else {
                    continue
                }

                accumulatedText += content

                // Send delta to iOS clients
                let deltaPayload = WSMessage.ChatDeltaPayload(
                    sessionId: sessionId,
                    delta: content,
                    messageId: messageId
                )
                await manager.sendToSession(
                    .chatDelta(deltaPayload),
                    sessionId: sessionId, logger: logger
                )
            }

            // Save the complete message
            guard !accumulatedText.isEmpty else {
                logger.warning("OpenClaw returned empty response for session \(sessionId)")
                return
            }

            let message = try Message(
                id: messageId,
                sessionId: sessionId,
                role: .assistant,
                content: .text(accumulatedText)
            )
            try await message.save(on: db)

            if let session = try await Session.find(sessionId, on: db) {
                session.lastMessageAt = Date()
                try await session.save(on: db)
            }

            // Send chatComplete to iOS clients
            let dto = try message.toDTO()
            await manager.sendToSession(
                .chatComplete(dto),
                sessionId: sessionId, logger: logger
            )

            // Auto-title if needed
            try? await autoTitleIfNeeded(sessionId: sessionId, db: db, manager: manager)

        } catch {
            logger.error("OpenClaw streaming error: \(error)")
            await manager.sendToSession(
                .error(.init(code: 500, message: "AI streaming failed: \(error.localizedDescription)")),
                sessionId: sessionId, logger: logger
            )
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
