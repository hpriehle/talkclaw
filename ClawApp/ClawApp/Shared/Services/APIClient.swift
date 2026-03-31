import Foundation
import SharedModels

/// REST API client for the ClawApp Vapor backend.
final class APIClient: Sendable {
    let baseURL: String
    private let apiKey: String
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(baseURL: String, apiKey: String) {
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.apiKey = apiKey
        self.session = URLSession.shared

        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Health

    func getHealth() async throws -> HealthResponse {
        try await get("/api/v1/health")
    }

    // MARK: - Sessions

    func getSessions() async throws -> [SessionDTO] {
        try await get("/api/v1/sessions")
    }

    func createSession(title: String? = nil) async throws -> SessionDTO {
        try await post("/api/v1/sessions", body: CreateSessionRequest(title: title))
    }

    func updateSession(id: UUID, update: UpdateSessionRequest) async throws -> SessionDTO {
        try await patch("/api/v1/sessions/\(id.uuidString)", body: update)
    }

    func deleteSession(id: UUID) async throws {
        let _: EmptyResponse = try await delete("/api/v1/sessions/\(id.uuidString)")
    }

    // MARK: - Messages

    func getMessages(sessionId: UUID, page: Int = 1, perPage: Int = 50) async throws -> PaginatedResponse<MessageDTO> {
        try await get("/api/v1/sessions/\(sessionId.uuidString)/messages?page=\(page)&perPage=\(perPage)")
    }

    func sendMessage(sessionId: UUID, content: String) async throws -> MessageDTO {
        try await post("/api/v1/sessions/\(sessionId.uuidString)/messages", body: SendMessageRequest(content: content))
    }

    // MARK: - Files

    func listFiles(path: String? = nil) async throws -> [FileItem] {
        let endpoint = path.map { "/api/v1/files/\($0)" } ?? "/api/v1/files"
        return try await get(endpoint)
    }

    func downloadFile(path: String) async throws -> Data {
        let url = URL(string: "\(baseURL)/api/v1/files/\(path)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await session.data(for: request)
        return data
    }

    // MARK: - HTTP Helpers

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try checkResponse(response)
        return try decoder.decode(T.self, from: data)
    }

    private func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        let (data, response) = try await session.data(for: request)
        try checkResponse(response)
        return try decoder.decode(T.self, from: data)
    }

    private func patch<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        let (data, response) = try await session.data(for: request)
        try checkResponse(response)
        return try decoder.decode(T.self, from: data)
    }

    private func delete<T: Decodable>(_ path: String) async throws -> T {
        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try checkResponse(response)
        if data.isEmpty, T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        return try decoder.decode(T.self, from: data)
    }

    private func checkResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    enum APIError: LocalizedError {
        case httpError(statusCode: Int)

        var errorDescription: String? {
            switch self {
            case .httpError(let code): return "HTTP \(code)"
            }
        }
    }
}

struct EmptyResponse: Decodable {}