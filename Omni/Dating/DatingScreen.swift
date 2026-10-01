import SwiftUI

struct DatingScreen: View {
    @EnvironmentObject private var account: AccountStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = DatingStore()
    @State private var showAccount = false
    @State private var edit = false
    @State private var erase = false
    @State private var conversation: DatingMatch?
    @State private var safety: DatingCandidate?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PageHeading(eyebrow: "OMNI · COSMIC CONNECTIONS", title: "A little chemistry.\nA real connection.", subtitle: "Meet adults who choose to be here. Explore your signs, then get to know the person.")
                    if !account.isSignedIn {
                        OmniCard {
                            Text("Your choice to connect").font(OmniTheme.title(25))
                            Text("Sign in to create a separate dating profile. Your journal and AI conversations stay private.")
                            Button("Sign in to explore") { showAccount = true }.accessibilityIdentifier("dating.signIn")
                        }
                    } else if let envelope = store.envelope {
                        if !envelope.discovery_enabled {
                            OmniCard {
                                Text("Discovery is not open yet.").font(OmniTheme.title(25))
                                Text("This account service hasn't opened dating. Your existing Omni features remain available.")
                            }
                        } else {
                            profileCard(envelope)
                            if envelope.status == "approved", envelope.profile?.visible == true {
                                if store.candidates.isEmpty {
                                    Text("No new profiles match both people's preferences yet. Check back as more people join.").foregroundStyle(OmniTheme.muted)
                                }
                                ForEach(store.candidates) { candidate in
                                    DatingPersonCard(person: candidate) {
                                        Button("Like", systemImage: "heart") { Task { await store.like(candidate, account: account) } }.disabled(store.isBusy)
                                        Button("Block or report", systemImage: "shield") { safety = candidate }
                                    }
                                }
                            }
                            if !store.matches.isEmpty {
                                Eyebrow(text: "YOUR MUTUAL MATCHES")
                                ForEach(store.matches) { match in
                                    Button { conversation = match } label: {
                                        OmniCard {
                                            HStack { Text(match.profile.name).font(OmniTheme.title(25)); Spacer(); Image(systemName: "bubble.left.and.bubble.right") }
                                            Text(match.profile.pairing.prompt).font(.subheadline).multilineTextAlignment(.leading)
                                        }
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    if store.isBusy { ProgressView("Loading your connections…") }
                    if let notice = store.notice { Text(notice).font(.subheadline) }
                    if let error = store.error { Text(error).foregroundStyle(.red).font(.subheadline) }
                    Text("18+ · You control whether your profile is shown. Exact birthdays, private memories and journal entries are never displayed to other daters.").font(.caption).foregroundStyle(OmniTheme.muted)
                }.padding(24)
            }.background(OmniTheme.paper)
                .navigationTitle("Discover").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                    ToolbarItem(placement: .primaryAction) { Button("Refresh", systemImage: "arrow.clockwise") { Task { await store.load(account: account) } }.disabled(!account.isSignedIn || store.isBusy) }
                }
                .task(id: account.accountID) { if account.isSignedIn { await store.load(account: account) } }
                .sheet(isPresented: $showAccount) { AccountScreen() }
                .sheet(isPresented: $edit, onDismiss: { Task { await store.load(account: account) } }) {
                    DatingProfileEditor(store: store, profile: store.envelope?.profile ?? DatingProfile())
                }
                .sheet(item: $conversation, onDismiss: { Task { await store.load(account: account) } }) { DatingConversationScreen(match: $0) }
                .sheet(item: $safety, onDismiss: { Task { await store.load(account: account) } }) { DatingSafetyScreen(person: $0) }
                .confirmationDialog("Delete your dating profile, matches and messages?", isPresented: $erase, titleVisibility: .visible) {
                    Button("Delete dating data", role: .destructive) { Task { await store.remove(account: account) } }
                } message: { Text("Your Omni account, journal, memory and subscription remain. This deletion cannot be undone.") }
        }
    }

