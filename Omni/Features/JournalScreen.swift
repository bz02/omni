import SwiftUI

struct JournalScreen: View {
    @EnvironmentObject private var store: ClarityStore
    @EnvironmentObject private var subscription: SubscriptionStore
    @State private var paywall = false
    @State private var selectedDay: DailyEntry?
    @State private var selectedConnection: ConnectionEntry?
    @State private var segment = 0
    private var summary: WeeklySummary { WeeklySummary(entries: store.days) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PageHeading(eyebrow: "A RECORD OF BECOMING", title: "Your story.\nIn your words.", subtitle: "Little moments count. You don't need a perfect streak.")
                    OmniCard(color: OmniTheme.sage) {
                        HStack { Eyebrow(text: "THE LAST SEVEN DAYS"); Spacer(); Image(systemName: "circle.lefthalf.filled") }
                        HStack(alignment: .firstTextBaseline, spacing: 8) { Text("\(summary.checkIns)").font(OmniTheme.title(50)); Text("moments for yourself").font(.subheadline) }
                        if subscription.hasPremium {
                            Text(summary.observations).font(.system(size: 15)).lineSpacing(5)
                            HStack { Label("\(summary.reflections) reflections", systemImage: "moon"); Spacer(); Label("\(summary.followThrough) intentions kept", systemImage: "checkmark") }.font(.caption)
                            Text("A summary of what you recorded, not a psychological assessment.").font(.caption2).foregroundStyle(OmniTheme.muted)
                        } else {
                            Text("Look back at your feelings and intentions with a little more perspective.").font(.system(size: 14)).foregroundStyle(OmniTheme.muted)
                            Button { paywall = true } label: { HStack { Text("Explore your week with Plus"); Spacer(); Image(systemName: "arrow.right") }.font(.system(size: 14, weight: .semibold)) }
                        }
                    }
                    Picker("Journal entries", selection: $segment) { Text("Daily moments").tag(0); Text("Connections").tag(1) }.pickerStyle(.segmented)
                    if segment == 0 {
                        if store.days.isEmpty { emptyState("Your first page is waiting.", "Start with a check-in on Today. There's no need to make it profound.", "book") }
                        ForEach(store.days) { entry in
                            Button { selectedDay = entry } label: {
                                OmniCard {
                                    HStack { Eyebrow(text: entry.date.formatted(.dateTime.month(.abbreviated).day())); Spacer(); Image(systemName: entry.feeling.symbol); Text(entry.feeling.label).font(.caption) }
                                    Text(entry.intention).font(OmniTheme.title(23)).multilineTextAlignment(.leading)
                                    if !entry.reflection.isEmpty { Text(entry.reflection).font(.system(size: 13)).lineLimit(3).foregroundStyle(OmniTheme.muted).multilineTextAlignment(.leading) }
                                    HStack { Text(entry.eveningFeeling == nil ? "Add an evening reflection" : "Revisit this moment"); Spacer(); Image(systemName: "arrow.up.right") }.font(.caption)
                                }
                            }.buttonStyle(.plain)
                        }
                    } else {
                        if store.connections.isEmpty { emptyState("A little clarity, kept.", "Your guided reflections will be here whenever you want to return to them.", "heart") }
                        ForEach(store.connections) { entry in
                            Button { selectedConnection = entry } label: {
                                OmniCard {
                                    HStack { Eyebrow(text: entry.date.formatted(.dateTime.month(.abbreviated).day())); Spacer(); Image(systemName: entry.kind.icon) }
                                    Text(entry.kind.rawValue).font(OmniTheme.title(24))
                                    Text(entry.fact).font(.system(size: 14)).lineLimit(3).foregroundStyle(OmniTheme.muted).multilineTextAlignment(.leading)
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding(24).padding(.bottom, 20)
            }.background(OmniTheme.paper).toolbar(.hidden, for: .navigationBar)
                .sheet(isPresented: $paywall) { PlusScreen() }
                .sheet(item: $selectedDay) { JournalDayDetail(entry: $0) }
                .sheet(item: $selectedConnection) { JournalConnectionDetail(entry: $0) }
        }
    }
    private func emptyState(_ title: String, _ subtitle: String, _ icon: String) -> some View {
        VStack(spacing: 15) { Image(systemName: icon).font(.system(size: 32, weight: .ultraLight)); Text(title).font(OmniTheme.title(25)); Text(subtitle).font(.system(size: 14)).foregroundStyle(OmniTheme.muted).multilineTextAlignment(.center).lineSpacing(4) }.frame(maxWidth: .infinity).padding(.vertical, 38)
    }
}

struct JournalDayDetail: View {
    let entry: DailyEntry
    @EnvironmentObject private var store: ClarityStore
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var delete = false
    private var current: DailyEntry { store.days.first { $0.id == entry.id } ?? entry }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PageHeading(eyebrow: current.date.formatted(.dateTime.month(.wide).day().year()), title: current.intention)
                    Label("I felt \(current.feeling.label.lowercased())", systemImage: current.feeling.symbol).font(.headline)
                    if let evening = current.eveningFeeling { Label("Later, I felt \(evening.label.lowercased())", systemImage: evening.symbol) }
                    if !current.reflection.isEmpty { Text(current.reflection).lineSpacing(6).textSelection(.enabled) }
                    OmniButton(title: current.eveningFeeling == nil ? "Add a reflection" : "Edit reflection", icon: "pencil") { editing = true }
                    Button("Delete this moment", role: .destructive) { delete = true }.font(.subheadline)
                }.padding(24)
            }.background(OmniTheme.paper).toolbar { Button("Done") { dismiss() } }
                .sheet(isPresented: $editing) { ReflectionSheet(entry: current) }
                .confirmationDialog("Delete this journal entry? This cannot be undone.", isPresented: $delete, titleVisibility: .visible) { Button("Delete entry", role: .destructive) { store.deleteDay(entry.id); if !store.days.contains(where: { $0.id == entry.id }) { dismiss() } } }
        }
    }
}

struct JournalConnectionDetail: View {
    let entry: ConnectionEntry
    @EnvironmentObject private var store: ClarityStore
    @Environment(\.dismiss) private var dismiss
    @State private var delete = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PageHeading(eyebrow: entry.date.formatted(.dateTime.month(.wide).day()), title: entry.kind.rawValue)
                    journalAnswer(entry.kind.firstPrompt, entry.fact)
                    journalAnswer(entry.kind.secondPrompt, entry.feeling)
                    journalAnswer(entry.kind.thirdPrompt, entry.need)
                    OmniCard(color: OmniTheme.sage) { Eyebrow(text: "YOUR REFLECTION"); Text(entry.takeaway).lineSpacing(6).textSelection(.enabled) }
                    Button("Delete this reflection", role: .destructive) { delete = true }.font(.subheadline)
                }.padding(24)
            }.background(OmniTheme.paper).toolbar { Button("Done") { dismiss() } }
                .confirmationDialog("Delete this reflection? This cannot be undone.", isPresented: $delete, titleVisibility: .visible) { Button("Delete reflection", role: .destructive) { store.deleteConnection(entry.id); if !store.connections.contains(where: { $0.id == entry.id }) { dismiss() } } }
        }
    }
    private func journalAnswer(_ title: String, _ answer: String) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text(title).font(.caption).foregroundStyle(OmniTheme.muted); Text(answer).lineSpacing(4).textSelection(.enabled) }
    }
}
