import SwiftUI

@main
struct OmniDailyApp: App {
    @StateObject private var store = ClarityStore()
    @StateObject private var subscription = SubscriptionStore()
    @StateObject private var account = AccountStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            MemoryScopeView(accountID: account.accountID)
            .id(account.accountID?.uuidString ?? "device-local")
            .environmentObject(store).environmentObject(subscription).environmentObject(account)
            .tint(OmniTheme.ink).foregroundStyle(OmniTheme.ink)
            .preferredColorScheme(.light)
            .alert("Couldn't save changes", isPresented: Binding(get: { store.errorMessage != nil && !store.recoveryRequired }, set: { if !$0 { store.errorMessage = nil } })) {
                Button("OK") { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
            .task {
                subscription.accountStore = account
                await account.refreshAccount()
                await subscription.refreshEntitlements()
                await subscription.syncAccountEntitlements()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await account.refreshAccount(); await subscription.refreshEntitlements(); await subscription.syncAccountEntitlements() }
            }
        }
    }
}

/// Changing accounts recreates the entire memory UI and cancels its pending work.
/// Guest data and the journal are never implicitly imported into an account.
private struct MemoryScopeView: View {
    @EnvironmentObject private var store: ClarityStore
    @StateObject private var memory: MemoryStore

    init(accountID: UUID?) {
        _memory = StateObject(wrappedValue: accountID.map { MemoryStore.forAccount($0) } ?? MemoryStore())
    }

    var body: some View {
        Group {
            if store.recoveryRequired { RecoveryView() }
            else if store.profile == nil { WelcomeFlow() }
            else { OmniTabView() }
        }.environmentObject(memory)
    }
}

struct OmniTabView: View {
    @State private var selectedTab = 0
    var body: some View {
        TabView(selection: $selectedTab) {
            TodayScreen().tabItem { Label("Today", systemImage: "sun.max") }.tag(0)
            ConnectionsScreen().tabItem { Label("Connect", systemImage: "heart") }.tag(1)
            MemoryConversationScreen().tabItem { Label("Talk", systemImage: "bubble.left.and.bubble.right") }.tag(2)
            JournalScreen().tabItem { Label("Journal", systemImage: "book.closed") }.tag(3)
            YouScreen().tabItem { Label("You", systemImage: "person.crop.circle") }.tag(4)
        }
    }
}

struct WelcomeFlow: View {
    @EnvironmentObject private var store: ClarityStore
    @State private var started = false
    @State private var name = ""
    @State private var focus: LifeFocus = .dating
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(spacing: 8) { Image(systemName: "sparkle"); Text("omni").font(.system(size: 27, weight: .medium, design: .serif)); Spacer(); Eyebrow(text: "A little more you") }
                    if !started {
                        CelestialArt().frame(height: 245).padding(.top, 15)
                        PageHeading(eyebrow: "YOUR SPACE TO FEEL UNDERSTOOD", title: "Come back\nto yourself.", subtitle: "For the unread text, the first-date nerves, and the days you need a little steadiness.")
                        VStack(alignment: .leading, spacing: 16) {
                            welcomePoint("sun.max", "A daily moment that's yours")
                            welcomePoint("heart", "A calmer way to navigate connection")
                            welcomePoint("lock", "A private journal. No account needed.")
                        }
                        OmniButton(title: "Find my starting point") { withAnimation { started = true } }.accessibilityIdentifier("welcome.start")
                        Text("Reflection and inspiration, with you in the driver's seat.").font(.caption).foregroundStyle(OmniTheme.muted)
                    } else {
                        PageHeading(eyebrow: "LET'S START WITH YOU", title: "What's on\nyour heart?", subtitle: "Choose a starting point. You can change it any time.")
                        TextField("Your first name (optional)", text: $name).textContentType(.givenName).padding(18).background(.white, in: RoundedRectangle(cornerRadius: 16)).onChange(of: name) { _, value in name = String(value.prefix(60)) }
                        ForEach(LifeFocus.allCases) { choice in
                            Button { focus = choice } label: {
                                HStack(spacing: 18) {
                                    Image(systemName: choice.icon).font(.title2).frame(width: 28)
                                    VStack(alignment: .leading, spacing: 5) { Text(choice.rawValue).font(.headline); Text(choice.subtitle).font(.subheadline).foregroundStyle(OmniTheme.muted) }
                                    Spacer(); Image(systemName: focus == choice ? "checkmark.circle.fill" : "circle").font(.title3)
                                }.padding(21).background(focus == choice ? OmniTheme.sage : .white.opacity(0.7), in: RoundedRectangle(cornerRadius: 20))
                            }.buttonStyle(.plain).accessibilityAddTraits(focus == choice ? .isSelected : [])
                        }
                        Text("Your journal stays on this device. Optional online conversations and birth-chart calculations each ask separately before sharing any relevant details.").font(.caption).foregroundStyle(OmniTheme.muted).lineSpacing(4)
                        OmniButton(title: "Make a little space") { _ = store.onboard(name: name, focus: focus) }.accessibilityIdentifier("welcome.finish")
                        Button("Back") { started = false }.font(.subheadline).frame(maxWidth: .infinity)
                    }
                }.padding(26).padding(.bottom, 22)
            }.background(OmniTheme.paper).toolbar(.hidden, for: .navigationBar)
        }
    }
    private func welcomePoint(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) { Image(systemName: icon).frame(width: 22); Text(text).font(.system(size: 14)) }
    }
}
