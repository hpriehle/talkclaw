import Foundation
import SharedModels

/// Manages the WebSocket connection to the Vapor backend for real-time chat.
final class ConnectionManager {
    private let serverURL: String
    private let apiKey: String
    private var webSocketTask: URLSessionWebSocketTask?
    private var isListening = false

    var onMessage: ((WSMessage) -> Void)?
    var onDelta: ((WSMessage.ChatDeltaPayload) -> Void)?

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    init(serverURL: String, apiKey: String) {
        self.serverURL = serverURL
        self.apiKey = apiKey
    }

    func connect() {
        let wsURL = serverURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
        guard let url = URL(string: "\(wsURL)/api/v1/ws?token=\(apiKey)") else { return }

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        listenForMessages()
        startPingLoop()
    }

    func disconnect() {
        isListening = false
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
    }

    func sendChat(sessionId: UUID, content: String) {
        let message = WSMessage.sendChat(.init(sessionId: sessionId, content: content))
        send(message)
    }

    private func send(_ message: WSMessage) {
        guard let data = try? encoder.encode(message),
              let text = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(text)) { error in
            if let error {
                print("WS send error: \(error)")
            }
        }
    }

    private func listenForMessages() {
        isListening = true
        webSocketTask?.receive { [weak self] result in
            guard let self, self.isListening else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let wsMsg = try? self.decoder.decode(WSMessage.self, from: data) {
                        DispatchQueue.main.async {
                            self.handleMessage(wsMsg)
                        }
                    }
                default:
                    break
                }
                // Continue listening
                self.listenForMessages()

            case .failure(let error):
                print("WS receive error: \(error)")
                // Attempt reconnect after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    self?.connect()
                }
            }
        }
    }

    private func handleMessage(_ message: WSMessage) {
        switch message {
        case .chatDelta(let delta):
            onDelta?(delta)
        default:
            break
        }
        onMessage?(message)
    }

    private func startPingLoop() {
        DispatchQueue.global().asyncAfter(deadline: .now() + 30) { [weak self] in
            guard let self, self.isListening else { return }
            self.send(.ping)
            self.startPingLoop()
        }
    }
}