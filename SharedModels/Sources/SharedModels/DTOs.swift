import Foundation

// MARK: - Session

public struct SessionDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public var title: String?
    public var lastMessageAt: Date?
    public var unreadCount: Int
    public var isPinned: Bool
    public var isArchived: Bool
    public let createdAt: Date

    public init(
        id: UUID,
        title: String? = nil,
        lastMessageAt: Date? = nil,
        unreadCount: Int = 0,
        isPinned: Bool = false,
        isArchived: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.lastMessageAt = lastMessageAt
        self.unreadCount = unreadCount
        self.isPinned = isPinned
        self.isArchived = isArchived
        self.createdAt = createdAt
    }
}

// MARK: - Message

public struct MessageDTO: Codable, Sendable, Identifiable {
    public let id: UUID
    public let sessionId: UUID
    public let role: MessageRole
    public let content: MessageContent
    public let createdAt: Date

    public init(
        id: UUID,
        sessionId: UUID,
        role: MessageRole,
        content: MessageContent,
        createdAt: Date = .now
    ) {
        self.id = id
        self.sessionId = sessionId
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

// MARK: - User

public struct UserDTO: Codable, Sendable, Identifiable {
    public let id: UUID
    public let email: String
    public var displayName: String?
    public var avatarURL: URL?

    public init(id: UUID, email: String, displayName: String? = nil, avatarURL: URL? = nil) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.avatarURL = avatarURL
    }
}

// MARK: - Auth

public struct LoginRequest: Codable, Sendable {
    public let email: String
    public let password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

public struct AuthResponse: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let user: UserDTO

    public init(accessToken: String, refreshToken: String? = nil, user: UserDTO) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.user = user
    }
}

// MARK: - Create/Update

public struct CreateSessionRequest: Codable, Sendable {
    public let title: String?

    public init(title: String? = nil) {
        self.title = title
    }
}

public struct UpdateSessionRequest: Codable, Sendable {
    public var title: String?
    public var isPinned: Bool?
    public var isArchived: Bool?

    public init(title: String? = nil, isPinned: Bool? = nil, isArchived: Bool? = nil) {
        self.title = title
        self.isPinned = isPinned
        self.isArchived = isArchived
    }
}

public struct SendMessageRequest: Codable, Sendable {
    public let content: String

    public init(content: String) {
        self.content = content
    }
}

// MARK: - File System

public struct FileItem: Codable, Sendable, Identifiable {
    public let id: String // relative path
    public let name: String
    public let isDirectory: Bool
    public let size: Int64?
    public let modifiedAt: Date?

    public init(id: String, name: String, isDirectory: Bool, size: Int64? = nil, modifiedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
        self.modifiedAt = modifiedAt
    }
}

// MARK: - Pagination

public struct PaginatedResponse<T: Codable & Sendable>: Codable, Sendable {
    public let items: [T]
    public let total: Int
    public let page: Int
    public let perPage: Int

    public init(items: [T], total: Int, page: Int, perPage: Int) {
        self.items = items
        self.total = total
        self.page = page
        self.perPage = perPage
    }
}

// MARK: - Health

public struct HealthResponse: Codable, Sendable {
    public let status: String
    public let version: String
    public let openclawConnected: Bool

    public init(status: String, version: String, openclawConnected: Bool) {
        self.status = status
        self.version = version
        self.openclawConnected = openclawConnected
    }
}
