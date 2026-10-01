import SwiftUI

/// Additive entry point: the existing five tabs and archives remain unchanged.
struct CosmosScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sign: ZodiacSign = .aries
    @State private var occasion: OutfitOccasion = .everyday
    @State private var question = ""
    @State private var draws: [TarotDraw] = []
    @State private var drawnQuestion = ""
    @State private var showChart = false
    @State private var showImageStudio = false
    @State private var showProfile = false
    @State private var chat: CosmicConversationDraft?
    @State private var poster: Image?
    @State private var posterError: String?
    @State private var now = Date()
    @Environment(\.scenePhase) private var phase
    private var outfit: CosmicOutfit { .make(sign: sign, occasion: occasion, date: now) }
    private let night = Color(hex: "160D27")
    private let gold = Color(hex: "D4AF37")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("OMNI · COSMOS").font(.caption.monospaced()).tracking(3).foregroundStyle(gold)
                        Text("A little magic.\nAll your own.").font(.system(size: 39, design: .serif))
                        Text("Explore your sign, draw your cards, and dress for the day you want to meet.").foregroundStyle(.white.opacity(0.75))
                        HStack {
                            Text(sign.symbol).font(.system(size: 64))
                            Spacer()
                            Picker("Your Sun sign", selection: $sign) { ForEach(ZodiacSign.allCases) { Text($0.rawValue).tag($0) } }
                                .tint(gold).accessibilityIdentifier("cosmos.sign")
                        }
                        Text("Choose the Sun sign you know. This selection is not a calculated birth chart.").font(.caption).foregroundStyle(.white.opacity(0.65))
                    }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(night, in: RoundedRectangle(cornerRadius: 24)).foregroundStyle(.white)

                    OmniCard {
                        Eyebrow(text: "YOUR COSMIC PROFILE")
                        Text("A reading that remembers you.").font(OmniTheme.title(27))
                        Text("Choose which birth details and style preferences Omni can remember for future conversations.").font(.subheadline)
                        Button("Personalize my cosmos", systemImage: "person.crop.circle.badge.checkmark") { showProfile = true }.accessibilityIdentifier("cosmos.profile")
                    }

                    OmniCard {
                        Eyebrow(text: "YOUR DAILY HOROSCOPE")
                        Text("What might today hold?").font(OmniTheme.title(27))
                        Text("Explore love, work and your next small step with Omni's AI astrologer.").font(.subheadline)
                        Button("Ask about my day", systemImage: "sparkles") {
                            chat = CosmicConversationDraft(text: "Give me a warm, specific daily horoscope for \(sign.rawValue) on \(now.formatted(date: .complete, time: .omitted)). Cover love, work, and one practical action.")
                        }.accessibilityIdentifier("cosmos.horoscope")
                        if ChartScreen.isAvailable {
                            Button("Calculate my birth chart", systemImage: "circle.hexagongrid") { showChart = true }
                        }
                    }

                    outfitCard
                    if ReleaseFeatures.aiImages {
                    OmniCard {
                        Eyebrow(text: "AI IMAGE STUDIO")
                        Text("Make your cosmos visible.").font(OmniTheme.title(27))
                        Text("Generate an original zodiac illustration or outfit inspiration with Omni AI.").font(.subheadline)
                        Button("Open image studio", systemImage: "sparkles.rectangle.stack") { showImageStudio = true }.accessibilityIdentifier("cosmos.imageStudio")
                    }
                    }
                    tarotCard
                    Text("Astrology and tarot offer symbolic interpretations, not guaranteed outcomes. Your choices are yours.")
                        .font(.caption).foregroundStyle(OmniTheme.muted)
                }.padding(24)
            }.background(OmniTheme.paper)
                .navigationTitle("Cosmos").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("cosmos.done") } }
                .sheet(isPresented: $showChart) { ChartScreen() }
                .sheet(isPresented: $showImageStudio) { CosmicImageScreen(sign: sign) }
                .sheet(isPresented: $showProfile) { CosmicProfileScreen() }
                .sheet(item: $chat) { item in MemoryConversationScreen(initialDraft: item.text) }
                .onChange(of: sign) { _, _ in poster = nil }
                .onChange(of: occasion) { _, _ in poster = nil }
                .onChange(of: phase) { _, phase in if phase == .active { now = Date(); poster = nil } }
                .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
                    if !Calendar.current.isDate(now, inSameDayAs: date) { now = date; poster = nil }
                }
        }
    }

    private var outfitCard: some View {
        OmniCard(color: OmniTheme.sage.opacity(0.6)) {
            Eyebrow(text: "TODAY'S COSMIC OUTFIT")
            Text(outfit.intention).font(OmniTheme.title(28))
            Picker("Dress for", selection: $occasion) { ForEach(OutfitOccasion.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14).fill(Color(hex: outfit.hex)).frame(width: 60, height: 72)
                VStack(alignment: .leading, spacing: 5) { Text(outfit.color).font(OmniTheme.title(25)); Text("\(sign.element) spirit · \(occasion.rawValue)").font(.caption) }
            }
            ForEach(outfit.pieces, id: \.self) { Text("• \($0)").font(.subheadline) }
            Text(outfit.basis).font(.caption).foregroundStyle(OmniTheme.muted)
            Button("Personalize with Omni AI", systemImage: "bubble.left.and.bubble.right") {
                chat = CosmicConversationDraft(text: "Help me personalize today's \(sign.rawValue)-inspired \(occasion.rawValue.lowercased()) outfit: \(outfit.pieces.joined(separator: ", ")). Use my relevant saved style preferences if available. Ask about weather and comfort rather than assuming my gender, body, location or budget. Suggest items I might already own.")
            }
            Button("Create my share card", systemImage: "photo") { makePoster() }.accessibilityIdentifier("cosmos.poster")
            if let poster {
                poster.resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 16))
                ShareLink(item: poster, preview: SharePreview("My cosmic outfit", image: poster)) { Label("Share image", systemImage: "square.and.arrow.up") }
                Text("Designed on your device. This card shares only the sign, date and outfit shown above.").font(.caption)
            }
            if let posterError { Text(posterError).font(.caption).foregroundStyle(.red) }
        }
    }

    private var tarotCard: some View {
        OmniCard {
            Eyebrow(text: "A THREE-CARD READING")
            Text("Ask. Shuffle. Discover.").font(OmniTheme.title(28))
            TextField("What is on your heart?", text: $question, axis: .vertical).lineLimit(2...4)
                .onChange(of: question) { _, value in question = String(value.prefix(600)) }
                .padding(12).background(OmniTheme.paper, in: RoundedRectangle(cornerRadius: 12)).accessibilityIdentifier("cosmos.question")
            Button(draws.isEmpty ? "Shuffle & draw" : "Draw a new spread", systemImage: "rectangle.stack") {
                var rng = SystemRandomNumberGenerator()
                draws = TarotDraw.threeCards(using: &rng)
                drawnQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
            }.disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("cosmos.draw")
            if !draws.isEmpty {
                Text(drawnQuestion).font(.subheadline.weight(.medium))
                ForEach(draws) { draw in
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: draw.position)
                        Label(draw.card.name, systemImage: draw.reversed ? "moon.stars" : "sparkles").font(OmniTheme.title(23))
                        Text(draw.reversed ? "Reversed" : "Upright").font(.caption)
                        Text(draw.prompt).font(.subheadline)
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(OmniTheme.peach.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
                }
                Button("Interpret my cards with AI", systemImage: "bubble.left.and.text.bubble.right") {
                    let spread = draws.map { "\($0.position): \($0.label) (\($0.card.theme))" }.joined(separator: "; ")
                    chat = CosmicConversationDraft(text: "Read this actual three-card draw for my question: \(drawnQuestion)\nCards: \(spread). My selected Sun sign: \(sign.rawValue). Keep the drawn cards unchanged. Explain the symbolism, connect it to my question and suggest one action. Do not claim to know another person's intentions or guarantee future events. Death is a symbol of transition, not a death prediction.")
                }
            }
            Text("78 cards, shuffled randomly without repeats. Reversed cards are included. These prompts are written guidance; AI interpretation opens a conversation for you to review and send.").font(.caption).foregroundStyle(OmniTheme.muted)
        }
    }

    @MainActor private func makePoster() {
        let renderer = ImageRenderer(content: CosmicStylePoster(sign: sign, outfit: outfit, date: now).frame(width: 360, height: 560))
        renderer.scale = 3
        if let image = renderer.uiImage { poster = Image(uiImage: image); posterError = nil }
        else { posterError = "The image couldn't be prepared. Please try again." }
    }
}

