import SwiftUI
import PhotosUI

struct DatingScreen: View {
    @EnvironmentObject private var account: AccountStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @StateObject private var store = DatingStore()
    @State private var showAccount = false
    @State private var edit = false
    @State private var erase = false
    @State private var conversation: DatingMatch?
    @State private var safety: DatingCandidate?
    @State private var reportCandidate: DatingCandidate?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PageHeading(eyebrow: "OMNI · COSMIC CONNECTIONS", title: "Find your people.\nFeel understood.", subtitle: "Meet friends on your wavelength, across all genders. Start with your five elements, then discover the person.")
                    if !account.isSignedIn {
                        OmniCard {
                            Text("Your choice to connect").font(OmniTheme.title(25))
                            Text("Sign in to create a separate Connect profile. Your journal and AI conversations stay private.")
                            Button("Sign in to explore") { showAccount = true }.accessibilityIdentifier("dating.signIn")
                        }
                    } else if let envelope = store.envelope {
                        if !envelope.discovery_enabled {
                            OmniCard {
                                Text("Discovery is not open yet.").font(OmniTheme.title(25))
                                Text("This account service hasn't opened friend discovery. Your existing Omni features remain available.")
                            }
                        } else {
                            profileCard(envelope)
                            if envelope.status == "approved", envelope.profile?.visible == true {
                                if store.candidates.isEmpty {
                                    Text("No new profiles match both people's preferences yet. Check back as more people join.").foregroundStyle(OmniTheme.muted)
                                }
                                ForEach(Array(store.candidates.prefix(1))) { candidate in
                                    DatingPersonCard(person: candidate) {
                                        if candidate.pairing.report != nil { Button("Why we might connect", systemImage: "sparkles") { reportCandidate = candidate } }
                                        Button("Pass", systemImage: "xmark") { Task { await store.decide(candidate, account: account) } }.disabled(store.isBusy)
                                        Button("Let’s connect", systemImage: "person.badge.plus") { Task { await store.like(candidate, account: account) } }.disabled(store.isBusy)
                                        Button("Block or report", systemImage: "shield") { safety = candidate }
                                    }
                                }
                            }
                            if !store.sentLikes.isEmpty {
                                DisclosureGroup("Requests you've sent (\(store.sentLikes.count))") {
                                    ForEach(store.sentLikes) { person in
                                        HStack { Text(person.name); Spacer(); Button("Withdraw request") { Task { await store.decide(person, unlike: true, account: account) } }.disabled(store.isBusy) }.padding(.vertical, 8)
                                    }
                                }
                            }
                            if !store.matches.isEmpty {
                                Eyebrow(text: "MESSAGES")
                                ForEach(store.matches) { match in
                                    Button { conversation = match } label: {
                                        OmniCard {
                                            HStack { Text(match.profile.name).font(OmniTheme.title(25)); Spacer(); Image(systemName: "bubble.left.and.bubble.right") }
                                            HStack {
                                                if match.pinned == true { Image(systemName: "pin.fill") }
                                                Text(match.last_message ?? "You connected. Say hello!").font(.subheadline).lineLimit(2).multilineTextAlignment(.leading)
                                                Spacer()
                                                if let unread = match.unread_count, unread > 0 { Text("\(unread)").font(.caption.bold()).padding(8).background(OmniTheme.sage, in: Capsule()) }
                                            }
                                        }
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    if store.isBusy { ProgressView("Loading your connections…") }
                    if let notice = store.notice { Text(notice).font(.subheadline) }
                    if let error = store.error { Text(error).foregroundStyle(.red).font(.subheadline) }
                    Text("18+ · You control whether your profile is shown. Exact birthdays, private memories and journal entries are never displayed to other people.").font(.caption).foregroundStyle(OmniTheme.muted)
                }.padding(24)
            }.background(OmniTheme.paper)
                .navigationTitle("Discover").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                    ToolbarItem(placement: .primaryAction) { Button("Refresh", systemImage: "arrow.clockwise") { Task { await store.load(account: account) } }.disabled(!account.isSignedIn || store.isBusy) }
                }
                .task(id: account.accountID) { if account.isSignedIn { await store.load(account: account) } }
                .task(id: phase) {
                    guard phase == .active else { return }
                    while !Task.isCancelled {
                        do { try await Task.sleep(for: .seconds(10)) } catch { return }
                        if account.isSignedIn && conversation == nil && !edit && safety == nil && reportCandidate == nil { await store.load(account: account) }
                    }
                }
                .sheet(isPresented: $showAccount) { AccountScreen() }
                .sheet(isPresented: $edit, onDismiss: { Task { await store.load(account: account) } }) {
                    DatingProfileEditor(store: store, profile: store.envelope?.profile ?? DatingProfile())
                }
                .sheet(item: $reportCandidate) { person in if let report = person.pairing.report { ConnectReportScreen(report: report) } }
                .sheet(item: $conversation, onDismiss: { Task { await store.load(account: account) } }) { DatingConversationScreen(match: $0) }
                .sheet(item: $safety, onDismiss: { Task { await store.load(account: account) } }) { DatingSafetyScreen(person: $0) }
                .confirmationDialog("Delete your Connect profile, matches and messages?", isPresented: $erase, titleVisibility: .visible) {
                    Button("Delete Connect discovery data", role: .destructive) { Task { await store.remove(account: account) } }
                } message: { Text("Your Omni account, journal, memory and subscription remain. This deletion cannot be undone.") }
        }
    }

