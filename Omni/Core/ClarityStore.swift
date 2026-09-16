import Foundation
import Combine

@MainActor
final class ClarityStore: ObservableObject {
    @Published private(set) var archive = ClarityArchive()
    @Published var errorMessage: String?
    @Published private(set) var recoveryRequired = false
    private let fileURL: URL
    var profile: ClarityProfile? { archive.profile }
    var days: [DailyEntry] { archive.days.sorted { $0.date > $1.date } }
    var connections: [ConnectionEntry] { archive.connections.sorted { $0.date > $1.date } }

    init(fileURL: URL? = nil) {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Omni", isDirectory: true)
        #if DEBUG
        if fileURL == nil, let testID = ProcessInfo.processInfo.environment["OMNI_TEST_STORAGE"], UUID(uuidString: testID) != nil {
            self.fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("OmniUITests", isDirectory: true).appendingPathComponent(testID + ".json")
        } else {
            self.fileURL = fileURL ?? folder.appendingPathComponent("clarity-v1.json")
        }
        #else
        self.fileURL = fileURL ?? folder.appendingPathComponent("clarity-v1.json")
        #endif
        if FileManager.default.fileExists(atPath: self.fileURL.path) {
            do {
                archive = try JSONDecoder().decode(ClarityArchive.self, from: Data(contentsOf: self.fileURL))
                guard archive.version == 1 else { throw CocoaError(.fileReadCorruptFile) }
            } catch {
                recoveryRequired = true
                errorMessage = "Your saved journal couldn't be opened. It has been kept intact. Close and reopen Omni, or export a backup before resetting."
            }
        }
    }

    func today(at date: Date = Date()) -> DailyEntry? {
        archive.days.first { $0.day == ReflectionLibrary.dayKey(date) }
    }

    @discardableResult
    func onboard(name: String, focus: LifeFocus) -> Bool {
        var next = archive
        next.profile = ClarityProfile(name: String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60)), focus: focus, createdAt: profile?.createdAt ?? Date())
        return commit(next)
    }

    @discardableResult
    func checkIn(feeling: Feeling, intention: String, date: Date = Date()) -> Bool {
        let clean = intention.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 500 else { return false }
        var next = archive
        let key = ReflectionLibrary.dayKey(date)
        if let i = next.days.firstIndex(where: { $0.day == key }) {
            next.days[i].feeling = feeling
            next.days[i].intention = clean
        } else {
            next.days.append(DailyEntry(day: key, date: date, feeling: feeling, focus: profile?.focus ?? .myself, intention: clean))
        }
        return commit(next)
    }

    @discardableResult
    func reflect(entryID: UUID, feeling: Feeling, text: String, completed: Bool) -> Bool {
        var next = archive
        guard let index = next.days.firstIndex(where: { $0.id == entryID }), text.count <= 4000 else { return false }
        next.days[index].eveningFeeling = feeling
        next.days[index].reflection = text.trimmingCharacters(in: .whitespacesAndNewlines)
        next.days[index].completed = completed
        return commit(next)
    }

    func canAddConnection(premium: Bool, now: Date = Date()) -> Bool {
        let used = archive.connectionUsageDays ?? archive.connections.map { ReflectionLibrary.dayKey($0.date) }
        return premium || !used.contains(ReflectionLibrary.dayKey(now))
    }

    @discardableResult
    func addConnection(kind: ConnectionKind, fact: String, feeling: String, need: String, premium: Bool, now: Date = Date()) -> ConnectionEntry? {
        guard canAddConnection(premium: premium, now: now) else { return nil }
        let parts = [fact, feeling, need].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.allSatisfy({ !$0.isEmpty && $0.count <= 1500 }) else { return nil }
        let entry = ConnectionEntry(date: now, kind: kind, fact: parts[0], feeling: parts[1], need: parts[2], takeaway: ReflectionLibrary.guidance(kind: kind, fact: parts[0], feeling: parts[1], need: parts[2]))
        var next = archive
        next.connections.append(entry)
        var used = next.connectionUsageDays ?? archive.connections.map { ReflectionLibrary.dayKey($0.date) }
        let day = ReflectionLibrary.dayKey(now)
        if !used.contains(day) { used.append(day) }
        next.connectionUsageDays = used
        return commit(next) ? entry : nil
    }

    func deleteDay(_ id: UUID) { var next = archive; next.days.removeAll { $0.id == id }; _ = commit(next) }
    func deleteConnection(_ id: UUID) {
        var next = archive
        if next.connectionUsageDays == nil { next.connectionUsageDays = archive.connections.map { ReflectionLibrary.dayKey($0.date) } }
        next.connections.removeAll { $0.id == id }
        _ = commit(next)
    }

    func exportData() throws -> Data {
        if recoveryRequired { return try Data(contentsOf: fileURL) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(archive)
    }

    func reset() -> Bool {
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) { try FileManager.default.removeItem(at: fileURL) }
            archive = ClarityArchive()
            recoveryRequired = false
            errorMessage = nil
            return true
        } catch { errorMessage = "Your data couldn't be erased. Please try again."; return false }
    }

    private func commit(_ next: ClarityArchive) -> Bool {
        guard !recoveryRequired else { return false }
        do {
            let folder = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var protectedFolder = folder
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try protectedFolder.setResourceValues(values)
            let data = try JSONEncoder().encode(next)
            #if os(iOS)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            #else
            try data.write(to: fileURL, options: .atomic)
            #endif
            archive = next
            return true
        } catch { errorMessage = "Your changes couldn't be saved. Please try again before closing Omni."; return false }
    }
}
