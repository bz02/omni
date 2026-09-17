import Foundation
import Testing
@testable import Omni

@Suite("Private memory ownership and controls")
@MainActor
struct MemoryTests {
    @Test("A local owner is stable across restart and reset; consent starts off")
    func ownershipAndDefaults() throws {
        let files = try MemoryTestFiles()
        defer { files.cleanUp() }
        let store = MemoryStore(fileURL: files.url)
        #expect(!store.settings.enabled)
        #expect(store.settings.saveHistory)
        #expect(!store.settings.allowOnlineConversations)
        #expect(!store.recoveryRequired)
        let reopened = MemoryStore(fileURL: files.url)
        #expect(reopened.ownerID == store.ownerID)
        #expect(reopened.reset())
        #expect(MemoryStore(fileURL: files.url).ownerID == store.ownerID)
    }

    @Test("An explicit different owner cannot read, export, overwrite, or erase this file")
    func ownerIsolation() throws {
        let files = try MemoryTestFiles()
        defer { files.cleanUp() }
        let first = MemoryStore(fileURL: files.url, ownerID: UUID())
        #expect(first.setSettings(MemorySettings(enabled: true), premium: true))
        #expect(first.addMemory(kind: .profile, text: "I live in Seattle.", premium: true) != nil)
        let original = try Data(contentsOf: files.url)
        let secondID = UUID()
        let second = MemoryStore(fileURL: files.url, ownerID: secondID)
        #expect(second.ownerID == secondID)
        #expect(second.recoveryRequired)
        #expect(second.memories.isEmpty)
        #expect(second.conversations.isEmpty)
        #expect(!second.setSettings(MemorySettings(enabled: true), premium: true))
        #expect(!second.reset())
        #expect(throws: (any Error).self) { try second.exportData() }
        #expect(try Data(contentsOf: files.url) == original)
        #expect(MemoryStore(fileURL: files.url, ownerID: first.ownerID).memories.count == 1)
    }

    @Test("Consent, entitlement, temporary mode, and history are independent gates")
    func privacyGates() throws {
        let files = try MemoryTestFiles()
        defer { files.cleanUp() }
        let store = MemoryStore(fileURL: files.url)
        #expect(!store.setSettings(MemorySettings(enabled: true), premium: false))
        #expect(!store.setSettings(MemorySettings(allowOnlineConversations: true), premium: false))
        #expect(store.addMemory(kind: .profile, text: "My name is Avery.", premium: true) == nil)
        #expect(store.setSettings(MemorySettings(enabled: true, allowOnlineConversations: true), premium: true))
        let item = try #require(store.addMemory(kind: .profile, text: "My name is Avery.", premium: true))
        #expect(store.addMemory(kind: .goal, text: "Try a pottery class.", premium: false) == nil)
        #expect(store.addMemory(kind: .goal, text: "Try a pottery class.", premium: true, temporary: true) == nil)
        #expect(store.retrieve(query: "Avery", premium: false).isEmpty)
        #expect(store.retrieve(query: "Avery", premium: true, temporary: true).isEmpty)
        #expect(store.retrieve(query: "Avery", premium: true).map(\.id) == [item.id])

        #expect(store.setSettings(MemorySettings(enabled: false, allowOnlineConversations: true), premium: false))
        #expect(store.settings.allowOnlineConversations)
        #expect(store.retrieve(query: "Avery", premium: true).isEmpty)
        #expect(store.addMemory(kind: .goal, text: "Try a pottery class.", premium: true) == nil)
        #expect(store.memories.count == 1)
        let conversation = MemoryConversation(title: "A conversation", messages: [MemoryMessage(role: .user, text: "What could I ask on a first date?")])
        #expect(store.saveConversation(conversation, premium: true))
        #expect(!store.saveConversation(conversation, premium: false))
        #expect(!store.saveConversation(conversation, premium: true, temporary: true))
        #expect(store.setSettings(MemorySettings(saveHistory: false), premium: false))
        #expect(!store.saveConversation(conversation, premium: true))
        #expect(store.conversations.count == 1)
    }