    @ViewBuilder private func profileCard(_ envelope: DatingEnvelope) -> some View {
        OmniCard(color: OmniTheme.sage) {
            Text(envelope.profile?.name ?? "Start with you").font(OmniTheme.title(27))
            if envelope.status == "pending" { Text("Your public details are waiting for review. They are not shown in discovery yet.") }
            else if envelope.status == "suspended" { Text("This profile is paused by our review team. Contact support if you need help.") }
            else if let profile = envelope.profile { Text(profile.visible ? "Your profile is visible to eligible adults." : "Your profile is hidden from discovery.") }
            else { Text("Add your birthday, an introduction and your dating preferences. You choose when to be visible.") }
            Button(envelope.profile == nil ? "Create my dating profile" : "Edit my profile") { edit = true }.accessibilityIdentifier("dating.edit")
            if envelope.profile != nil {
                Button("Delete dating profile", role: .destructive) { erase = true }
            }
        }
    }
}

struct DatingPersonCard<Actions: View>: View {
    let person: DatingCandidate
    @ViewBuilder let actions: () -> Actions
    var body: some View {
        OmniCard {
            HStack { Text("\(person.name), \(person.age)").font(OmniTheme.title(28)); Spacer(); Image(systemName: "sparkles") }
            Text(person.city).font(.subheadline).foregroundStyle(OmniTheme.muted)
            Text(person.bio)
            Text(person.intention.replacingOccurrences(of: "_", with: " ").capitalized).font(.caption)
            Label("\(person.pairing.score) · Symbolic connection", systemImage: "moon.stars").font(.headline)
            Text(person.pairing.signs.joined(separator: " + ")).font(.subheadline)
            DisclosureGroup("What this score means") { Text(person.pairing.explanation).font(.caption) }
            Text(person.pairing.prompt).font(.subheadline.italic())
            actions()
        }
    }
}