    @ViewBuilder private func profileCard(_ envelope: DatingEnvelope) -> some View {
        OmniCard(color: OmniTheme.sage) {
            Text(envelope.profile?.name ?? "Start with you").font(OmniTheme.title(27))
            if envelope.status == "pending" { Text("Your public details are waiting for review. They are not shown in discovery yet.") }
            else if envelope.status == "suspended" { Text("This profile is paused by our review team. Contact support if you need help.") }
            else if let profile = envelope.profile { Text(profile.visible ? "Your profile is visible to eligible adults." : "Your profile is hidden from discovery.") }
            else { Text("Add your birthday, an introduction and your connection preferences. You choose when to be visible.") }
            Button(envelope.profile == nil ? "Create my Connect profile" : "Edit my profile") { edit = true }.accessibilityIdentifier("dating.edit")
            if envelope.profile != nil {
                Button("Delete Connect profile", role: .destructive) { erase = true }
            }
        }
    }
}

struct DatingPersonCard<Actions: View>: View {
    let person: DatingCandidate
    @ViewBuilder let actions: () -> Actions
    var body: some View {
        OmniCard {
            DatingPhotoView(identifier: person.photo_id, name: person.name)
            HStack { Text("\(person.name), \(person.age)").font(OmniTheme.title(28)); Spacer(); Image(systemName: "sparkles") }
            Text(person.city).font(.subheadline).foregroundStyle(OmniTheme.muted)
            Text(person.bio)
            Text(person.intention.replacingOccurrences(of: "_", with: " ").capitalized).font(.caption)
            Label("\(person.pairing.score) · Conversation fit", systemImage: "moon.stars").font(.headline)
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
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var photoError: String?
    @State private var photoLoading = false
    private let genders = [("woman", "Women"), ("man", "Men"), ("nonbinary", "Nonbinary people")]
    private var valid: Bool { !photoLoading && (profile.birth_time == nil || profile.birth_timezone != nil) && consent && !profile.name.trimmingCharacters(in: .whitespaces).isEmpty && profile.city.count >= 2 && profile.bio.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10 && ["woman", "man", "nonbinary", "unspecified"].contains(profile.gender) && !profile.seeking.isEmpty && profile.age_min <= profile.age_max }
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
                    Picker("I identify as", selection: $profile.gender) { Text("Prefer not to say").tag("unspecified"); Text("Woman").tag("woman"); Text("Man").tag("man"); Text("Nonbinary").tag("nonbinary") }
                    Picker("Here for", selection: $profile.intention) { Text("Friendship · all genders welcome").tag("friendship"); if profile.intention != "friendship" { Text("Existing relationship preference").tag(profile.intention) } }
                }
                Section("Photo · optional") {
                    if let photoData, let image = UIImage(data: photoData) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220) }
                    else { DatingPhotoView(identifier: store.envelope?.photo_id, name: profile.name) }
                    PhotosPicker(selection: $selectedPhoto, matching: .images) { Label("Choose a photo", systemImage: "photo") }.disabled(photoLoading)
                    Text("No photo required. Only the photo you select is shared. New photos are reviewed before your profile appears.").font(.caption)
                    if photoData != nil { Button("Remove selected photo") { photoData = nil; selectedPhoto = nil } }
                    if store.envelope?.photo_id != nil { Button("Delete saved photo", role: .destructive) { Task { _ = await store.photo(nil, account: account) } }.disabled(store.isBusy) }
                    if photoLoading { ProgressView("Preparing photo…") }
                    if let photoError { Text(photoError).foregroundStyle(.red) }
                }
                Section("Birthday · kept private") {
                    DatePicker("Birth date", selection: birthday, in: Date(timeIntervalSince1970: -2208988800)...Date(), displayedComponents: .date)
                        .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!).environment(\.calendar, Calendar(identifier: .gregorian))
                        .disabled(store.envelope?.profile != nil)
                    BirthDetailsEditor(time: $profile.birth_time, zone: $profile.birth_timezone, place: $profile.birth_place, longitude: $profile.birth_longitude, fold: $profile.birth_fold)
                    Text("Only your age and derived matching details are shown. You must be 18+. Contact support to correct a saved birthday.").font(.caption)
                }
                Section("How you connect") {
                    Picker("Personality type (optional)", selection: $profile.mbti) { ForEach(ConnectOptions.types, id: \.self) { Text($0 == "unknown" ? "Not sure" : $0).tag($0) } }
                    Picker("Communication", selection: $profile.communication) { ForEach(ConnectOptions.communication, id: \.0) { Text($0.1).tag($0.0) } }
                    Picker("Social pace", selection: $profile.social) { ForEach(ConnectOptions.social, id: \.0) { Text($0.1).tag($0.0) } }
                    Picker("Life priority", selection: $profile.value) { ForEach(ConnectOptions.values, id: \.0) { Text($0.1).tag($0.0) } }
                }
                Section("Who you'd like to meet") {
                    if profile.intention == "friendship" { Text("Friendship welcomes all genders. We use your age range and shared ways of connecting, without a gender filter.").font(.subheadline) } else {
                    ForEach(genders, id: \.0) { value in
                        Toggle(value.1, isOn: Binding(get: { profile.seeking.contains(value.0) }, set: { enabled in
                            profile.seeking.removeAll { $0 == value.0 }; if enabled { profile.seeking.append(value.0) }
                        }))
                    }
                    }
                    Stepper("Minimum age: \(profile.age_min)", value: $profile.age_min, in: 18...100)
                    Stepper("Maximum age: \(profile.age_max)", value: $profile.age_max, in: 18...100)
                    Text("Recommendations respect both people's preferences. City is shown, but distance filtering is not available yet.").font(.caption)
                }
                Section("You choose to be seen") {
                    Toggle("Show me in discovery", isOn: $profile.visible)
                    Toggle("I am 18+ and agree to this profile being stored by Omni and shown to eligible friends when visible.", isOn: $consent)
                    Text("Be yourself, be respectful and don't post contact details, explicit content or requests for money. Public profiles are reviewed before discovery. Block or report unwanted behavior at any time.").font(.caption)
                    if let url = URL(string: "mailto:seatrial.ai@gmail.com") { Link("Contact support", destination: url) }
                }
                if let error = store.error { Text(error).foregroundStyle(.red) }
                Button(store.isBusy ? "Saving…" : "Save my profile") { Task { if profile.intention == "friendship" { profile.consent_version = "friends-v1" }; if await store.save(profile, account: account) { if let photoData { if await store.photo(photoData, account: account) { dismiss() } } else { dismiss() } } } }.disabled(!valid || store.isBusy)
            }.navigationTitle("My Connect profile").toolbar { Button("Cancel") { dismiss() } }
        }.interactiveDismissDisabled(store.isBusy || photoLoading)
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }; photoLoading = true; photoError = nil
                Task {
                    defer { photoLoading = false }
                    do {
                        guard let data = try await item.loadTransferable(type: Data.self), data.count <= 20_000_000,
                              let image = UIImage(data: data), image.size.width >= 100, image.size.height >= 100 else { throw AccountError.invalidResponse }
                        let scale = min(1, 1000 / max(image.size.width, image.size.height))
                        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                        let format = UIGraphicsImageRendererFormat(); format.scale = 1
                        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
                        guard let jpeg = resized.jpegData(compressionQuality: 0.8), jpeg.count <= 1_048_576 else { throw AccountError.invalidResponse }
                        photoData = jpeg
                    } catch { photoError = "Choose a smaller photo (at least 100 pixels). Your profile can also stay photo-free." }
                }
            }
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
    @Environment(\.scenePhase) private var phase
    @StateObject private var chat = ConnectionChatStore()
    @State private var safety = false
    @State private var unmatch = false
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        Text("You both chose to connect.").font(OmniTheme.title(24))
                        Text(match.profile.pairing.prompt).font(.subheadline).foregroundStyle(OmniTheme.muted)
                        Text("Private conversation with \(match.profile.name). These messages are not sent to Omni AI.").font(.caption)
                        if chat.before != nil {
                            Button("Earlier messages") { Task { await chat.load(match.id, account: account, older: true) } }.disabled(chat.busy)
                        }
                        ForEach(chat.messages) { message in
                            HStack {
                                if message.mine { Spacer(minLength: 35) }
                                VStack(alignment: .leading, spacing: 6) {
                                    if let quote = message.reply_preview { Text(quote).font(.caption).foregroundStyle(.secondary).padding(8).background(.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 8)) }
                                    Text(message.text).textSelection(.enabled)
                                    HStack(spacing: 5) {
                                        Text(Date(timeIntervalSince1970: message.created_at), format: .dateTime.month(.abbreviated).day().hour().minute())
                                        if message.mine { Text(message.seen == true ? "Seen" : "Sent") }
                                    }.font(.caption2).foregroundStyle(.secondary)
                                }.padding(14).background(message.mine ? OmniTheme.sage : .white, in: RoundedRectangle(cornerRadius: 18))
                                    .contextMenu { Button("Reply", systemImage: "arrowshape.turn.up.left") { chat.reply = message } }
                                if !message.mine { Spacer(minLength: 35) }
                            }.id(message.id)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }.padding(20)
                }.onChange(of: chat.messages.last?.id) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .background(OmniTheme.paper)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    if let reply = chat.reply {
                        HStack { Text("Replying: " + reply.text).font(.caption).lineLimit(2); Spacer(); Button("Cancel reply", systemImage: "xmark") { chat.reply = nil }.labelStyle(.iconOnly) }
                    }
                    if let error = chat.error { Text(error).font(.caption).foregroundStyle(.red) }
                    if chat.pending != nil { Text("Awaiting confirmation. Retry sends this message only once. Keep this chat open to retry.").font(.caption) }
                    HStack(alignment: .bottom) {
                        TextField("Message…", text: $chat.draft, axis: .vertical).lineLimit(1...5)
                            .onChange(of: chat.draft) { _, value in chat.draft = String(value.prefix(1000)) }
                            .padding(12).background(OmniTheme.paper, in: RoundedRectangle(cornerRadius: 20))
                        Button(chat.pending == nil ? "Send" : "Retry", systemImage: "paperplane.fill") { Task { await chat.send(match.id, account: account) } }
                            .disabled(chat.busy || (chat.pending == nil && chat.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                    }
                }.padding().background(.regularMaterial)
            }
            .navigationTitle(match.profile.name).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(chat.pinned ? "Unpin conversation" : "Pin conversation", systemImage: "pin") { Task { await chat.settings(match.id, account: account, pin: !chat.pinned) } }
                        Button(chat.readReceipts ? "Turn off read receipts" : "Share read receipts", systemImage: "checkmark.bubble") { Task { await chat.settings(match.id, account: account, receipts: !chat.readReceipts) } }
                        Button("Refresh", systemImage: "arrow.clockwise") { Task { await chat.load(match.id, account: account) } }
                        Button("Block or report", systemImage: "shield") { safety = true }
                        Button("End connection", role: .destructive) { unmatch = true }
                    } label: { Image(systemName: "ellipsis.circle") }.disabled(chat.busy)
                }
            }
            .task(id: phase) {
                guard phase == .active else { return }
                while !Task.isCancelled {
                    if !safety && !unmatch { await chat.load(match.id, account: account) }
                    do { try await Task.sleep(for: .seconds(5)) } catch { return }
                }
            }
            .sheet(isPresented: $safety, onDismiss: { Task { await chat.load(match.id, account: account) } }) { DatingSafetyScreen(person: match.profile) }
            .confirmationDialog("End connection with \(match.profile.name)?", isPresented: $unmatch, titleVisibility: .visible) {
                Button("End connection", role: .destructive) {
                    Task { do { _ = try await account.authenticatedRequest(path: ConnectionChatStore.path(match.id), method: "DELETE"); dismiss() } catch { chat.error = DatingStore.message(error) } }
                }
            } message: { Text("This deletes the conversation and blocks future contact in Omni.") }
        }
    }
}