    @Test("Saved profile facts, settings, conversations, and source provenance survive restart")
    func roundTrip() throws {
        let files = try MemoryTestFiles()
        defer { files.cleanUp() }
        let store = MemoryStore(fileURL: files.url)
        #expect(store.setSettings(MemorySettings(enabled: true, allowOnlineConversations: true), premium: true))
        let profile = try #require(store.addMemory(kind: .profile, text: "  Call me Avery.  ", premium: true))
        let originalMessage = MemoryMessage(role: .user, text: "I prefer a walk to a noisy bar.")
        let conversation = MemoryConversation(title: "  A first date  ", messages: [originalMessage, MemoryMessage(role: .assistant, text: "What would make a walk feel comfortable?", usedMemoryIDs: [profile.id])])
        #expect(store.saveConversation(conversation, premium: true))
        let preference = try #require(store.rememberMessage(conversationID: conversation.id, messageID: originalMessage.id, kind: .preference, premium: true))
        let reopened = MemoryStore(fileURL: files.url, ownerID: store.ownerID)
        #expect(reopened.settings == store.settings)
        #expect(reopened.memories.count == 2)
        #expect(reopened.memories.first(where: { $0.id == profile.id })?.text == "Call me Avery.")
        #expect(reopened.memories.first(where: { $0.id == preference.id })?.sourceMessageID == originalMessage.id)
        #expect(reopened.conversations.first?.title == "A first date")
        #expect(reopened.conversations.first?.messages.last?.usedMemoryIDs == [profile.id])
    }

    @Test("Only explicit user messages may become memories; no automatic extraction occurs")
    func explicitUserSourceOnly() throws {
        let files = try MemoryTestFiles()
        defer { files.cleanUp() }
        let store = MemoryStore(fileURL: files.url)
        #expect(store.setSettings(MemorySettings(enabled: true), premium: true))
        let user = MemoryMessage(role: .user, text: "I am hoping to date more slowly.")
        let assistant = MemoryMessage(role: .assistant, text: "You could have an avoidant attachment style.")
        let conversation = MemoryConversation(title: "My pace", messages: [user, assistant])
        #expect(store.saveConversation(conversation, premium: true))
        #expect(store.memories.isEmpty)
        #expect(store.rememberMessage(conversationID: conversation.id, messageID: assistant.id, kind: .profile, premium: true) == nil)
        #expect(store.addMemory(kind: .profile, text: "An invented label", premium: true, sourceConversationID: conversation.id, sourceMessageID: assistant.id) == nil)
        let saved = try #require(store.rememberMessage(conversationID: conversation.id, messageID: user.id, kind: .goal, premium: true))
        #expect(saved.text == user.text)
        #expect(saved.confirmedByUser)
        let duplicate = try #require(store.rememberMessage(conversationID: conversation.id, messageID: user.id, kind: .goal, premium: true))
        #expect(duplicate.id == saved.id)
        #expect(store.memories.count == 1)
    }

    @Test("Former subscribers can edit, export and delete without reactivating memory")
    func managementAfterExpiry() throws {
        let files = try MemoryTestFiles()
        defer { files.cleanUp() }
        let store = MemoryStore(fileURL: files.url)
        #expect(store.setSettings(MemorySettings(enabled: true), premium: true))
        let item = try #require(store.addMemory(kind: .preference, text: "I like morning dates.", premium: true))
        #expect(store.setSettings(MemorySettings(enabled: false), premium: false))
        #expect(store.updateMemory(id: item.id, kind: .preference, text: "  I prefer evening dates now.  "))
        #expect(store.memories.first?.text == "I prefer evening dates now.")
        let exported = try store.exportData()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive = try decoder.decode(MemoryArchive.self, from: exported)
        #expect(archive.ownerID == store.ownerID)
        #expect(archive.memories.first?.id == item.id)
        #expect(store.deleteMemory(item.id))
        #expect(MemoryStore(fileURL: files.url).memories.isEmpty)
    }

