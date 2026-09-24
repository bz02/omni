import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct JournalExport: FileDocument {
    static let readableContentTypes = [UTType.json]
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct YouScreen: View {
    @EnvironmentObject private var account: AccountStore
    @EnvironmentObject private var memory: MemoryStore
    @EnvironmentObject private var store: ClarityStore
    @EnvironmentObject private var subscription: SubscriptionStore
    @State private var paywall = false
    @State private var privacy = false
    @State private var reminders = false
    @State private var profileEdit = false
    @State private var chart = false
    @State private var reset = false
    @State private var showMemory = false
    @State private var showAccount = false
    @State private var showSync = false
    @State private var export = false
    @State private var document = JournalExport(data: Data())
    @State private var message: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PageHeading(eyebrow: "YOUR OWN LITTLE UNIVERSE", title: store.profile?.name.isEmpty == false ? store.profile!.name : "Beautifully\nunfinished.", subtitle: "You get to keep becoming.")
                    HStack {
                        ZStack { Circle().fill(OmniTheme.sage).frame(width: 75, height: 75); Image(systemName: store.profile?.focus.icon ?? "sun.max").font(.system(size: 30, weight: .ultraLight)) }
                        VStack(alignment: .leading, spacing: 7) { Eyebrow(text: "MAKING SPACE FOR"); Text(store.profile?.focus.rawValue ?? "Myself").font(OmniTheme.title(24)) }
                        Spacer(); Button("Edit") { profileEdit = true }.font(.subheadline)
                    }
                    Button { paywall = true } label: {
                        OmniCard(color: OmniTheme.ink) {
                            HStack { Text(subscription.hasPremium ? "Omni Plus is yours" : "A little more room to grow").font(OmniTheme.title(24)); Spacer(); Image(systemName: "sparkles") }.foregroundStyle(.white)
                            Text(subscription.hasPremium ? "Manage your subscription" : "Explore Omni Plus").font(.system(size: 13)).foregroundStyle(.white.opacity(0.75))
                        }
                    }.buttonStyle(.plain)
                    VStack(spacing: 0) {
                        settingsRow("A gentle reminder", "bell") { reminders = true }
                        settingsRow("What Omni remembers", "brain.head.profile") { showMemory = true }
                        if account.hasConfiguration {
                            settingsRow(account.isSignedIn ? "Your Omni account" : "Sign in with Apple", "person.crop.circle.badge.checkmark") { showAccount = true }
                            if account.isSignedIn {
                                settingsRow("Sync account memory", "arrow.triangle.2.circlepath") { showSync = true }
                            }
                        }
                        settingsRow("Export my journal", "square.and.arrow.up") { prepareExport() }
                        settingsRow("Privacy & your data", "lock") { privacy = true }
                        if ChartScreen.isAvailable { settingsRow("Explore my birth chart", "sparkles.rectangle.stack") { chart = true } }
                        if let support = ReleaseLinks.support { Link(destination: support) { HStack { Label("Get in touch", systemImage: "envelope"); Spacer(); Image(systemName: "arrow.up.right") }.padding(.vertical, 20) } }
                    }.font(.system(size: 15))
                    Text("Omni is a space for reflection and inspiration. It doesn't predict your future or replace professional care. You decide what fits your life.").font(.system(size: 12)).foregroundStyle(OmniTheme.muted).lineSpacing(4)
                    Button("Erase data on this device", role: .destructive) { reset = true }.font(.system(size: 13))
                    Text("OMNI · 1.0").font(.system(size: 10, design: .monospaced)).tracking(2).foregroundStyle(OmniTheme.muted).padding(.top, 8)
                }.padding(24).padding(.bottom, 20)
            }.background(OmniTheme.paper).toolbar(.hidden, for: .navigationBar)
                .sheet(isPresented: $paywall) { PlusScreen() }
                .sheet(isPresented: $privacy) { PrivacyScreen() }
                .sheet(isPresented: $reminders) { ReminderScreen() }
                .sheet(isPresented: $profileEdit) { EditProfileSheet() }
                .sheet(isPresented: $chart) { ChartScreen() }
                .sheet(isPresented: $showMemory) { MemoryScreen() }
                .sheet(isPresented: $showAccount) { AccountScreen() }
                .sheet(isPresented: $showSync) { MemorySyncScreen() }
                .fileExporter(isPresented: $export, document: document, contentType: .json, defaultFilename: "Omni-journal") { result in
                    if case .failure = result { message = "Your journal couldn't be exported. Please try again." }
                }
                .confirmationDialog("Erase your profile, journal and the memories currently open on this device? Cloud copies and other account caches remain; delete your cloud account in Account settings to remove its server data. Your Apple subscription is managed separately.", isPresented: $reset, titleVisibility: .visible) {
                    Button("Erase local data", role: .destructive) {
                        guard memory.reset() else { message = memory.errorMessage ?? "Your memories couldn't be erased. Please try again."; return }
                        MemorySessionVault.remove(ownerID: memory.ownerID)
                        if store.reset() { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["omni.evening"]); UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["omni.evening"]) }
                    }
                }
                .alert("Your data", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") { message = nil } } message: { Text(message ?? "") }
        }
    }
    private func settingsRow(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) { Button(action: action) { HStack { Image(systemName: icon).frame(width: 25); Text(title); Spacer(); Image(systemName: "chevron.right").font(.caption) }.padding(.vertical, 20).contentShape(Rectangle()) }.buttonStyle(.plain); Rectangle().fill(OmniTheme.line).frame(height: 0.6) }
    }
    private func prepareExport() {
        do { document = JournalExport(data: try store.exportData()); export = true }
        catch { message = "Your journal couldn't be prepared for export. Please try again." }
    }
}