struct DatingProfileEditor: View {
    @ObservedObject var store: DatingStore
    @State var profile: DatingProfile
    @EnvironmentObject private var account: AccountStore
    @Environment(\.dismiss) private var dismiss
    @State private var consent = false
    private let genders = [("woman", "Women"), ("man", "Men"), ("nonbinary", "Nonbinary people")]
    private var valid: Bool { consent && !profile.name.trimmingCharacters(in: .whitespaces).isEmpty && profile.city.count >= 2 && profile.bio.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10 && ["woman", "man", "nonbinary"].contains(profile.gender) && !profile.seeking.isEmpty && profile.age_min <= profile.age_max }
    private var birthday: Binding<Date> {
        Binding(get: { Self.dateFormatter.date(from: profile.birth_date) ?? Date(timeIntervalSince1970: 788918400) },
                set: { profile.birth_date = Self.dateFormatter.string(from: $0) })
    }
    private static var dateFormatter: DateFormatter {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.calendar = Calendar(identifier: .gregorian); f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "yyyy-MM-dd"; return f
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Your public profile") {
                    TextField("First name", text: $profile.name).onChange(of: profile.name) { _, value in profile.name = String(value.prefix(40)) }
                    TextField("City or area", text: $profile.city).onChange(of: profile.city) { _, value in profile.city = String(value.prefix(80)) }
                    TextField("A little about you", text: $profile.bio, axis: .vertical).lineLimit(3...6).onChange(of: profile.bio) { _, value in profile.bio = String(value.prefix(500)) }
                    Picker("I identify as", selection: $profile.gender) { Text("Choose").tag(""); Text("Woman").tag("woman"); Text("Man").tag("man"); Text("Nonbinary").tag("nonbinary") }
                    Picker("I'm looking for", selection: $profile.intention) { Text("A long-term relationship").tag("long_term"); Text("Still exploring").tag("exploring"); Text("Casual dating").tag("casual") }
                }
                Section("Birthday · kept private") {
                    DatePicker("Birth date", selection: birthday, in: Date(timeIntervalSince1970: -2208988800)...Date(), displayedComponents: .date)
                        .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!).environment(\.calendar, Calendar(identifier: .gregorian))
                        .disabled(store.envelope?.profile != nil)
                    Text("Only your age and approximate Sun sign are shown. You must be 18+. Contact support to correct a saved birthday.").font(.caption)
                }
                Section("Who you'd like to meet") {
                    ForEach(genders, id: \.0) { value in
                        Toggle(value.1, isOn: Binding(get: { profile.seeking.contains(value.0) }, set: { enabled in
                            profile.seeking.removeAll { $0 == value.0 }; if enabled { profile.seeking.append(value.0) }
                        }))
                    }
                    Stepper("Minimum age: \(profile.age_min)", value: $profile.age_min, in: 18...100)
                    Stepper("Maximum age: \(profile.age_max)", value: $profile.age_max, in: 18...100)
                    Text("Recommendations respect both people's preferences. City is shown, but distance filtering is not available yet.").font(.caption)
                }
                Section("You choose to be seen") {
                    Toggle("Show me in discovery", isOn: $profile.visible)
                    Toggle("I am 18+ and agree to this profile being stored by Omni and shown to eligible daters when visible.", isOn: $consent)
                    Text("Be yourself, be respectful and don't post contact details, explicit content or requests for money. Public profiles are reviewed before discovery. Block or report unwanted behavior at any time.").font(.caption)
                    if let url = URL(string: "mailto:seatrial.ai@gmail.com") { Link("Contact support", destination: url) }
                }
                if let error = store.error { Text(error).foregroundStyle(.red) }
                Button(store.isBusy ? "Saving…" : "Save my profile") { Task { if await store.save(profile, account: account) { dismiss() } } }.disabled(!valid || store.isBusy)
            }.navigationTitle("Dating profile").toolbar { Button("Cancel") { dismiss() } }
        }.interactiveDismissDisabled(store.isBusy)
    }
}

struct DatingSafetyScreen: View {
    let person: DatingCandidate
    @EnvironmentObject private var account: AccountStore
    @Environment(\.dismiss) private var dismiss
    @State private var reason = "harassment"
    @State private var detail = ""
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Block \(person.name)").font(.headline)
                    Text("Blocking removes your match and messages and stops future contact in Omni. They won't receive a notification.")
                    Button("Block this person", role: .destructive) { act(report: false) }.disabled(busy)
                }
                Section("Send a report to Omni") {
                    Picker("Reason", selection: $reason) {
                        Text("Under 18").tag("underage"); Text("Harassment").tag("harassment"); Text("Scam").tag("scam")
                        Text("Explicit content").tag("sexual_content"); Text("Impersonation").tag("impersonation"); Text("Other").tag("other")
                    }
                    TextField("Details (optional)", text: $detail, axis: .vertical).onChange(of: detail) { _, value in detail = String(value.prefix(1000)) }
                    Text("Your report goes to Omni's review queue. Reporting also blocks this person. Describe the issue here because the blocked conversation is deleted.").font(.caption)
                    Button("Submit report & block", role: .destructive) { act(report: true) }.disabled(busy)
                }
                if let error { Text(error).foregroundStyle(.red) }
                Link("Contact support", destination: URL(string: "mailto:seatrial.ai@gmail.com")!)
            }.navigationTitle("Your safety").toolbar { Button("Cancel") { dismiss() }.disabled(busy) }
        }.interactiveDismissDisabled(busy)
    }
    private func act(report: Bool) {
        busy = true; error = nil
        Task {
            defer { busy = false }
            do {
                struct Body: Encodable { let reason: String; let detail: String }
                let body = report ? try JSONEncoder().encode(Body(reason: reason, detail: detail)) : nil
                _ = try await account.authenticatedRequest(path: "/v1/dating/profiles/\(person.id.uuidString.lowercased())/\(report ? "report" : "block")", method: "POST", body: body)
                dismiss()
            } catch { self.error = DatingStore.message(error) }
        }
    }
}