    @Test("Deleting a conversation removes its memories and leaves manually added facts intact")
    func conversationCascade() throws {
        let files = try MemoryTestFiles()
        defer { files.cleanUp() }
        let store = MemoryStore(fileURL: files.url)
        #expect(store.setSettings(MemorySettings(enabled: true), premium: true))
        let independent = try #require(store.addMemory(kind: .profile, text: "I live in Seattle.", premium: true))
        let first = try savedConversation(store, text: "I like quiet walks.")
        let second = try savedConversation(store, text: "I like coffee dates.")
        #expect(store.memories.count == 3)
        #expect(store.deleteConversation(first.id))
        #expect(store.memories.count == 2)
        #expect(!store.memories.contains(where: { $0.sourceConversationID == first.id }))
        #expect(store.memories.contains(where: { $0.id == independent.id }))
        #expect(store.conversations.map(\.id) == [second.id])
        #expect(store.clearConversations())
        let reopened = MemoryStore(fileURL: files.url)
        #expect(reopened.conversations.isEmpty)
        #expect(reopened.memories.map(\.id) == [independent.id])
    }

    @Test("Deleting memory immediately removes retrieval and stale reply citations, not chat text")
    func memoryDeletionAndHistory() throws {
        let files = try MemoryTestFiles()
        defer { files.cleanUp() }
        let store = MemoryStore(fileURL: files.url)
        #expect(store.setSettings(MemorySettings(enabled: true), premium: true))
        let item = try #require(store.addMemory(kind: .profile, text: "Call me Avery.", premium: true))
        let conversation = MemoryConversation(title: "A note", messages: [MemoryMessage(role: .user, text: "Hello"), MemoryMessage(role: .assistant, text: "Hello Avery.", usedMemoryIDs: [item.id])])
        #expect(store.saveConversation(conversation, premium: true))
        #expect(store.retrieve(query: "Avery", premium: true).count == 1)
        #expect(store.deleteMemory(item.id))
        #expect(store.retrieve(query: "Avery", premium: true).isEmpty)
        #expect(store.conversations.first?.messages.last?.usedMemoryIDs.isEmpty == true)
        #expect(store.conversations.first?.messages.last?.text == "Hello Avery.")
        #expect(store.addMemory(kind: .profile, text: "Another fact", premium: true) != nil)
        #expect(store.clearMemories())
        #expect(store.memories.isEmpty)
        #expect(store.conversations.count == 1)
    }

    @Test("Retrieval is deterministic, relevant and limited to six items and 3,000 characters")
    func boundedRetrieval() throws {
        let files = try MemoryTestFiles()
        defer { files.cleanUp() }
        let store = MemoryStore(fileURL: files.url)
        #expect(store.setSettings(MemorySettings(enabled: true), premium: true))
        let relevant = try #require(store.addMemory(kind: .preference, text: "For coffee dates I prefer quiet cafés.", premium: true))
        #expect(store.addMemory(kind: .goal, text: "Learn watercolor painting.", premium: true) != nil)
        for number in 0..<10 {
            #expect(store.addMemory(kind: .profile, text: "Profile fact \(number) " + String(repeating: "x", count: 480), premium: true) != nil)
        }
        let result = store.retrieve(query: "coffee dates", premium: true)
        #expect(result.first?.id == relevant.id)
        #expect(!result.contains(where: { $0.kind == .goal }))
        #expect(result.count <= 6)
        #expect(result.map(\.text).joined().count <= 3000)
        #expect(result == store.retrieve(query: "coffee dates", premium: true))
        #expect(result == MemoryStore(fileURL: files.url).retrieve(query: "coffee dates", premium: true))
        let emptyQuery = store.retrieve(query: "", premium: true)
        #expect(emptyQuery.count <= 6)
        #expect(emptyQuery.map(\.text).joined().count <= 3000)
    }