struct EditProfileSheet: View {
    @EnvironmentObject private var store: ClarityStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var focus: LifeFocus = .myself
    var body: some View {
        NavigationStack {
            Form {
                TextField("First name (optional)", text: $name).onChange(of: name) { _, value in name = String(value.prefix(60)) }
                Picker("My focus", selection: $focus) { ForEach(LifeFocus.allCases) { Text($0.rawValue).tag($0) } }
            }.navigationTitle("Your starting point").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { if store.onboard(name: name, focus: focus) { dismiss() } } } }
        }.onAppear { name = store.profile?.name ?? ""; focus = store.profile?.focus ?? .myself }.presentationDetents([.medium])
    }
}

struct PrivacyScreen: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PageHeading(eyebrow: "PERSONAL STAYS PERSONAL", title: "A space\nyou control.")
                    privacySection("Your journal", "Your name, focus, feelings, intentions and connection reflections are stored on this device with iOS file protection. They are excluded from the app's device backup. Account sign-in, online chat and memory sync do not upload your journal. Omni includes no advertising SDK or third-party analytics. Deleting the app can remove these records, so export anything you want to keep.")
                    privacySection("Reflection guidance", "Daily reflections and guided connection exercises use authored prompts and your own words on your device. They do not send your journal to an AI provider. Online AI conversations are separate and ask for your permission.")
                    privacySection("Saved memory & conversations", "Memory is off until you choose to enable it. Plus lets you add facts, explicitly save your own words, or review an AI memory suggestion before saving it. These records are protected on this device and excluded from device backup. Existing memories and history remain available to view, correct, delete and export after Plus ends. Local memory and each signed-in account use separate archives; signing in does not upload your journal or local memories.")
                    privacySection("Optional account & sync", "Sign in with Apple connects your Omni account. Apple verifies your identity; Omni stores an account identifier, protected session credentials and subscription status. Sync account memory asks separately before uploading saved account memories, conversation history and memory/history settings. Sync is manual, with choices for conflicting copies. Online chat consent stays separate on each iPhone. Sign-out leaves a protected account cache on this device, accessible in Omni when that account signs in again.")
                    privacySection("Optional online conversations", "Online conversations require your Omni account, a verified Plus subscription, an internet connection and separate consent. Your message and up to eight recent messages from the current conversation are sent through Omni's service to OpenAI. If memory is on, up to six relevant saved memories can also be included. Your journal is not included. Chat itself does not save another copy on Omni's server; a later manual memory sync can upload saved history. OpenAI's API data retention policies still apply. Turn off online conversations to stop future sending.")
                    privacySection("Temporary & forgotten", "Temporary conversations exclude saved memories and don't save history or new memories. They clear when you leave the conversation screen or background the app. Deleting a saved memory does not erase words from older chats; deleting its source conversation also removes memories created from that conversation. Turn off online conversations to stop future sending.")
                    privacySection("Optional birth charts", "If birth charts are enabled, a place search sends the location text you enter to Apple's geocoding service. Chart calculation asks separately for your permission to send birth time, time zone and coordinates to the chart service. No journal entries are included. The chart is kept only in memory in this version.")
                    privacySection("Purchases & reminders", "Apple processes subscriptions and payment information. You can purchase, restore, and use on-device Plus without an Omni account. If you choose to sign in for online features, Omni verifies your subscription and links an unlinked purchase to that account. Optional reminders are scheduled on your device, with generic text that doesn't reveal your journal.")
                    privacySection("Export & erase", "Export journal records in You → Export my journal and memories in What Omni remembers → Export. Sync also offers a cloud-copy export when resolving a conflict. Erase data on this device clears the journal and currently open memory archive; cloud records and other account caches remain. Delete cloud copy removes only the server snapshot. Delete account in Your Omni account removes server account data, revokes login and clears this account's cache here. Other devices learn of deletion when they reconnect; existing offline caches and exported files remain separate copies. Data deletion doesn't cancel an Apple subscription; manage it in your App Store account settings.")
                    if let url = ReleaseLinks.privacy { Link("Read the published privacy policy", destination: url) }
                    if let support = ReleaseLinks.support { Link("Contact support", destination: support) }
                }.padding(24)
            }.background(OmniTheme.paper).navigationTitle("Privacy & your data").navigationBarTitleDisplayMode(.inline).toolbar { Button("Done") { dismiss() } }
        }
    }
    private func privacySection(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) { Text(title).font(OmniTheme.title(25)); Text(text).font(.system(size: 14)).foregroundStyle(OmniTheme.muted).lineSpacing(5) }
    }
}

