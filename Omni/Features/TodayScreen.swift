import SwiftUI

struct TodayScreen: View {
    @EnvironmentObject private var store: ClarityStore
    @State private var checkIn = false
    @State private var reflection: DailyEntry?
    @State private var showLens = false
    @State private var now = Date()
    @Environment(\.scenePhase) private var scenePhase
    private var ritual: DailyRitual { ReflectionLibrary.focusedRitual(for: now, focus: store.profile?.focus ?? .myself) }
    private var entry: DailyEntry? { store.today(at: now) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    HStack {
                        Text("omni").font(.system(size: 28, weight: .medium, design: .serif))
                        Spacer()
                        HStack(spacing: 6) { Circle().fill(OmniTheme.gold).frame(width: 5, height: 5); Text("YOUR DAILY PAUSE").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1) }
                    }.padding(.bottom, 5)
                    HStack {
                        Eyebrow(text: now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        Spacer()
                        Text(store.profile?.focus.rawValue ?? "For you").font(.system(size: 11)).padding(.horizontal, 12).padding(.vertical, 7).background(OmniTheme.sage, in: Capsule())
                    }
                    VStack(alignment: .leading, spacing: 17) {
                        Text(greeting).font(.system(size: 14)).foregroundStyle(OmniTheme.muted)
                        Text(ritual.title).font(OmniTheme.title(42)).lineSpacing(-1).fixedSize(horizontal: false, vertical: true)
                        CelestialArt().frame(height: 140).padding(.vertical, -10)
                        Text(ritual.reassurance).font(.system(size: 16)).lineSpacing(5).foregroundStyle(OmniTheme.muted)
                        Button { showLens = true } label: {
                            HStack(spacing: 5) { Image(systemName: "sparkle"); Text("\(ritual.element.uppercased()) · TODAY'S REFLECTION LENS"); Image(systemName: "info.circle") }.font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(0.7)
                        }.padding(.top, 3)
                    }
                    if let entry {
                        OmniCard(color: OmniTheme.sage) {
                            HStack { Eyebrow(text: "YOUR ONE SMALL THING"); Spacer(); Image(systemName: entry.completed ? "checkmark.circle.fill" : "circle.dotted") }
                            Text(entry.intention).font(OmniTheme.title(25))
                            HStack { Label(entry.feeling.label, systemImage: entry.feeling.symbol); Spacer(); Button("Edit") { checkIn = true } }.font(.caption)
                            OmniButton(title: entry.eveningFeeling == nil ? "Come back & reflect" : "Revisit your reflection", icon: "moon") { reflection = entry }
                        }
                    } else {
                        OmniCard(color: OmniTheme.sage.opacity(0.65)) {
                            HStack { Eyebrow(text: "A TWO-MINUTE CHECK-IN"); Spacer(); Image(systemName: "sun.haze") }
                            Text("How are you, really?").font(OmniTheme.title(26))
                            Text("No right feeling. No score to improve.").font(.system(size: 14)).foregroundStyle(OmniTheme.muted)
                            OmniButton(title: "Check in with myself") { checkIn = true }.accessibilityIdentifier("today.checkin")
                        }
                    }
                    HStack(alignment: .top, spacing: 18) {
                        RoundedRectangle(cornerRadius: 15).fill(Color(hex: ritual.colorHex)).frame(width: 65, height: 83)
                            .overlay(Image(systemName: "sparkle").font(.title2).foregroundStyle(.white.opacity(0.8)))
                        VStack(alignment: .leading, spacing: 7) {
                            Eyebrow(text: "WEAR A LITTLE INTENTION")
                            Text(ritual.colorName).font(OmniTheme.title(23))
                            Text(ritual.style).font(.system(size: 13)).foregroundStyle(OmniTheme.muted).lineSpacing(3)
                        }
                    }.padding(.vertical, 3)
                    HStack(spacing: 7) { Image(systemName: "lock"); Text("A moment for you. Kept on your device.") }.font(.system(size: 11)).foregroundStyle(OmniTheme.muted).frame(maxWidth: .infinity).padding(.top, 8)
                }.padding(24).padding(.bottom, 16)
            }.background(OmniTheme.paper).toolbar(.hidden, for: .navigationBar)
                .sheet(isPresented: $checkIn) { CheckInSheet(existing: entry) }
                .sheet(item: $reflection) { ReflectionSheet(entry: $0) }
                .sheet(isPresented: $showLens) { ReflectionLensSheet(ritual: ritual) }
                .onChange(of: scenePhase) { _, phase in if phase == .active { now = Date() } }
                .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now = $0 }
        }
    }
    private var greeting: String {
        let name = store.profile?.name ?? ""
        return name.isEmpty ? "It's good to have you here." : "A little space for you, \(name)."
    }
}

