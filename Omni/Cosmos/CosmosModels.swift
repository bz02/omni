import Foundation

/// User-selected sign; exact placements still belong to the astronomical service.
enum ZodiacSign: String, Codable, CaseIterable, Identifiable {
    case aries = "Aries", taurus = "Taurus", gemini = "Gemini", cancer = "Cancer"
    case leo = "Leo", virgo = "Virgo", libra = "Libra", scorpio = "Scorpio"
    case sagittarius = "Sagittarius", capricorn = "Capricorn", aquarius = "Aquarius", pisces = "Pisces"
    var id: String { rawValue }
    var symbol: String { ["♈︎", "♉︎", "♊︎", "♋︎", "♌︎", "♍︎", "♎︎", "♏︎", "♐︎", "♑︎", "♒︎", "♓︎"][index] }
    var index: Int { Self.allCases.firstIndex(of: self)! }
    var element: String { ["Fire", "Earth", "Air", "Water"][index % 4] }
}

enum OutfitOccasion: String, CaseIterable, Identifiable {
    case everyday = "Everyday", work = "Work", dateNight = "Date night"
    var id: String { rawValue }
}

struct CosmicOutfit: Equatable {
    let color: String
    let hex: String
    let pieces: [String]
    let intention: String
    let basis: String

    static func make(sign: ZodiacSign, occasion: OutfitOccasion, date: Date, calendar: Calendar = .current) -> Self {
        // Anchor to the civil day's start so a 25-hour DST day keeps one palette.
        let day = calendar.ordinality(of: .day, in: .era, for: calendar.startOfDay(for: date)) ?? 1
        let palettes = [("Plum", "754B7D"), ("Sage", "879F8B"), ("Amber", "C29553"), ("Midnight blue", "354765"), ("Ivory", "DDD5C5"), ("Rose", "B87583"), ("Terracotta", "B46A51")]
        let palette = palettes[(day + sign.index) % palettes.count]
        let pieces: [String]
        switch occasion {
        case .everyday: pieces = ["A \(palette.0.lowercased()) top", "Your favorite straight-leg denim", "Comfortable sneakers", "One accessory you already love"]
        case .work: pieces = ["A \(palette.0.lowercased()) shirt or knit", "Tailored trousers", "A structured layer", "Simple loafers and a watch"]
        case .dateNight: pieces = ["A \(palette.0.lowercased()) statement piece", "A relaxed jacket", "Shoes you can comfortably walk in", "One personal detail with a story"]
        }
        return Self(color: palette.0, hex: palette.1, pieces: pieces,
                    intention: ["Let yourself be seen.", "Choose what feels like you.", "Leave room for a little surprise.", "Comfort can be magnetic."][sign.index % 4],
                    basis: "A daily creative palette for your selected \(sign.rawValue) sign and occasion. Adapt layers to the weather; this is style inspiration, not a planetary calculation.")
    }
}

struct TarotCard: Identifiable, Equatable {
    let id: Int
    let name: String
    let theme: String
    static let deck: [TarotCard] = {
        let major = [
            ("The Fool", "beginnings"), ("The Magician", "initiative"), ("The High Priestess", "intuition"),
            ("The Empress", "nurture"), ("The Emperor", "structure"), ("The Hierophant", "tradition"),
            ("The Lovers", "values and choice"), ("The Chariot", "direction"), ("Strength", "gentle courage"),
            ("The Hermit", "solitude"), ("Wheel of Fortune", "change"), ("Justice", "fairness"),
            ("The Hanged Man", "perspective"), ("Death", "endings and renewal"), ("Temperance", "balance"),
            ("The Devil", "attachments"), ("The Tower", "disruption"), ("The Star", "hope"),
            ("The Moon", "uncertainty"), ("The Sun", "vitality"), ("Judgement", "awakening"), ("The World", "completion")]
        var result = major.enumerated().map { TarotCard(id: $0.offset, name: $0.element.0, theme: $0.element.1) }
        let ranks = ["Ace", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Page", "Knight", "Queen", "King"]
        for (suit, theme) in [("Wands", "creativity and action"), ("Cups", "feelings and connection"), ("Swords", "thought and communication"), ("Pentacles", "resources and everyday life")] {
            for rank in ranks { result.append(TarotCard(id: result.count, name: "\(rank) of \(suit)", theme: theme)) }
        }
        return result
    }()
}

struct TarotDraw: Identifiable, Equatable {
    let position: String
    let card: TarotCard
    let reversed: Bool
    var id: String { position }
    var label: String { "\(card.name) · \(reversed ? "Reversed" : "Upright")" }
    var prompt: String { reversed ? "Where might \(card.theme) need your attention?" : "How could you make room for \(card.theme)?" }

    /// Fisher–Yates without replacement; the system RNG supplies both draw and orientation.
    static func threeCards<R: RandomNumberGenerator>(using rng: inout R) -> [Self] {
        var cards = TarotCard.deck
        for index in stride(from: cards.count - 1, through: 1, by: -1) {
            cards.swapAt(index, Int.random(in: 0...index, using: &rng))
        }
        return zip(["Past", "Present", "Possibility"], cards.prefix(3)).map {
            Self(position: $0.0, card: $0.1, reversed: Bool.random(using: &rng))
        }
    }
}
