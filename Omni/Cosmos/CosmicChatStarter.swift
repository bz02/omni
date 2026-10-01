import Foundation

enum CosmicChatStarter: String, CaseIterable, Identifiable {
    case horoscope = "My daily horoscope"
    case love = "Love & connection"
    case work = "Career & next steps"
    case style = "What should I wear?"
    var id: String {
        switch self { case .horoscope: "horoscope"; case .love: "love"; case .work: "work"; case .style: "style" }
    }
    var icon: String {
        switch self { case .horoscope: "sparkles"; case .love: "heart"; case .work: "sun.max"; case .style: "tshirt" }
    }
    func prompt(date: Date = Date()) -> String {
        let day = date.formatted(date: .complete, time: .omitted)
        let topic: String
        switch self {
        case .horoscope: topic = "Give me a personal horoscope for today, \(day), with a theme, love and work insight, and one practical action."
        case .love: topic = "Help me explore love and connection through astrology today, \(day). Ask about my situation before making it personal."
        case .work: topic = "Help me explore my career energy for today, \(day), through astrology, with a practical next step."
        case .style: topic = "Recommend a zodiac-inspired outfit for today, \(day), using any style preferences I have chosen to save. Ask about occasion and weather if needed."
        }
        return topic
    }
}
