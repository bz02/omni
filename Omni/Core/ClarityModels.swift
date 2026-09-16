import Foundation

enum LifeFocus: String, Codable, CaseIterable, Identifiable {
    case myself = "Myself", dating = "Dating", relationship = "My relationship"
    var id: String { rawValue }
    var icon: String { switch self { case .myself: "sun.max"; case .dating: "sparkles"; case .relationship: "heart" } }
    var subtitle: String { switch self { case .myself: "Find my footing"; case .dating: "Stay open. Stay me."; case .relationship: "Feel closer, with care" } }
}

enum Feeling: Int, Codable, CaseIterable, Identifiable {
    case tender = 1, unsettled, okay, hopeful, grounded
    var id: Int { rawValue }
    var label: String { switch self { case .tender: "Tender"; case .unsettled: "Unsettled"; case .okay: "Okay"; case .hopeful: "Hopeful"; case .grounded: "Grounded" } }
    var symbol: String { switch self { case .tender: "cloud.rain"; case .unsettled: "wind"; case .okay: "cloud.sun"; case .hopeful: "sun.haze"; case .grounded: "sun.max" } }
}

struct ClarityProfile: Codable {
    var name: String
    var focus: LifeFocus
    var createdAt: Date = Date()
}

struct DailyEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var day: String
    var date: Date
    var feeling: Feeling
    var focus: LifeFocus
    var intention: String
    var eveningFeeling: Feeling?
    var reflection: String = ""
    var completed: Bool = false
}

enum ConnectionKind: String, Codable, CaseIterable, Identifiable {
    case beforeDate = "Before a date"
    case afterDate = "After a date"
    case conversation = "Say it clearly"
    case uncertainty = "When you're overthinking"
    var id: String { rawValue }
    var icon: String { switch self { case .beforeDate: "sparkles"; case .afterDate: "moon.stars"; case .conversation: "bubble.left.and.bubble.right"; case .uncertainty: "cloud.sun" } }
    var subtitle: String { switch self { case .beforeDate: "Less performing. More connecting."; case .afterDate: "How did you feel around them?"; case .conversation: "Turn a feeling into a kind, clear ask."; case .uncertainty: "Separate what happened from what you fear." } }
    var firstPrompt: String { switch self { case .beforeDate: "What are you looking forward to?"; case .afterDate: "What actually happened?"; case .conversation: "What happened, without guessing their intent?"; case .uncertainty: "What do you know for sure?" } }
    var secondPrompt: String { switch self { case .beforeDate: "What feels a little vulnerable?"; case .afterDate: "How did you feel in their company?"; case .conversation: "How did it make you feel?"; case .uncertainty: "What story is your mind adding?" } }
    var thirdPrompt: String { switch self { case .beforeDate: "What would help you feel like yourself?"; case .afterDate: "What would you like to learn or ask next?"; case .conversation: "What specific change would you like to ask for?"; case .uncertainty: "What is one thing within your control?" } }
}

struct ConnectionEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()
    var kind: ConnectionKind
    var fact: String
    var feeling: String
    var need: String
    var takeaway: String
}

struct ClarityArchive: Codable {
    var version: Int = 1
    var profile: ClarityProfile?
    var days: [DailyEntry] = []
    var connections: [ConnectionEntry] = []
    var connectionUsageDays: [String]? = []
}

struct DailyRitual {
    var eyebrow: String
    var title: String
    var reassurance: String
    var question: String
    var action: String
    var element: String
    var colorName: String
    var colorHex: String
    var style: String
}