struct ReminderScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var time = Calendar.current.date(from: DateComponents(hour: 20)) ?? Date()
    @State private var enabled = false
    @State private var saving = false
    @State private var message: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    PageHeading(eyebrow: "AN INVITATION, NEVER A NUDGE", title: "A moment\nto come home.", subtitle: "An optional daily reminder to check in. We'll keep the words on your lock screen private.")
                    Toggle("Daily reminder", isOn: $enabled)
                    if enabled { DatePicker("At a time that suits you", selection: $time, displayedComponents: .hourAndMinute) }
                    OmniCard(color: OmniTheme.sage) { Eyebrow(text: "YOUR REMINDER WILL SAY"); Text("A little space for you").font(.headline); Text("If it feels right, take a moment to check in with yourself.").font(.subheadline) }
                    if let message { Text(message).font(.subheadline).foregroundStyle(OmniTheme.muted) }
                    OmniButton(title: saving ? "Saving…" : "Save reminder", icon: "checkmark") { Task { await save() } }.disabled(saving)
                }.padding(24)
            }.background(OmniTheme.paper).toolbar { Button("Done") { dismiss() } }.task { await load() }
        }
    }
    private func load() async {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        if let request = requests.first(where: { $0.identifier == "omni.evening" }), let trigger = request.trigger as? UNCalendarNotificationTrigger {
            enabled = true; time = Calendar.current.date(from: trigger.dateComponents) ?? time
        }
    }
    private func save() async {
        saving = true
        defer { saving = false }
        let center = UNUserNotificationCenter.current()
        if !enabled { center.removePendingNotificationRequests(withIdentifiers: ["omni.evening"]); dismiss(); return }
        do {
            guard try await center.requestAuthorization(options: [.alert, .sound]) else { message = "Notifications are off. You can allow them for Omni in iPhone Settings, or keep checking in without a reminder."; return }
            let content = UNMutableNotificationContent()
            content.title = "A little space for you"
            content.body = "If it feels right, take a moment to check in with yourself."
            content.sound = .default
            let components = Calendar.current.dateComponents([.hour, .minute], from: time)
            try await center.add(UNNotificationRequest(identifier: "omni.evening", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)))
            dismiss()
        } catch { message = "Your reminder couldn't be saved. Please try again." }
    }
}

struct RecoveryView: View {
    @EnvironmentObject private var store: ClarityStore
    @State private var document = JournalExport(data: Data())
    @State private var export = false
    @State private var reset = false
    @State private var message: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeading(eyebrow: "YOUR WRITING IS STILL HERE", title: "Let's protect\nyour journal.", subtitle: store.errorMessage)
            OmniButton(title: "Export a backup", icon: "square.and.arrow.up") { do { document = JournalExport(data: try store.exportData()); export = true } catch { message = "The backup couldn't be exported. Your original file has been kept." } }
            if let message { Text(message).font(.subheadline) }
            Button("Erase data and start fresh", role: .destructive) { reset = true }
        }.padding(26).frame(maxWidth: .infinity, maxHeight: .infinity).background(OmniTheme.paper)
            .fileExporter(isPresented: $export, document: document, contentType: .json, defaultFilename: "Omni-recovery") { result in if case .failure = result { message = "The backup couldn't be saved. Please try again." } }
            .confirmationDialog("Erase the unreadable journal? Export a backup first. This cannot be undone.", isPresented: $reset, titleVisibility: .visible) { Button("Erase and restart", role: .destructive) { _ = store.reset() } }
    }
}