struct CheckInSheet: View {
    @EnvironmentObject private var store: ClarityStore
    @Environment(\.dismiss) private var dismiss
    @State private var feeling: Feeling = .okay
    @State private var intention = ""
    @State private var openedAt = Date()
    let existing: DailyEntry?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 27) {
                    PageHeading(eyebrow: "MEET YOURSELF HERE", title: "Everything you're\nfeeling can belong.", subtitle: "Pick the closest word. Mixed feelings count, too.")
                    FeelingPicker(selection: $feeling)
                    EntryField(title: "One small thing I can do for myself", placeholder: ReflectionLibrary.focusedRitual(for: openedAt, focus: store.profile?.focus ?? .myself).action, text: $intention, maxLength: 500)
                    Text(ReflectionLibrary.focusedRitual(for: openedAt, focus: store.profile?.focus ?? .myself).question).font(OmniTheme.title(22)).foregroundStyle(OmniTheme.muted)
                    OmniButton(title: "Keep this intention", icon: "checkmark") {
                        if store.checkIn(feeling: feeling, intention: intention, date: existing?.date ?? openedAt) { dismiss() }
                    }.disabled(intention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).opacity(intention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1).accessibilityIdentifier("checkin.save")
                }.padding(24)
            }.scrollDismissesKeyboard(.interactively).background(OmniTheme.paper).navigationTitle("Your check-in").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }.onAppear { if let existing { feeling = existing.feeling; intention = existing.intention } }
    }
}

struct ReflectionSheet: View {
    @EnvironmentObject private var store: ClarityStore
    @Environment(\.dismiss) private var dismiss
    let entry: DailyEntry
    @State private var feeling: Feeling = .okay
    @State private var text = ""
    @State private var completed = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    PageHeading(eyebrow: "COME BACK WITH KINDNESS", title: "How did your\nday feel?", subtitle: "You're noticing, not grading yourself.")
                    FeelingPicker(selection: $feeling)
                    OmniCard(color: OmniTheme.sage) {
                        Eyebrow(text: "YOUR INTENTION")
                        Text(entry.intention).font(OmniTheme.title(22))
                        Toggle("I made space for this", isOn: $completed).font(.subheadline)
                    }
                    EntryField(title: "What would you like to remember?", placeholder: "A moment, a feeling, or something I learned…", text: $text, maxLength: 4000)
                    OmniButton(title: "Save my reflection", icon: "checkmark") {
                        if store.reflect(entryID: entry.id, feeling: feeling, text: text, completed: completed) { dismiss() }
                    }.accessibilityIdentifier("reflection.save")
                }.padding(24)
            }.scrollDismissesKeyboard(.interactively).background(OmniTheme.paper).navigationTitle("Evening reflection").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }.onAppear { feeling = entry.eveningFeeling ?? entry.feeling; text = entry.reflection; completed = entry.completed }
    }
}

struct ReflectionLensSheet: View {
    let ritual: DailyRitual
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PageHeading(eyebrow: "INSPIRATION, WITH CONTEXT", title: "A lens,\nnot a label.")
                    Text("Today's \(ritual.element.lowercased()) theme is part of a rotating, authored collection inspired by the five elements. It offers a metaphor for reflection and a color to play with.").lineSpacing(5)
                    Text("It isn't calculated from your birth chart and doesn't predict what will happen. The clothing suggestions are style inspiration, not a treatment or a way to change your luck.").foregroundStyle(OmniTheme.muted).lineSpacing(5)
                    Text("Your experiences and choices matter more than any symbol.").font(OmniTheme.title(26))
                }.padding(26)
            }.background(OmniTheme.paper).toolbar { Button("Done") { dismiss() } }
        }.presentationDetents([.medium, .large])
    }
}
