import Foundation
import Testing
@testable import Omni

@Suite("Additive Cosmos journeys")
struct CosmosTests {
    struct Seeded: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }
    @Test func deckAndDraws() {
        #expect(TarotCard.deck.count == 78)
        #expect(Set(TarotCard.deck.map(\.id)).count == 78)
        #expect(Set(TarotCard.deck.map(\.name)).count == 78)
        var seen = Set<Int>()
        for seed in 1...200 {
            var rng = Seeded(state: UInt64(seed))
            let draw = TarotDraw.threeCards(using: &rng)
            #expect(draw.count == 3)
            #expect(Set(draw.map(\.card.id)).count == 3)
            #expect(draw.map(\.position) == ["Past", "Present", "Possibility"])
            seen.formUnion(draw.map(\.card.id))
        }
        #expect(seen.count == 78)
    }
    @Test func stableOnSameCivilDayAndDifferentOccasions() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let a = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 0))!
        let b = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 23))!
        let first = CosmicOutfit.make(sign: .libra, occasion: .work, date: a, calendar: calendar)
        #expect(first == CosmicOutfit.make(sign: .libra, occasion: .work, date: b, calendar: calendar))
        #expect(first.pieces != CosmicOutfit.make(sign: .libra, occasion: .dateNight, date: a, calendar: calendar).pieces)
        let next = calendar.date(byAdding: .day, value: 1, to: a)!
        #expect(first.color != CosmicOutfit.make(sign: .libra, occasion: .work, date: next, calendar: calendar).color)
    }
}
