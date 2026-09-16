import Foundation

struct MemorySettings: Codable, Equatable {
    var enabled = false
    var saveHistory = true
    var allowOnlineConversations = false
}

extension MemorySettings {
    private enum CodingKeys: String, CodingKey { case enabled, saveHistory, allowOnlineConversations }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        saveHistory = try container.decodeIfPresent(Bool.self, forKey: .saveHistory) ?? true
        allowOnlineConversations = try container.decodeIfPresent(Bool.self, forKey: .allowOnlineConversations) ?? false
    }
}

enum MemoryKind: String, Codable, CaseIterable, Identifiable {
    case profile, preference, relationship, goal
    var id: String { rawValue }
    var title: String {
        switch self {
        case .profile: "About me"
        case .preference: "Preferences"
        case .relationship: "Relationships"
        case .goal: "Goals"
        }
    }
}

struct SavedMemory: Codable, Identifiable, Equatable {
    var id = UUID()
    var kind: MemoryKind
    var text: String
    var createdAt = Date()
    var updatedAt = Date()
    var sourceConversationID: UUID?
    var sourceMessageID: UUID?
    var confirmedByUser = true
}

enum MemoryMessageRole: String, Codable {
    case user, assistant
}

struct MemoryMessage: Codable, Identifiable, Equatable {
    var id = UUID()
    var role: MemoryMessageRole
    var text: String
    var date = Date()
    var usedMemoryIDs: [UUID] = []
}

struct MemoryConversation: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var createdAt = Date()
    var updatedAt = Date()
    var messages: [MemoryMessage] = []
}

struct MemoryArchive: Codable, Equatable {
    var version = 1
    var ownerID: UUID
    var settings = MemorySettings()
    var memories: [SavedMemory] = []
    var conversations: [MemoryConversation] = []
}
