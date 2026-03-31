import SwiftUI
import Combine
import SharedModels

@MainActor
final class AppState: ObservableObject {
    @Published var serverURL: String = ""
    @Published var apiKey: String = ""
    @Published var isConnected: Bool = false
    @Published var connectionStatus: ConnectionStatus = .disconnected

    @Published var sessions: [SessionDTO] = []
    @Published var currentSession: SessionDTO?
    @Published var currentUser: UserDTO?

    /// Persisted ID of the last session the user had open
    var lastOpenedSessionId: UUID? {
        get {
            guard let str = UserDefaults.standard.string(forKey: "lastOpenedSessionId"),
                  let id = UUID(uuidString: str) else { return nil }
            return id
        }
        set {
            UserDefaults.standard.set(newValue?.uuidString, forKey: "lastOpenedSessionId")
        }
    }

    enum ConnectionStatus: String {
        case disconnected
        case connecting
        case connected
        case error
    }

    private var connectionManager: ConnectionManager?
    private var apiClient: APIClient?

    init() {
        // Load stored credentials
        if let url = KeychainService.load(key: "server_url"),
           let key = KeychainService.load(key: "api_key"),
           !url.isEmpty, !key.isEmpty {
            self.serverURL = url
            self.apiKey = key
            self.isConnected = true
            setupServices()
        }
    }

    func connect(serverURL: String, apiKey: String) async throws {
        self.serverURL = serverURL
        self.apiKey = apiKey

        let client = APIClient(baseURL: serverURL, apiKey: apiKey)

        // Verify connection
        let health = try await client.getHealth()
        guard health.status == "ok" else {
            throw ConnectionError.serverUnavailable
        }

        // Store credentials
        KeychainService.save(key: "server_url", value: serverURL)
        KeychainService.save(key: "api_key", value: apiKey)

        self.apiClient = client
        self.isConnected = true
        setupServices()
    }

    func disconnect() {
        connectionManager?.disconnect()
        connectionManager = nil
        apiClient = nil
        isConnected = false
        serverURL = ""
        apiKey = ""
        sessions = []
        currentUser = nil
        KeychainService.delete(key: "server_url")
        KeychainService.delete(key: "api_key")
    }

    func loadSessions() async {
        guard let client = apiClient else { return }
        do {
            sessions = try await client.getSessions()
        } catch {
            print("Failed to load sessions: \(error)")
        }
    }

    func createSession(title: String? = nil) async throws -> SessionDTO {
        guard let client = apiClient else { throw ConnectionError.notConnected }
        let session = try await client.createSession(title: title)
        sessions.insert(session, at: 0)
        return session
    }

    func getAPIClient() -> APIClient? { apiClient }
    func getConnectionManager() -> ConnectionManager? { connectionManager }

    /// Record which session the user last opened (persisted across launches)
    func recordSessionOpened(_ id: UUID) {
        lastOpenedSessionId = id
    }

    /// Guarantees at least one session exists and returns the best one to navigate to.
    /// Retries up to 3 times on failure, then creates a local placeholder as last resort.
    func ensureSession() async -> SessionDTO {
        for attempt in 0..<3 {
            if attempt > 0 {
                try? await Task.sleep(for: .seconds(1))
            }

            await loadSessions()

            let sorted = sessions.sorted { a, b in
                if a.isPinned != b.isPinned { return a.isPinned }
                let dateA = a.lastMessageAt ?? a.createdAt
                let dateB = b.lastMessageAt ?? b.createdAt
                return dateA > dateB
            }

            // Try restoring the last-opened session
            if let lastId = lastOpenedSessionId,
               let found = sorted.first(where: { $0.id == lastId }) {
                return found
            }

            // Fall back to the most recent session
            if let first = sorted.first {
                return first
            }

            // No sessions — try to create one
            if let created = try? await createSession(title: nil) {
                return created
            }
        }

        // Last resort — local placeholder so the UI is never empty
        let placeholder = SessionDTO(
            id: UUID(),
            title: "New Chat",
            lastMessageAt: nil,
            unreadCount: 0,
            isPinned: false,
            isArchived: false,
            createdAt: Date()
        )
        sessions = [placeholder]
        return placeholder
    }

    private func setupServices() {
        let client = APIClient(baseURL: serverURL, apiKey: apiKey)
        self.apiClient = client

        let manager = ConnectionManager(serverURL: serverURL, apiKey: apiKey)
        self.connectionManager = manager
        manager.onMessage = { [weak self] message in
            Task { @MainActor in
                self?.handleWSMessage(message)
            }
        }
        manager.connect()
        connectionStatus = .connected
    }

    private func handleWSMessage(_ message: WSMessage) {
        switch message {
        case .chatDelta(let delta):
            NotificationCenter.default.post(
                name: .chatDelta,
                object: nil,
                userInfo: ["delta": delta]
            )
        case .chatComplete(let msg):
            NotificationCenter.default.post(
                name: .chatComplete,
                object: nil,
                userInfo: ["message": msg]
            )
        case .sessionUpdated(let session):
            if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[idx] = session
            }
        default:
            break
        }
    }

    enum ConnectionError: LocalizedError {
        case serverUnavailable
        case notConnected

        var errorDescription: String? {
            switch self {
            case .serverUnavailable: return "Could not connect to server"
            case .notConnected: return "Not connected to a server"
            }
        }
    }
}

extension Notification.Name {
    static let newMessage = Notification.Name("ClawApp.newMessage")
    static let chatDelta = Notification.Name("ClawApp.chatDelta")
    static let chatComplete = Notification.Name("ClawApp.chatComplete")
}