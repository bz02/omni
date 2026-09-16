import Foundation
import Testing
@testable import Omni

@Suite("Local dates and daily rituals")
struct ClarityCalendarTests {
    @Test("The same instant belongs to each time zone's own local day")
    func timeZoneDayBoundaries() throws {
        let moment = try instant("2026-09-13T06:59:59Z")
        let losAngeles = try calendar(timeZone: "America/Los_Angeles")
        let tokyo = try calendar(timeZone: "Asia/Tokyo")
        #expect(ReflectionLibrary.dayKey(moment, calendar: losAngeles) == "2026-09-12")
        #expect(ReflectionLibrary.dayKey(moment, calendar: tokyo) == "2026-09-13")
        #expect(ReflectionLibrary.dayKey(moment.addingTimeInterval(1), calendar: losAngeles) == "2026-09-13")
    }

    @Test("Calendar preferences cannot create a second local day or ritual")
    func calendarPreferenceDoesNotChangeIdentity() throws {
        let now = try instant("2026-09-13T19:00:00Z")
        let gregorian = try calendar(timeZone: "America/Los_Angeles")
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.locale = Locale(identifier: "th_TH")
        buddhist.timeZone = gregorian.timeZone
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = gregorian.timeZone

        for preference in [gregorian, buddhist, iso] {
            #expect(ReflectionLibrary.dayKey(now, calendar: preference) == "2026-09-13")
            #expect(ReflectionLibrary.ritual(for: now, calendar: preference).title == ReflectionLibrary.ritual(for: now, calendar: gregorian).title)
        }
    }

    @Test("A ritual remains stable through daylight-saving clock changes")
    func ritualStaysStableAcrossDST() throws {
        let local = try calendar(timeZone: "America/Los_Angeles")
        let pairs = [
            ("2026-03-08T09:59:59Z", "2026-03-08T10:00:00Z"),
            ("2026-11-01T08:59:59Z", "2026-11-01T09:00:00Z")
        ]
        for (before, after) in pairs {
            let first = try instant(before)
            let second = try instant(after)
            #expect(ReflectionLibrary.dayKey(first, calendar: local) == ReflectionLibrary.dayKey(second, calendar: local))
            #expect(ReflectionLibrary.ritual(for: first, calendar: local).title == ReflectionLibrary.ritual(for: second, calendar: local).title)
        }
    }

    @Test("Rituals follow local calendar days, including leap days and pre-epoch dates")
    func ritualRotation() throws {
        let utc = try calendar(timeZone: "UTC")
        let leapDay = try instant("2024-02-29T00:00:00Z")
        let evening = try instant("2024-02-29T23:59:59Z")
        let nextDay = try instant("2024-03-01T00:00:00Z")
        let fiveDaysLater = try instant("2024-03-05T12:00:00Z")
        let today = ReflectionLibrary.ritual(for: leapDay, calendar: utc)
        #expect(today.title == ReflectionLibrary.ritual(for: evening, calendar: utc).title)
        #expect(today.title != ReflectionLibrary.ritual(for: nextDay, calendar: utc).title)
        #expect(today.title == ReflectionLibrary.ritual(for: fiveDaysLater, calendar: utc).title)

        let beforeEpoch = ReflectionLibrary.ritual(for: try instant("1969-12-31T12:00:00Z"), calendar: utc)
        #expect(!beforeEpoch.title.isEmpty)
        #expect(ReflectionLibrary.rituals.contains { $0.title == beforeEpoch.title })
    }
}

@Suite("Private journal persistence")
@MainActor
struct ClarityPersistenceTests {
    @Test("A fresh store restores the profile, journal, reflection, and connection")
    func roundTrip() throws {
        let files = try TemporaryArchive()
        defer { files.cleanUp() }
        let store = ClarityStore(fileURL: files.fileURL)
        let now = try localDate(hour: 12)
        #expect(store.onboard(name: "  Avery  ", focus: .dating))
        #expect(store.checkIn(feeling: .hopeful, intention: "  Ask an honest question.  ", date: now))
        let entry = try #require(store.today(at: now))
        #expect(store.reflect(entryID: entry.id, feeling: .grounded, text: "  I felt heard.  ", completed: true))
        let connection = try #require(store.addConnection(kind: .afterDate, fact: "We took a walk.", feeling: "Comfortable", need: "Another conversation", premium: false, now: now))

        let reopened = ClarityStore(fileURL: files.fileURL)
        #expect(!reopened.recoveryRequired)
        #expect(reopened.profile?.name == "Avery")
        #expect(reopened.profile?.focus == .dating)
        let saved = try #require(reopened.today(at: now))
        #expect(saved.id == entry.id)
        #expect(saved.date == now)
        #expect(saved.intention == "Ask an honest question.")
        #expect(saved.focus == .dating)
        #expect(saved.eveningFeeling == .grounded)
        #expect(saved.reflection == "I felt heard.")
        #expect(saved.completed)
        #expect(reopened.connections.count == 1)
        #expect(reopened.connections.first?.id == connection.id)
        #expect(reopened.connections.first?.takeaway == connection.takeaway)
    }