struct DatingConversationScreen: View {
    let match: DatingMatch
    @EnvironmentObject private var account: AccountStore
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [DatingMessage] = []
    @State private var draft = ""
    @State private var pending: (id: UUID, text: String)?
    @State private var busy = false
    @State private var error: String?
    @State private var safety = false
    @State private var unmatch = false
    private var path: String { "/v1/dating/matches/\(match.id.uuidString.lowercased())" }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("You both chose to connect.").font(OmniTheme.title(26))
                    Text(match.profile.pairing.prompt).font(.subheadline).foregroundStyle(OmniTheme.muted)
                    Text("This conversation is with \(match.profile.name), not Omni AI. The latest 20 messages are shown.").font(.caption)
                    ForEach(messages) { message in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(message.mine ? "You" : match.profile.name).font(.caption.bold())
                            Text(message.text).textSelection(.enabled)
                        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(message.mine ? OmniTheme.sage : .white, in: RoundedRectangle(cornerRadius: 16))
                    }
                    TextField("Say hello…", text: $draft, axis: .vertical).lineLimit(2...5).padding(16).background(.white, in: RoundedRectangle(cornerRadius: 16))
                        .onChange(of: draft) { _, value in draft = String(value.prefix(1000)) }
                    Button(pending == nil ? "Send message" : "Retry pending message", systemImage: "paperplane") { send() }.disabled(busy || (pending == nil && draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                    if pending != nil { Text("A message is awaiting confirmation. Retry sends the same message once; your edited draft is kept for later.").font(.caption) }
                    if let error { Text(error).foregroundStyle(.red).font(.subheadline) }
                    Button("Block or report") { safety = true }
                    Button("Unmatch", role: .destructive) { unmatch = true }
                }.padding(24)
            }.background(OmniTheme.paper).navigationTitle(match.profile.name).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                    ToolbarItem(placement: .primaryAction) { Button("Refresh", systemImage: "arrow.clockwise") { Task { await load() } }.disabled(busy) }
                }
                .task { await load() }
                .sheet(isPresented: $safety, onDismiss: { Task { await load() } }) { DatingSafetyScreen(person: match.profile) }
                .confirmationDialog("Unmatch with \(match.profile.name)?", isPresented: $unmatch, titleVisibility: .visible) {
                    Button("Unmatch", role: .destructive) {
                        Task { do { _ = try await account.authenticatedRequest(path: path, method: "DELETE"); dismiss() } catch { self.error = DatingStore.message(error) } }
                    }
                } message: { Text("This deletes the conversation and blocks future contact in Omni.") }
        }
    }
    private func load() async {
        guard !busy else { return }; busy = true
        defer { busy = false }
        do {
            struct Body: Decodable { let messages: [DatingMessage] }
            let data = try await account.authenticatedRequest(path: path + "/messages")
            messages = try JSONDecoder().decode(Body.self, from: data).messages; error = nil
        } catch { messages = []; self.error = DatingStore.message(error) }
    }
    private func send() {
        guard !busy else { return }
        if pending == nil { pending = (UUID(), draft.trimmingCharacters(in: .whitespacesAndNewlines)) }
        guard let pending else { return }
        busy = true; error = nil
        Task {
            do {
                struct Body: Encodable { let id: UUID; let text: String }
                _ = try await account.authenticatedRequest(path: path + "/messages", method: "POST", body: JSONEncoder().encode(Body(id: pending.id, text: pending.text)))
                if draft.trimmingCharacters(in: .whitespacesAndNewlines) == pending.text { draft = "" }
                self.pending = nil; busy = false; await load()
            } catch { self.error = DatingStore.message(error); busy = false }
        }
    }
}
