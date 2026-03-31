import SwiftData
import Foundation

@Model
class CachedSession {
    @Attribute(.unique) var id: UUID
    var title: String?
    var lastMessageAt: Date?
    var unreadCount: Int
    var isPinned: Bool
    var isArchived: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \CachedMessage.session)
    var messages: [CachedMessage] = []

    init(id: UUID, title: String? = nil, lastMessageAt: Date? = nil, unreadCount: Int = 0, isPinned: Bool = false, isArchived: Bool = false, createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.lastMessageAt = lastMessageAt
        self.unreadCount = unreadCount
        self.isPinned = isPinned
        self.isArchived = isArchived
        self.createdAt = createdAt
    }
}

@Model
class CachedMessage {
    @Attribute(.unique) var id: UUID
    var sessionId: UUID
    var role: String
    var contentJSON: Data
    var createdAt: Date

    var session: CachedSession?

    init(id: UUID, sessionId: UUID, role: String, contentJSON: Data, createdAt: Date = .now) {
        self.id = id
        self.sessionId = sessionId
        self.role = role
        self.contentJSON = contentJSON
        self.createdAt = createdAt
    }
}