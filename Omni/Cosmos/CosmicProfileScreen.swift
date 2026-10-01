import SwiftUI

/// Uses the existing account/guest memory archive and its consent, export and deletion controls.
struct CosmicProfileScreen: View {
    @EnvironmentObject private var memory: MemoryStore
    @EnvironmentObject private var subscription: SubscriptionStore
    @Environment(\.dismiss) private var dismiss
    @State private var birthday = Date(timeIntervalSince1970: 788918400)
    @State private var birthTime = Date(timeIntervalSince1970: 43200)
    @State private var knowsTime = false
    @State private var birthplace = ""
    @State private var style = ""
    @State private var consent = false
    @State private var saved = false
    @State private var message: String?
    @State private var manage = false
    private let marker = "Birth details I provided:"
    private var existingBirth: SavedMemory? { memory.memories.first { $0.kind == .profile && $0.text.hasPrefix(marker + "\n") } }
    private var existingStyle: SavedMemory? { memory.memories.first { $0.kind == .preference && $0.text.hasPrefix("My outfit preferences: ") } }
    private var active: Bool { subscription.hasPremium && memory.settings.enabled && !memory.recoveryRequired }
    private static func format(_ value: Date, _ pattern: String) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.calendar = Calendar(identifier: .gregorian); formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = pattern
        return formatter.string(from: value)
    }
    private var birthNote: String {
        "\(marker)\nBirth date: \(Self.format(birthday, "yyyy-MM-dd"))\nRecorded local birth time: \(knowsTime ? Self.format(birthTime, "HH:mm") : "unknown")\nBirthplace: \(birthplace.trimmingCharacters(in: .whitespacesAndNewlines))\nThese are my supplied details, not a calculated birth chart."
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Let Omni get to know you.").font(OmniTheme.title(27))
                    Text("Save your birth details and style preferences in your existing Omni memory. They can help future AI conversations when memory and online sharing are enabled. They are never copied to your dating profile.")
                    Button("Manage memory & privacy") { manage = true }
                    if !active { Text("Turn on memory with Omni Plus to save these details. Existing memories remain yours to review and delete.").font(.caption) }
                }
                if let existingBirth {
                    Section("Currently remembered") { Text(existingBirth.text).font(.subheadline) }
                }
                Section(existingBirth == nil ? "Your birth details" : "Replace these birth details") {
                    DatePicker("Birth date", selection: $birthday, in: Date(timeIntervalSince1970: -2208988800)...Date(), displayedComponents: .date)
                        .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!).environment(\.calendar, Calendar(identifier: .gregorian))
                    Toggle("I know my recorded birth time", isOn: $knowsTime)
                    if knowsTime { DatePicker("Local birth time", selection: $birthTime, displayedComponents: .hourAndMinute).environment(\.timeZone, TimeZone(secondsFromGMT: 0)!) }
                    TextField("Birth city and country", text: $birthplace).onChange(of: birthplace) { _, value in birthplace = String(value.prefix(150)); consent = false }
                    Text("If the time is unknown, Omni won't invent a rising sign or houses. Full chart calculations need a verified birthplace and timezone.").font(.caption)
                }
                Section("Your style") {
                    TextField("What you like to wear, colors, comfort or budget preferences", text: $style, axis: .vertical).lineLimit(3...6).onChange(of: style) { _, value in style = String(value.prefix(500)); consent = false }
                    Text("Optional. Leave blank to keep your existing style memory unchanged. You can delete it in Manage memory.").font(.caption)
                }
                Section {
                    Text(birthNote).font(.caption)
                    Toggle("Save these details for future conversations", isOn: $consent)
                    Button(existingBirth == nil ? "Remember my details" : "Update remembered details") { save() }
                        .disabled(!active || !consent || birthplace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("cosmos.saveProfile")
                    if let message { Text(message).foregroundStyle(saved ? OmniTheme.ink : .red) }
                }
            }.navigationTitle("Your cosmic profile").toolbar { Button("Done") { dismiss() }.accessibilityIdentifier("cosmicProfile.done") }
                .sheet(isPresented: $manage) { MemoryScreen() }
                .onChange(of: birthday) { _, _ in consent = false }
                .onChange(of: birthTime) { _, _ in consent = false }
                .onChange(of: knowsTime) { _, _ in consent = false }
                .onAppear { restoreFields() }
        }
    }
    private func restoreFields() {
        if let existingStyle { style = String(existingStyle.text.dropFirst("My outfit preferences: ".count)) }
        guard let text = existingBirth?.text else { return }
        let lines = text.components(separatedBy: "\n")
        func value(_ prefix: String) -> String? { lines.first { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) } }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.calendar = Calendar(identifier: .gregorian); formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        if let value = value("Birth date: "), let date = formatter.date(from: value) { birthday = date }
        formatter.dateFormat = "HH:mm"
        if let value = value("Recorded local birth time: "), let time = formatter.date(from: value) { birthTime = time; knowsTime = true }
        birthplace = value("Birthplace: ") ?? ""
    }
    private func save() {
        guard active && consent else { return }
        let birthSaved: Bool
        if let existingBirth { birthSaved = memory.updateMemory(id: existingBirth.id, kind: .profile, text: birthNote) }
        else { birthSaved = memory.addMemory(kind: .profile, text: birthNote, premium: subscription.hasPremium) != nil }
        guard birthSaved else { saved = false; message = memory.errorMessage ?? "Your details couldn't be saved."; return }
        let cleanStyle = style.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanStyle.isEmpty {
            let note = "My outfit preferences: " + cleanStyle
            let styleSaved = existingStyle.map { memory.updateMemory(id: $0.id, kind: .preference, text: note) }
                ?? (memory.addMemory(kind: .preference, text: note, premium: subscription.hasPremium) != nil)
            if !styleSaved { saved = false; message = "Birth details saved. Style preferences couldn't be saved; please retry."; return }
        }
        consent = false; saved = true; message = "Saved in your Omni memory. Review, edit or forget these details any time."
    }
}