private struct CosmicConversationDraft: Identifiable { let id = UUID(); let text: String }

private struct CosmicStylePoster: View {
    let sign: ZodiacSign
    let outfit: CosmicOutfit
    let date: Date
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("OMNI · COSMOS").font(.caption.monospaced()).tracking(3)
            HStack { Text(sign.rawValue).font(.system(size: 34, design: .serif)); Spacer(); Text(sign.symbol).font(.system(size: 62)) }
            Text(date.formatted(.dateTime.month(.wide).day().year())).font(.caption)
            Rectangle().fill(.white.opacity(0.3)).frame(height: 1)
            Text(outfit.intention).font(.system(size: 30, design: .serif))
            Text("TODAY'S COLOR · \(outfit.color.uppercased())").font(.caption.monospaced())
            ForEach(outfit.pieces, id: \.self) { Text($0).font(.system(size: 16)).fixedSize(horizontal: false, vertical: true) }
            Spacer(minLength: 0)
            Text("Wear your own kind of magic.").font(.system(size: 18, design: .serif))
            Text("Zodiac-inspired style · Made with Omni").font(.system(size: 10))
        }.padding(30).foregroundStyle(.white)
            .background(LinearGradient(colors: [Color(hex: "2D004B"), Color(hex: outfit.hex).opacity(0.9), Color(hex: "160D27")], startPoint: .topLeading, endPoint: .bottomTrailing))
    }
}