enum ReflectionLibrary {
    // Authored reflection prompts. These are not calculated transits or predictions.
    static let rituals: [DailyRitual] = [
        .init(eyebrow: "A LITTLE SPACE", title: "You don't have to\nearn your ease.", reassurance: "Being understood starts with listening to yourself. There is room for how you feel today.", question: "Where could you stop performing and be a little more yourself?", action: "Leave one small thing imperfect today.", element: "Earth", colorName: "Soft sand", colorHex: "C2A789", style: "A soft knit, relaxed layers, and something that feels familiar."),
        .init(eyebrow: "YOUR OWN PACE", title: "A pause is\nan answer, too.", reassurance: "You can care about someone and still take time to work out what you need.", question: "What deserves a thoughtful reply instead of an immediate one?", action: "Take three unhurried breaths before your next reply.", element: "Water", colorName: "Ink blue", colorHex: "455C78", style: "An easy blue layer and a silhouette you can breathe in."),
        .init(eyebrow: "ROOM TO GROW", title: "Stay curious.\nStay yourself.", reassurance: "You don't need to be the most interesting person in the room. A real question is a good beginning.", question: "What would you ask if you weren't trying to make the perfect impression?", action: "Ask one question you actually want the answer to.", element: "Wood", colorName: "Sage green", colorHex: "829783", style: "A sage accent, a cotton shirt, and your everyday shoes."),
        .init(eyebrow: "A WARMER WAY", title: "Let a little\njoy find you.", reassurance: "You can want more from life without turning today into a project to fix.", question: "What small thing would feel good even if no one else saw it?", action: "Make ten minutes for something you enjoy.", element: "Fire", colorName: "Warm coral", colorHex: "C97559", style: "A warm coral accent on a comfortable neutral base."),
        .init(eyebrow: "GENTLE BOUNDARIES", title: "Kind can\nalso be clear.", reassurance: "Your needs don't become too much just because they're hard to say out loud.", question: "What is one kind, clear ask you could make today?", action: "Replace one hint with a specific request.", element: "Metal", colorName: "Pearl white", colorHex: "C9C8BE", style: "A crisp white layer and one simple silver accessory.")
    ]

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let c = gregorian.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func ritual(for date: Date, calendar: Calendar = .current) -> DailyRitual {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let c = gregorian.dateComponents([.year, .month, .day], from: date)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let normalized = utc.date(from: c) ?? date
        let days = Int(floor(normalized.timeIntervalSince1970 / 86400))
        return rituals[((days % rituals.count) + rituals.count) % rituals.count]
    }

    static func guidance(kind: ConnectionKind, fact: String, feeling: String, need: String) -> String {
        switch kind {
        case .beforeDate:
            return "Your intention: \(need)\n\nTry asking: ‘What's something you've been enjoying lately?’ Notice whether you feel free to be curious, disagree, and take your time. You are getting to know them, too."
        case .afterDate:
            return "What you noticed: \(feeling)\n\nYour next question: \(need)\n\nChemistry and comfort can tell different stories. One date is a moment, not a verdict. Look for consistency over time."
        case .conversation:
            return "‘When \(sentenceFragment(fact)), I feel \(sentenceFragment(feeling)). Would you be open to \(sentenceFragment(need))?’\n\nRead this in your own voice. Make the request specific, leave room for their answer, and choose a moment when you both have space."
        case .uncertainty:
            return "The fact: \(fact)\n\nThe interpretation: \(feeling)\n\nThe next step you control: \(need)\n\nA feeling is real. It isn't proof of what another person thinks. You can leave room for more information."
        }
    }

    private static func sentenceFragment(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
    }
}

struct WeeklySummary {
    let checkIns: Int
    let reflections: Int
    let followThrough: Int
    let mostCommonFeeling: Feeling?
    let observations: String

    init(entries: [DailyEntry], now: Date = Date(), calendar: Calendar = .current) {
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let recent = entries.filter { $0.date >= start && $0.date < end }
        checkIns = recent.count
        reflections = recent.filter { $0.eveningFeeling != nil }.count
        followThrough = recent.filter(\.completed).count
        let counts = Dictionary(grouping: recent, by: \.feeling).mapValues(\.count)
        mostCommonFeeling = counts.sorted { $0.value == $1.value ? $0.key.rawValue < $1.key.rawValue : $0.value > $1.value }.first?.key
        if recent.count < 3 {
            observations = "Your story is still taking shape. Three check-ins will give you a first look at your week."
        } else {
            observations = "You described yourself as \(mostCommonFeeling?.label.lowercased() ?? "present") most often across \(recent.count) check-ins. You returned to \(reflections) evening reflections. What was happening around those moments?"
        }
    }
}