    @Test("Editing a same-day check-in preserves its identity and evening reflection")
    func sameDayUpsert() throws {
        let files = try TemporaryArchive()
        defer { files.cleanUp() }
        let store = ClarityStore(fileURL: files.fileURL)
        let morning = try localDate(hour: 8)
        let evening = try localDate(hour: 21)
        #expect(store.checkIn(feeling: .unsettled, intention: "Take my time.", date: morning))
        let original = try #require(store.today(at: morning))
        #expect(store.reflect(entryID: original.id, feeling: .okay, text: "I paused.", completed: true))
        #expect(store.checkIn(feeling: .hopeful, intention: "  Be curious.  ", date: evening))

        let saved = try #require(ClarityStore(fileURL: files.fileURL).today(at: evening))
        #expect(store.days.count == 1)
        #expect(saved.id == original.id)
        #expect(saved.date == original.date)
        #expect(saved.feeling == .hopeful)
        #expect(saved.intention == "Be curious.")
        #expect(saved.reflection == "I paused.")
        #expect(saved.eveningFeeling == .okay)
        #expect(saved.completed)
    }

    @Test("Crossing local midnight creates a new check-in")
    func midnightCreatesNewEntry() throws {
        let files = try TemporaryArchive()
        defer { files.cleanUp() }
        let store = ClarityStore(fileURL: files.fileURL)
        let before = try localDate(hour: 23, minute: 59, second: 59)
        let after = before.addingTimeInterval(1)
        #expect(store.checkIn(feeling: .okay, intention: "Rest.", date: before))
        #expect(store.checkIn(feeling: .grounded, intention: "Begin again.", date: after))
        #expect(store.days.count == 2)
        let first = try #require(store.today(at: before))
        let second = try #require(store.today(at: after))
        #expect(first.id != second.id)
        #expect(first.day != second.day)
        #expect(store.days.first?.id == second.id)
    }

    @Test("Invalid edits leave the persisted journal unchanged")
    func invalidEditsAreRejected() throws {
        let files = try TemporaryArchive()
        defer { files.cleanUp() }
        let store = ClarityStore(fileURL: files.fileURL)
        #expect(store.checkIn(feeling: .okay, intention: "Keep this."))
        let id = try #require(store.days.first?.id)
        let before = try Data(contentsOf: files.fileURL)
        #expect(!store.checkIn(feeling: .tender, intention: " \n "))
        #expect(!store.checkIn(feeling: .tender, intention: String(repeating: "a", count: 501)))
        #expect(!store.reflect(entryID: id, feeling: .tender, text: String(repeating: "a", count: 4001), completed: true))
        #expect(!store.reflect(entryID: UUID(), feeling: .tender, text: "Unknown entry", completed: true))
        #expect(try Data(contentsOf: files.fileURL) == before)
        #expect(store.days.first?.intention == "Keep this.")
        #expect(store.days.first?.eveningFeeling == nil)
    }

    @Test("Deletion persists and does not remove other records")
    func deletingRecords() throws {
        let files = try TemporaryArchive()
        defer { files.cleanUp() }
        let store = ClarityStore(fileURL: files.fileURL)
        let now = try localDate(hour: 12)
        let tomorrow = try #require(Calendar.current.date(byAdding: .day, value: 1, to: now))
        #expect(store.checkIn(feeling: .okay, intention: "First", date: now))
        #expect(store.checkIn(feeling: .hopeful, intention: "Second", date: tomorrow))
        let removedID = try #require(store.today(at: now)?.id)
        let keptID = try #require(store.today(at: tomorrow)?.id)
        let connection = try #require(addConnection(to: store, now: now))
        store.deleteDay(removedID)
        store.deleteConnection(connection.id)

        let reopened = ClarityStore(fileURL: files.fileURL)
        #expect(reopened.days.map(\.id) == [keptID])
        #expect(reopened.connections.isEmpty)
        #expect(reopened.today(at: now) == nil)
    }

