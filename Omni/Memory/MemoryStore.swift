import Foundation
import Combine
import CryptoKit

/// One protected archive: a guest owner by default, or an authenticated account
/// UUID supplied by the account integration through forAccount(_:).
@MainActor
final class MemoryStore: ObservableObject {
    @Published private(set) var archive: MemoryArchive
    @Published var errorMessage: String?
    @Published private(set) var recoveryRequired = false
    @Published private(set) var revision = 0
    private let fileURL: URL
    private var ownerAccessDenied = false
    @Published private var syncState: SyncState?

    var cloudRevision: Int? { syncState?.cloudRevision }
    var hasUnsyncedChanges: Bool {
        guard let syncState, let data = try? snapshotData() else { return true }
        return Self.digest(data) != syncState.baselineHash
    }

    var ownerID: UUID { archive.ownerID }
    var settings: MemorySettings { archive.settings }
    var memories: [SavedMemory] { archive.memories.sorted(by: Self.newestMemory) }
    var conversations: [MemoryConversation] {
        archive.conversations.sorted {
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    init(fileURL: URL? = nil, ownerID: UUID? = nil) {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Omni", isDirectory: true)
        #if DEBUG
        if fileURL == nil, let testID = ProcessInfo.processInfo.environment["OMNI_TEST_STORAGE"], UUID(uuidString: testID) != nil {
            self.fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("OmniUITests", isDirectory: true)
                .appendingPathComponent(testID + "-memory.json")
        } else {
            self.fileURL = fileURL ?? folder.appendingPathComponent("memory-v1.json")
        }
        #else
        self.fileURL = fileURL ?? folder.appendingPathComponent("memory-v1.json")
        #endif
        archive = MemoryArchive(ownerID: ownerID ?? UUID())
        guard FileManager.default.fileExists(atPath: self.fileURL.path) else {
            _ = commit(archive)
            return
        }
        do {
            let data = try Data(contentsOf: self.fileURL)
            // Check ownership before decoding private content, including unsupported versions.
            let header = try JSONDecoder().decode(ArchiveHeader.self, from: data)
            if let ownerID, header.ownerID != ownerID {
                ownerAccessDenied = true
                throw CocoaError(.fileReadNoPermission)
            }
            archive.ownerID = header.ownerID
            guard header.version == 1 else { throw CocoaError(.fileReadCorruptFile) }
            let saved = try JSONDecoder().decode(MemoryArchive.self, from: data)
            guard Self.valid(saved) else { throw CocoaError(.fileReadCorruptFile) }
            let metadata = try JSONDecoder().decode(DiskMetadata.self, from: data).localSync
            if let metadata {
                guard metadata.cloudRevision >= 0, metadata.baselineHash.count == 64 else { throw CocoaError(.fileReadCorruptFile) }
            }
            archive = saved
            syncState = metadata
        } catch {
            recoveryRequired = true
            errorMessage = ownerAccessDenied
                ? "This memory file belongs to a different local profile. It has not been opened or changed."
                : "Your memory file couldn't be opened. It has been kept intact. Export a backup before resetting."
        }
    }

    /// Account caches never load or import the guest archive.
    static func forAccount(_ accountID: UUID, directory: URL? = nil) -> MemoryStore {
        MemoryStore(fileURL: accountFile(accountID, directory: directory), ownerID: accountID)
    }

    static func removeAccountCache(_ accountID: UUID, directory: URL? = nil) throws {
        let file = accountFile(accountID, directory: directory)
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
    }

    private static func accountFile(_ accountID: UUID, directory: URL?) -> URL {
        let folder: URL
        if let directory { folder = directory }
        else {
            #if DEBUG
            if let testID = ProcessInfo.processInfo.environment["OMNI_TEST_STORAGE"], UUID(uuidString: testID) != nil {
                folder = FileManager.default.temporaryDirectory.appendingPathComponent("OmniUITests", isDirectory: true)
                    .appendingPathComponent(testID + "-accounts", isDirectory: true)
            } else {
                folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("Omni/Accounts", isDirectory: true)
            }
            #else
            folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Omni/Accounts", isDirectory: true)
            #endif
        }
        return folder.appendingPathComponent(accountID.uuidString.lowercased() + "-memory.json")
    }

    /// Device consent and sync bookkeeping are deliberately absent from the cloud payload.
    func snapshotData() throws -> Data {
        guard !recoveryRequired else { throw CocoaError(.fileReadCorruptFile) }
        return try Self.cloudData(archive)
    }

    @discardableResult
    func applyCloudSnapshot(_ snapshot: MemoryCloudSnapshot, expectedLocalRevision: Int) -> Bool {
        guard expectedLocalRevision == revision else { return fail("Your local memory changed while downloading. Review it before replacing it.") }
        guard snapshot.revision >= (cloudRevision ?? 0) else { return fail("The cloud returned an older revision. Your local copy has been kept intact.") }
        var incoming = snapshot.archive ?? MemoryArchive(ownerID: ownerID)
        guard incoming.version == 1, incoming.ownerID == ownerID, Self.valid(incoming), Self.validCloudReferences(incoming) else {
            return fail("This cloud memory couldn't be verified for your account. Your local data is unchanged.")
        }
        incoming.settings.allowOnlineConversations = settings.allowOnlineConversations
        do {
            let data = try Self.cloudData(incoming)
            let baseline = SyncState(cloudRevision: snapshot.revision, baselineHash: Self.digest(data))
            return commit(incoming, syncState: baseline)
        } catch { return fail("This cloud memory is too large or couldn't be read. Your local data is unchanged.") }
    }

    @discardableResult
    func recordSuccessfulUpload(remoteRevision: Int, expectedLocalRevision: Int) -> Bool {
        guard remoteRevision >= (cloudRevision ?? 0), expectedLocalRevision == revision else {
            return fail("Your local memory changed during upload. The cloud has the earlier version; review it before syncing again.")
        }
        do {
            let baseline = SyncState(cloudRevision: remoteRevision, baselineHash: Self.digest(try snapshotData()))
            return commit(archive, syncState: baseline)
        } catch { return fail("The upload finished, but its local sync record couldn't be saved. Review cloud memory before retrying.") }
    }

    @discardableResult
    func setSettings(_ settings: MemorySettings, premium: Bool) -> Bool {
        guard !settings.enabled || archive.settings.enabled || premium else {
            return fail("Omni Plus is required to turn on memory.")
        }
        guard !settings.allowOnlineConversations || archive.settings.allowOnlineConversations || premium else {
            return fail("Omni Plus is required to turn on online conversations.")
        }
        var next = archive
        next.settings = settings
        return commit(next)
    }

    @discardableResult
    func addMemory(kind: MemoryKind, text: String, premium: Bool, temporary: Bool = false,
                   sourceConversationID: UUID? = nil, sourceMessageID: UUID? = nil) -> SavedMemory? {
        guard canWriteMemory(premium: premium, temporary: temporary) else { return nil }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 1000 else {
            _ = fail("Write a memory between 1 and 1,000 characters.")
            return nil
        }
        guard Self.validSource(conversationID: sourceConversationID, messageID: sourceMessageID, in: archive) else {
            _ = fail("The original message is no longer available. Save this as a new personal memory instead.")
            return nil
        }
        if let existing = archive.memories.first(where: {
            $0.kind == kind && $0.text == clean && $0.sourceConversationID == sourceConversationID && $0.sourceMessageID == sourceMessageID
        }) { return existing }
        let now = Date()
        let memory = SavedMemory(kind: kind, text: clean, createdAt: now, updatedAt: now,
                                 sourceConversationID: sourceConversationID, sourceMessageID: sourceMessageID)
        var next = archive
        next.memories.append(memory)
        return commit(next) ? memory : nil
    }

    /// Only an explicit user action saves facts. Assistant messages are never treated as facts.
    @discardableResult
    func rememberMessage(conversationID: UUID, messageID: UUID, kind: MemoryKind, premium: Bool) -> SavedMemory? {
        guard let conversation = archive.conversations.first(where: { $0.id == conversationID }),
              let message = conversation.messages.first(where: { $0.id == messageID && $0.role == .user }) else {
            _ = fail("Only your own saved messages can become a memory.")
            return nil
        }
        return addMemory(kind: kind, text: message.text, premium: premium,
                         sourceConversationID: conversationID, sourceMessageID: messageID)
    }

    @discardableResult
    func updateMemory(id: UUID, kind: MemoryKind, text: String) -> Bool {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 1000 else { return fail("Write a memory between 1 and 1,000 characters.") }
        var next = archive
        guard let index = next.memories.firstIndex(where: { $0.id == id }) else { return fail("This memory is no longer available.") }
        next.memories[index].kind = kind
        next.memories[index].text = clean
        next.memories[index].updatedAt = Date()
        return commit(next)
    }

    /// History and long-term memory are separate controls. Temporary conversations never persist.
    @discardableResult
    func saveConversation(_ conversation: MemoryConversation, premium: Bool, temporary: Bool = false) -> Bool {
        guard premium else { return fail("Omni Plus is required to save new conversations.") }
        guard !temporary else { return fail("Temporary conversations are not saved.") }
        guard settings.saveHistory else { return fail("Conversation history is turned off.") }
        var clean = conversation
        clean.title = clean.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.title.isEmpty, clean.title.count <= 160, !clean.messages.isEmpty,
              Self.unique(clean.messages.map(\.id)), clean.messages.allSatisfy({ !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.text.count <= 16000 }) else {
            return fail("This conversation couldn't be saved. Include a title and a message within the text limit.")
        }
        let existingIDs = Set(archive.memories.map(\.id))
        for index in clean.messages.indices {
            // Preserve existing citations while preventing new references to unavailable memories.
            clean.messages[index].usedMemoryIDs = clean.messages[index].usedMemoryIDs.filter { existingIDs.contains($0) }
        }
        var next = archive
        if let index = next.conversations.firstIndex(where: { $0.id == clean.id }) {
            let previous = next.conversations[index]
            clean.createdAt = previous.createdAt
            let sourceIDs = Set(next.memories.filter { $0.sourceConversationID == clean.id }.compactMap(\.sourceMessageID))
            guard sourceIDs.allSatisfy({ sourceID in
                clean.messages.contains(where: { $0.id == sourceID && $0.role == .user })
            }) else { return fail("A remembered message cannot be removed through a conversation update. Delete its memory first.") }
            next.conversations[index] = clean
        } else {
            next.conversations.append(clean)
        }
        return commit(next)
    }

    /// Retrieval returns user-approved data, never instructions. Callers must mark it as such in prompts.
    func retrieve(query: String, premium: Bool, temporary: Bool = false) -> [SavedMemory] {
        guard premium, settings.enabled, !temporary, !recoveryRequired else { return [] }
        let queryTokens = Self.tokens(query)
        let normalQuery = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let scored = archive.memories.compactMap { memory -> (SavedMemory, Int)? in
            guard memory.confirmedByUser else { return nil }
            let textTokens = Self.tokens(memory.text)
            let intersection = queryTokens.intersection(textTokens).count
            let categoryMatch = queryTokens.contains(memory.kind.rawValue) ? 3 : 0
            let exact = !normalQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                memory.text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")).contains(normalQuery) ? 4 : 0
            let relevance = intersection + categoryMatch + exact
            // Basic profile facts are useful context; other facts must match the current topic.
            guard relevance > 0 || memory.kind == .profile || queryTokens.isEmpty else { return nil }
            let categoryWeight: Int
            switch memory.kind { case .profile: categoryWeight = 4; case .preference: categoryWeight = 3; case .relationship: categoryWeight = 2; case .goal: categoryWeight = 1 }
            return (memory, relevance * 10 + categoryWeight)
        }.sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            return Self.newestMemory($0.0, $1.0)
        }
        var result: [SavedMemory] = []
        var remaining = 3000
        for (memory, _) in scored where result.count < 6 {
            guard memory.text.count <= remaining else { continue }
            result.append(memory)
            remaining -= memory.text.count
        }
        return result
    }

    @discardableResult
    func deleteMemory(_ id: UUID) -> Bool {
        var next = archive
        next.memories.removeAll { $0.id == id }
        Self.removeStaleReferences(from: &next)
        return commit(next)
    }

    @discardableResult
    func deleteConversation(_ id: UUID) -> Bool {
        var next = archive
        next.conversations.removeAll { $0.id == id }
        next.memories.removeAll { $0.sourceConversationID == id }
        Self.removeStaleReferences(from: &next)
        return commit(next)
    }

    @discardableResult
    func clearMemories() -> Bool {
        var next = archive
        next.memories = []
        Self.removeStaleReferences(from: &next)
        return commit(next)
    }

    @discardableResult
    func clearConversations() -> Bool {
        var next = archive
        next.conversations = []
        next.memories.removeAll { $0.sourceConversationID != nil }
        return commit(next)
    }

    func exportData() throws -> Data {
        guard !ownerAccessDenied else { throw CocoaError(.fileReadNoPermission) }
        if recoveryRequired { return try Data(contentsOf: fileURL) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(archive)
    }

    @discardableResult
    func reset() -> Bool {
        guard !ownerAccessDenied else { return fail("This file belongs to a different local profile and cannot be reset here.") }
        // Explicit reset is the only write permitted over a damaged or unsupported archive.
        return commit(MemoryArchive(ownerID: ownerID), allowRecoveryReset: true)
    }

    private func canWriteMemory(premium: Bool, temporary: Bool) -> Bool {
        guard premium else { return fail("Omni Plus is required to save new memories.") }
        guard settings.enabled else { return fail("Turn on memory before saving a new memory.") }
        guard !temporary else { return fail("Temporary conversations cannot create memories.") }
        return !recoveryRequired
    }

    private func fail(_ message: String) -> Bool { errorMessage = message; return false }

    private func commit(_ next: MemoryArchive, allowRecoveryReset: Bool = false, syncState incomingSync: SyncState? = nil) -> Bool {
        guard !ownerAccessDenied, !recoveryRequired || allowRecoveryReset else { return false }
        do {
            let folder = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var protectedFolder = folder
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try protectedFolder.setResourceValues(values)
            let updatedSync = incomingSync ?? syncState
            let encoded = try JSONEncoder().encode(next)
            var object = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
            if let updatedSync {
                object["localSync"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(updatedSync))
            }
            let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            #if os(iOS)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            #else
            try data.write(to: fileURL, options: .atomic)
            #endif
            archive = next
            syncState = updatedSync
            revision &+= 1
            recoveryRequired = false
            errorMessage = nil
            return true
        } catch { return fail("Your memory changes couldn't be saved. Please try again before closing Omni.") }
    }

    private struct ArchiveHeader: Decodable { let version: Int; let ownerID: UUID }
    private struct SyncState: Codable { let cloudRevision: Int; let baselineHash: String }
    private struct DiskMetadata: Decodable { let localSync: SyncState? }

    private static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

    private static func cloudData(_ archive: MemoryArchive) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var object = try JSONSerialization.jsonObject(with: encoder.encode(archive)) as! [String: Any]
        var settings = object["settings"] as! [String: Any]
        settings.removeValue(forKey: "allowOnlineConversations")
        object["settings"] = settings
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        guard data.count <= 1_900_000 else { throw CocoaError(.fileWriteOutOfSpace) }
        return data
    }

    private static func validCloudReferences(_ archive: MemoryArchive) -> Bool {
        let memories = Set(archive.memories.map(\.id))
        let messages = archive.conversations.flatMap(\.messages)
        guard unique(messages.map(\.id)), archive.memories.count <= 2000, archive.conversations.count <= 2000,
              archive.conversations.allSatisfy({ $0.messages.count <= 2000 }) else { return false }
        return messages.allSatisfy {
            $0.usedMemoryIDs.count <= 6 && unique($0.usedMemoryIDs) && Set($0.usedMemoryIDs).isSubset(of: memories) &&
            ($0.role == .assistant || $0.usedMemoryIDs.isEmpty)
        }
    }

    private static func valid(_ archive: MemoryArchive) -> Bool {
        guard unique(archive.memories.map(\.id)), unique(archive.conversations.map(\.id)) else { return false }
        return archive.memories.allSatisfy {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.text.count <= 1000 && $0.confirmedByUser &&
            validSource(conversationID: $0.sourceConversationID, messageID: $0.sourceMessageID, in: archive)
        } && archive.conversations.allSatisfy {
            !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.title.count <= 160 && !$0.messages.isEmpty && unique($0.messages.map(\.id)) &&
            $0.messages.allSatisfy { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.text.count <= 16000 }
        }
    }

    private static func validSource(conversationID: UUID?, messageID: UUID?, in archive: MemoryArchive) -> Bool {
        if conversationID == nil && messageID == nil { return true }
        guard let conversationID, let messageID else { return false }
        return archive.conversations.first(where: { $0.id == conversationID })?.messages.contains(where: { $0.id == messageID && $0.role == .user }) == true
    }

    private static func unique(_ ids: [UUID]) -> Bool { Set(ids).count == ids.count }

    private static func newestMemory(_ lhs: SavedMemory, _ rhs: SavedMemory) -> Bool {
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func removeStaleReferences(from archive: inout MemoryArchive) {
        let ids = Set(archive.memories.map(\.id))
        for conversationIndex in archive.conversations.indices {
            for messageIndex in archive.conversations[conversationIndex].messages.indices {
                archive.conversations[conversationIndex].messages[messageIndex].usedMemoryIDs.removeAll { !ids.contains($0) }
            }
        }
    }

    private static func tokens(_ text: String) -> Set<String> {
        let normalized = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let stopWords: Set<String> = ["a", "an", "the", "i", "my", "me", "is", "am", "are", "was", "to", "for", "of", "and", "or", "on", "in", "it", "that", "this", "with", "you", "your", "have", "do", "how", "what"]
        var result: Set<String> = []
        for word in normalized.components(separatedBy: CharacterSet.alphanumerics.inverted) where !word.isEmpty && !stopWords.contains(word) {
            result.insert(word)
            let characters = Array(word)
            if characters.count > 1, word.unicodeScalars.contains(where: { (0x3400...0x9fff).contains(Int($0.value)) }) {
                for index in 0..<(characters.count - 1) { result.insert(String(characters[index...index + 1])) }
            }
        }
        return result
    }
}
