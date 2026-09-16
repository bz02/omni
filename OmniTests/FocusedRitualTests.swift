import Foundation
import Testing
@testable import Omni

@Suite("Focused daily content")
struct FocusedRitualTests {
    @Test("Each focus has two weeks of distinct, complete, compact authored content")
    func completeCollections() throws {
        let calendar = try focusedCalendar("UTC")
        let start = try focusedInstant("2026-09-01T12:00:00Z")
        var titlesByFocus: [Set<String>] = []
        for focus in LifeFocus.allCases {
            var titles = Set<String>()
            for offset in 0..<14 {
                let date = try #require(calendar.date(byAdding: .day, value: offset, to: start))
                let ritual = ReflectionLibrary.focusedRitual(for: date, focus: focus, calendar: calendar)
                #expect(ritual.title.count <= 30)
                #expect(ritual.title.split(separator: "\n", omittingEmptySubsequences: false).count <= 2)
                #expect([ritual.eyebrow, ritual.title, ritual.reassurance, ritual.question, ritual.action].allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                let base = ReflectionLibrary.ritual(for: date, calendar: calendar)
                #expect(ritual.element == base.element)
                #expect(ritual.colorHex == base.colorHex)
                #expect(ritual.style == base.style)
                titles.insert(ritual.title)
            }
            #expect(titles.count == 14)
            titlesByFocus.append(titles)
        }
        #expect(titlesByFocus.reduce(into: Set<String>()) { $0.formUnion($1) }.count == 42)
    }

    @Test("Content repeats after fourteen local days and stays fixed within a day")
    func stableRotation() throws {
        let calendar = try focusedCalendar("America/Los_Angeles")
        let morning = try focusedInstant("2026-09-13T07:01:00Z")
        let evening = try focusedInstant("2026-09-14T06:59:00Z")
        let next = try #require(calendar.date(byAdding: .day, value: 1, to: morning))
        let repeatDate = try #require(calendar.date(byAdding: .day, value: 14, to: morning))
        for focus in LifeFocus.allCases {
            let first = ReflectionLibrary.focusedRitual(for: morning, focus: focus, calendar: calendar)
            for sameSlot in [morning, evening, repeatDate] {
                let repeated = ReflectionLibrary.focusedRitual(for: sameSlot, focus: focus, calendar: calendar)
                #expect(repeated.title == first.title)
                #expect(repeated.action == first.action)
            }
            #expect(ReflectionLibrary.focusedRitual(for: next, focus: focus, calendar: calendar).title != first.title)
        }
    }

    @Test("Local date survives DST and calendar preferences while respecting different timezones")
    func calendarAndTimezoneBoundaries() throws {
        let losAngeles = try focusedCalendar("America/Los_Angeles")
        let tokyo = try focusedCalendar("Asia/Tokyo")
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = losAngeles.timeZone
        let beforeMidnight = try focusedInstant("2026-09-13T06:59:59Z")
        let afterMidnight = beforeMidnight.addingTimeInterval(1)
        let beforeClockChange = try focusedInstant("2026-11-01T08:59:59Z")
        let afterClockChange = beforeClockChange.addingTimeInterval(1)
        for focus in LifeFocus.allCases {
            let local = ReflectionLibrary.focusedRitual(for: beforeMidnight, focus: focus, calendar: losAngeles)
            let preference = ReflectionLibrary.focusedRitual(for: beforeMidnight, focus: focus, calendar: buddhist)
            #expect(local.title == preference.title)
            let newDay = ReflectionLibrary.focusedRitual(for: afterMidnight, focus: focus, calendar: losAngeles)
            #expect(local.title != newDay.title)
            #expect(newDay.title == ReflectionLibrary.focusedRitual(for: beforeMidnight, focus: focus, calendar: tokyo).title)
            #expect(ReflectionLibrary.focusedRitual(for: beforeClockChange, focus: focus, calendar: losAngeles).title == ReflectionLibrary.focusedRitual(for: afterClockChange, focus: focus, calendar: losAngeles).title)
        }
    }
}

private func focusedInstant(_ value: String) throws -> Date {
    try #require(ISO8601DateFormatter().date(from: value))
}

private func focusedCalendar(_ timezone: String) throws -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: timezone))
    return calendar
}