    @Test("Restart and deleting a connection cannot refund today's free use")
    func dailyQuotaSurvivesRestartAndDeletion() throws {
        let files = try TemporaryArchive()
        defer { files.cleanUp() }
        let now = try localDate(hour: 23, minute: 59, second: 59)
        let store = ClarityStore(fileURL: files.fileURL)
        #expect(store.canAddConnection(premium: false, now: now))
        let first = try #require(addConnection(to: store, now: now))
        #expect(addConnection(to: store, now: now) == nil)
        let reopened = ClarityStore(fileURL: files.fileURL)
        #expect(!reopened.canAddConnection(premium: false, now: now))
        reopened.deleteConnection(first.id)
        #expect(reopened.connections.isEmpty)
        #expect(!reopened.canAddConnection(premium: false, now: now))

        let afterDeletionRestart = ClarityStore(fileURL: files.fileURL)
        #expect(addConnection(to: afterDeletionRestart, now: now) == nil)
        let tomorrow = now.addingTimeInterval(1)
        #expect(afterDeletionRestart.canAddConnection(premium: false, now: tomorrow))
        #expect(addConnection(to: afterDeletionRestart, now: tomorrow) != nil)
    }

    @Test("Legacy archives preserve used quota when their last connection is deleted")
    func legacyQuotaMigration() throws {
        let files = try TemporaryArchive()
        defer { files.cleanUp() }
        let now = try localDate(hour: 12)
        let oldConnection = ConnectionEntry(date: now, kind: .uncertainty, fact: "No reply", feeling: "Unsure", need: "Take a walk", takeaway: "A saved reflection")
        let legacy = ClarityArchive(connections: [oldConnection])
        let encoded = try JSONEncoder().encode(legacy)
        var json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json.removeValue(forKey: "connectionUsageDays")
        try JSONSerialization.data(withJSONObject: json).write(to: files.fileURL)

        let migrated = ClarityStore(fileURL: files.fileURL)
        #expect(!migrated.recoveryRequired)
        #expect(!migrated.canAddConnection(premium: false, now: now))
        migrated.deleteConnection(oldConnection.id)
        let reopened = ClarityStore(fileURL: files.fileURL)
        #expect(reopened.connections.isEmpty)
        #expect(!reopened.canAddConnection(premium: false, now: now))
        #expect(addConnection(to: reopened, now: now) == nil)
    }

    @Test("Premium permits additional connections; invalid input consumes no free use")
    func premiumAndValidation() throws {
        let files = try TemporaryArchive()
        defer { files.cleanUp() }
        let store = ClarityStore(fileURL: files.fileURL)
        let now = try localDate(hour: 12)
        #expect(store.addConnection(kind: .beforeDate, fact: "  ", feeling: "Nervous", need: "A pause", premium: false, now: now) == nil)
        #expect(store.canAddConnection(premium: false, now: now))
        #expect(addConnection(to: store, now: now) != nil)
        #expect(store.canAddConnection(premium: true, now: now))
        #expect(addConnection(to: store, premium: true, now: now) != nil)
        #expect(addConnection(to: store, premium: true, now: now) != nil)
        #expect(ClarityStore(fileURL: files.fileURL).connections.count == 3)
        #expect(!store.canAddConnection(premium: false, now: now))
    }

    @Test("Explicit erase-all removes journal data and its local quota")
    func explicitReset() throws {
        let files = try TemporaryArchive()
        defer { files.cleanUp() }
        let store = ClarityStore(fileURL: files.fileURL)
        let now = try localDate(hour: 12)
        #expect(store.onboard(name: "Avery", focus: .relationship))
        #expect(store.checkIn(feeling: .okay, intention: "Listen.", date: now))
        #expect(addConnection(to: store, now: now) != nil)
        #expect(store.reset())
        let reopened = ClarityStore(fileURL: files.fileURL)
        #expect(reopened.profile == nil)
        #expect(reopened.days.isEmpty)
        #expect(reopened.connections.isEmpty)
        #expect(reopened.canAddConnection(premium: false, now: now))
    }