    @Test("Invalid input and failed writes never publish unsaved state")
    func invalidAndFailedWrites() throws {
        let files = try MemoryTestFiles()
        defer { files.cleanUp() }
        let store = MemoryStore(fileURL: files.url)
        #expect(store.setSettings(MemorySettings(enabled: true), premium: true))
        let original = try Data(contentsOf: files.url)
        let revision = store.revision
        #expect(store.addMemory(kind: .profile, text: " \n ", premium: true) == nil)
        #expect(store.addMemory(kind: .profile, text: String(repeating: "x", count: 1001), premium: true) == nil)
        #expect(!store.saveConversation(MemoryConversation(title: "Empty"), premium: true))
        let duplicate = MemoryMessage(role: .user, text: "A message")
        #expect(!store.saveConversation(MemoryConversation(title: "Duplicate IDs", messages: [duplicate, duplicate]), premium: true))
        #expect(try Data(contentsOf: files.url) == original)
        #expect(store.revision == revision)

        try FileManager.default.removeItem(at: files.url)
        try FileManager.default.createDirectory(at: files.url, withIntermediateDirectories: true)
        #expect(store.addMemory(kind: .profile, text: "Must not appear saved", premium: true) == nil)
        #expect(store.errorMessage != nil)
        #expect(store.memories.isEmpty)
        #expect(store.revision == revision)
    }

    @Test("Corrupt and future versions are preserved until an explicit reset")
    func recoveryProtection() throws {
        let future = MemoryArchive(version: 999, ownerID: UUID())
        for original in [Data("{broken json".utf8), try JSONEncoder().encode(future)] {
            let files = try MemoryTestFiles()
            defer { files.cleanUp() }
            try original.write(to: files.url)
            let store = MemoryStore(fileURL: files.url)
            #expect(store.recoveryRequired)
            #expect(!store.setSettings(MemorySettings(enabled: true), premium: true))
            #expect(!store.clearMemories())
            #expect(!store.clearConversations())
            #expect(try store.exportData() == original)
            #expect(try Data(contentsOf: files.url) == original)
            let owner = store.ownerID
            #expect(store.reset())
            let reopened = MemoryStore(fileURL: files.url)
            #expect(!reopened.recoveryRequired)
            #expect(reopened.ownerID == owner)
            #expect(reopened.memories.isEmpty)
        }
    }

    @Test("Online consent defaults off when restoring earlier settings; mutations advance revision")
    func consentMigrationAndRevision() throws {
        let decoded = try JSONDecoder().decode(MemorySettings.self, from: Data("{\"enabled\":true,\"saveHistory\":false}".utf8))
        #expect(decoded.enabled)
        #expect(!decoded.saveHistory)
        #expect(!decoded.allowOnlineConversations)
        let files = try MemoryTestFiles()
        defer { files.cleanUp() }
        let store = MemoryStore(fileURL: files.url)
        var revision = store.revision
        #expect(store.setSettings(MemorySettings(enabled: true), premium: true))
        #expect(store.revision > revision)
        revision = store.revision
        #expect(store.addMemory(kind: .goal, text: "Take more walks.", premium: true) != nil)
        #expect(store.revision > revision)
        revision = store.revision
        #expect(store.reset())
        #expect(store.revision > revision)
        #expect(store.settings == MemorySettings())
    }
}

@MainActor
private func savedConversation(_ store: MemoryStore, text: String) throws -> MemoryConversation {
    let message = MemoryMessage(role: .user, text: text)
    let conversation = MemoryConversation(title: "A reflection", messages: [message])
    #expect(store.saveConversation(conversation, premium: true))
    #expect(store.rememberMessage(conversationID: conversation.id, messageID: message.id, kind: .preference, premium: true) != nil)
    return conversation
}

private struct MemoryTestFiles {
    let directory: URL
    var url: URL { directory.appendingPathComponent("memory-v1.json") }
    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("Omni-MemoryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    func cleanUp() { try? FileManager.default.removeItem(at: directory) }
}