    @Test("Corrupt and unsupported archives stay recoverable and cannot be overwritten")
    func damagedArchiveProtection() throws {
        let malformed = Data("{this is not a valid journal".utf8)
        let futureVersion = try JSONEncoder().encode(ClarityArchive(version: 999, profile: ClarityProfile(name: "Keep this", focus: .myself)))
        for original in [malformed, futureVersion] {
            let files = try TemporaryArchive()
            defer { files.cleanUp() }
            try original.write(to: files.fileURL)
            let store = ClarityStore(fileURL: files.fileURL)
            #expect(store.recoveryRequired)
            #expect(store.errorMessage != nil)
            #expect(!store.onboard(name: "Replacement", focus: .dating))
            #expect(!store.checkIn(feeling: .okay, intention: "Replacement"))
            #expect(addConnection(to: store, premium: true, now: Date()) == nil)
            store.deleteDay(UUID())
            store.deleteConnection(UUID())
            #expect(try store.exportData() == original)
            #expect(try Data(contentsOf: files.fileURL) == original)
            #expect(ClarityStore(fileURL: files.fileURL).recoveryRequired)
        }
    }
}

@Suite("Grounded weekly summaries")
struct ClarityWeeklySummaryTests {
    @Test("Fewer than three check-ins yields a low-data message, not a trend")
    func insufficientData() throws {
        let local = try calendar(timeZone: "America/Los_Angeles")
        let now = try instant("2026-09-13T19:00:00Z")
        let noData = WeeklySummary(entries: [], now: now, calendar: local)
        #expect(noData.checkIns == 0)
        #expect(noData.reflections == 0)
        #expect(noData.followThrough == 0)
        #expect(noData.mostCommonFeeling == nil)
        #expect(noData.observations.contains("Three check-ins"))
        let yesterday = try #require(local.date(byAdding: .day, value: -1, to: now))
        let entries = [day(at: yesterday, feeling: .tender), day(at: now, feeling: .grounded)]
        for count in 1...2 {
            let summary = WeeklySummary(entries: Array(entries.prefix(count)), now: now, calendar: local)
            #expect(summary.checkIns == count)
            #expect(summary.observations == noData.observations)
            #expect(!summary.observations.contains("most often"))
        }
    }

    @Test("The seven local days use calendar boundaries across DST and real entry values")
    func weeklyWindowAndCounts() throws {
        let local = try calendar(timeZone: "America/Los_Angeles")
        let start = try instant("2026-03-03T08:00:00Z")
        let end = try instant("2026-03-10T07:00:00Z")
        let now = end.addingTimeInterval(-0.5)
        let middle = try instant("2026-03-08T19:00:00Z")
        let entries = [
            day(at: start.addingTimeInterval(-1), feeling: .tender, evening: .tender, completed: true),
            day(at: start, feeling: .hopeful, evening: .grounded, completed: true),
            day(at: middle, feeling: .grounded),
            day(at: end.addingTimeInterval(-1), feeling: .hopeful, evening: .okay),
            day(at: end, feeling: .tender, evening: .tender, completed: true)
        ]
        let summary = WeeklySummary(entries: entries, now: now, calendar: local)
        #expect(summary.checkIns == 3)
        #expect(summary.reflections == 2)
        #expect(summary.followThrough == 1)
        #expect(summary.mostCommonFeeling == .hopeful)
        #expect(summary.observations.contains("hopeful"))
        #expect(summary.observations.contains("3 check-ins"))
    }
}

private func instant(_ iso8601: String) throws -> Date {
    try #require(ISO8601DateFormatter().date(from: iso8601))
}

private func calendar(timeZone: String) throws -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: timeZone))
    return calendar
}

private func localDate(hour: Int, minute: Int = 0, second: Int = 0) throws -> Date {
    // Store APIs intentionally use the device's local zone; never mutate global time-zone state.
    var gregorian = Calendar(identifier: .gregorian)
    gregorian.timeZone = Calendar.current.timeZone
    return try #require(gregorian.date(from: DateComponents(year: 2026, month: 9, day: 13, hour: hour, minute: minute, second: second)))
}

private func day(at date: Date, feeling: Feeling, evening: Feeling? = nil, completed: Bool = false) -> DailyEntry {
    DailyEntry(day: "fixture", date: date, feeling: feeling, focus: .myself, intention: "A real intention", eveningFeeling: evening, completed: completed)
}

@MainActor
private func addConnection(to store: ClarityStore, premium: Bool = false, now: Date) -> ConnectionEntry? {
    store.addConnection(kind: .uncertainty, fact: "I haven't heard back.", feeling: "I'm imagining rejection.", need: "Put my phone away for a while.", premium: premium, now: now)
}

private struct TemporaryArchive {
    let directory: URL
    var fileURL: URL { directory.appendingPathComponent("clarity-v1.json") }

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("Omni-ClarityTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: directory)
    }
}
