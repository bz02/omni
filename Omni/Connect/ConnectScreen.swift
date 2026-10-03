import SwiftUI

struct ConnectScreen: View {
    @EnvironmentObject private var account: AccountStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var connect = ConnectStore()
    @State private var showAccount = false
    @State private var showProfile = false
    @State private var selected: ConnectInvitation?
    @State private var deleting: ConnectInvitation?
    @State private var erase = false
    @State private var kind = "dating"
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PageHeading(eyebrow: "CONNECT · BY CHOICE", title: "A little chemistry.\nA real conversation.", subtitle: "Find common ground through your goals, five elements, zodiac and personality.")
                    if !account.isSignedIn {
                        OmniCard(color: OmniTheme.sage) {
                            Text("Start with someone you know.").font(OmniTheme.title(25))
                            Text("Create your profile, send a private invitation, and see your report when they choose to share. They can respond on the web without downloading Omni.")
                            OmniButton(title: "Sign in to create my profile", icon: "person.crop.circle") { showAccount = true }.accessibilityIdentifier("connect.signIn")
                        }
                    } else if let profile = connect.envelope?.profile {
                        profileCard(profile)
                        invitationCard
                        results
                        Button("Delete my Connect profile & reports", role: .destructive) { erase = true }.font(.caption).disabled(connect.busy)
                    } else if connect.envelope != nil {
                        OmniCard(color: OmniTheme.sage) {
                            Eyebrow(text: "STEP 1 · YOUR STARTING POINT")
                            Text("More than your Sun sign.").font(OmniTheme.title(26))
                            Text("Share the basics and what matters to you. Your journal and AI memories stay separate.")
                            OmniButton(title: "Create my Connect profile") { showProfile = true }.accessibilityIdentifier("connect.createProfile")
                        }
                    }
                    if connect.busy { ProgressView("Connecting…") }
                    if let error = connect.error {
                        Text(error).font(.subheadline).foregroundStyle(.red).accessibilityIdentifier("connect.error")
                        Button("Try again") { Task { await connect.load(account) } }
                    }
                    OmniCard {
                        Eyebrow(text: "HOW RECOMMENDATIONS WORK")
                        Text("People first. Symbols second.").font(OmniTheme.title(24))
                        Text("Goals and stated preferences carry 85% of the index. Zodiac, five elements and optional personality type add 15%. Reports explain every lens and give you questions to ask each other.").font(.subheadline)
                        Text("Recommendations come from people who accept your dating invitations and share compatible intentions. Friendship reports stay separate. No fabricated profiles or contact imports.").font(.caption).foregroundStyle(OmniTheme.muted)
                        Text("Five elements use a self-reported element or the civil birth date's day stem, not a full Ba Zi chart. Zodiac uses approximate Sun-sign dates. These are creative references, not a prediction of love or safety.").font(.caption).foregroundStyle(OmniTheme.muted)
                    }
                }.padding(24)
            }.background(OmniTheme.paper).navigationTitle("Cosmic connections").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }; ToolbarItem(placement: .primaryAction) { if account.isSignedIn { Button("Refresh", systemImage: "arrow.clockwise") { Task { await connect.load(account) } }.disabled(connect.busy) } } }
                .task(id: account.accountID) { await connect.load(account) }
                .refreshable { await connect.load(account) }
                .sheet(isPresented: $showAccount) { AccountScreen() }
                .sheet(isPresented: $showProfile) { ConnectProfileEditor(connect: connect) }
                .sheet(item: $connect.link) { link in
                    NavigationStack {
                        VStack(alignment: .leading, spacing: 24) {
                            PageHeading(eyebrow: "STEP 2 · SEND IT YOURSELF", title: "An invitation,\nnot a prediction.", subtitle: "This one-person link expires in 7 days. Only send it to the person you want to invite; anyone with the unused link can respond.")
                            ShareLink(item: link.url, subject: Text("Explore our connection on Omni"), message: Text("Want to compare our zodiac, five elements and what matters to us? Fill this in only if you want to share a private report with me.")) { Label("Share private invitation", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity).padding().background(OmniTheme.sage, in: RoundedRectangle(cornerRadius: 16)) }.accessibilityIdentifier("connect.shareInvite")
                            Text("Omni does not send messages or access your contacts. The other person chooses what to share. Refresh Connect after they finish.").font(.subheadline).foregroundStyle(OmniTheme.muted)
                            Spacer()
                        }.padding(24).background(OmniTheme.paper).toolbar { Button("Done") { connect.link = nil } }
                    }.presentationDetents([.large])
                }
                .sheet(item: $selected) { item in if let report = item.report { ConnectReportScreen(report: report) } }
                .confirmationDialog("Remove this invitation and any shared report from both sides?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                    Button("Remove", role: .destructive) { if let item = deleting { Task { await connect.remove(item, account: account) } }; deleting = nil }
                } message: { Text("Its links will stop working. Copies already exported cannot be recalled.") }
                .confirmationDialog("Delete your Connect profile, all invitations and reports?", isPresented: $erase, titleVisibility: .visible) {
                    Button("Delete Connect data", role: .destructive) { Task { await connect.erase(account) } }
                } message: { Text("Your journal, AI memory, subscription and Omni account remain available.") }
        }
    }
    private func profileCard(_ p: ConnectProfile) -> some View {
        OmniCard(color: OmniTheme.sage) {
            HStack { Eyebrow(text: "YOUR CONNECT PROFILE"); Spacer(); Button("Edit") { showProfile = true } }
            Text(p.name).font(OmniTheme.title(30))
            Text("\(ConnectOptions.title(p.intention)) · \(p.mbti == "unknown" ? "Personality optional" : p.mbti)").font(.subheadline)
            Text("Your birthday stays private. Each invitation uses the profile you shared when it was created.").font(.caption).foregroundStyle(OmniTheme.muted)
        }
    }
    private var invitationCard: some View {
        OmniCard(color: OmniTheme.peach.opacity(0.6)) {
            Eyebrow(text: "STEP 2 · INVITE SOMEONE")
            Text("Who are you curious about?").font(OmniTheme.title(25))
            Picker("Connection", selection: $kind) { Text("Dating").tag("dating"); Text("Friendship").tag("friendship") }.pickerStyle(.segmented)
            OmniButton(title: "Create private invitation", icon: "link") { Task { await connect.invite(kind: kind, account: account) } }.disabled(connect.busy).accessibilityIdentifier("connect.invite")
        }
    }
    private var results: some View {
        VStack(alignment: .leading, spacing: 18) {
            Eyebrow(text: "STEP 3 · YOUR CONNECTIONS")
            if connect.recommendations.isEmpty {
                Text("Your next connection starts with an invitation.").font(OmniTheme.title(24))
                Text("When someone accepts a dating invite and your intentions align, they appear here in order of conversation fit. You decide who feels right.").font(.subheadline).foregroundStyle(OmniTheme.muted)
            } else {
                Text("Worth getting to know").font(OmniTheme.title(27))
                ForEach(connect.recommendations) { invitationRow($0) }
            }
            let others = (connect.envelope?.invitations ?? []).filter { $0.report?.recommended != true }
            if !others.isEmpty { Text("Invitations & other reports").font(OmniTheme.title(23)); ForEach(others) { invitationRow($0) } }
        }
    }
    private func invitationRow(_ item: ConnectInvitation) -> some View {
        OmniCard {
            if let report = item.report {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) { Text(report.names.last ?? "Connection").font(OmniTheme.title(27)); Text(report.recommendation).font(.subheadline); Text(item.kind.capitalized).font(.caption).foregroundStyle(OmniTheme.muted) }
                    Spacer(); Text("\(report.score)").font(OmniTheme.title(42)); Text("/100").font(.caption).padding(.top, 24)
                }
                Text(report.strengths.first ?? "Start with a conversation.").font(.subheadline).foregroundStyle(OmniTheme.muted)
                Button("Read our report", systemImage: "sparkles") { selected = item }
            } else {
                Label("Waiting for your \(item.kind == "dating" ? "date" : "friend")", systemImage: "envelope")
                Text("Invite \(item.id.uuidString.prefix(6).lowercased()) · expires \(Date(timeIntervalSince1970: item.expires_at).formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(OmniTheme.muted)
                Text("If you lost the link, remove this invitation and create another.").font(.caption)
            }
            Button("Remove", role: .destructive) { deleting = item }.font(.caption).disabled(connect.busy)
        }
    }
}

enum ConnectOptions {
    static let intentions = [("long_term", "Long-term relationship"), ("exploring", "Exploring"), ("casual", "Something casual"), ("friendship", "Friendship")]
    static let communication = [("mix", "A balance of talking and space"), ("talk_it_out", "Talk it through"), ("time_to_think", "Time to think first")]
    static let social = [("mix", "A little of both"), ("quiet", "Quiet, small-group time"), ("outgoing", "Going out and meeting people")]
    static let values = [("growth", "Growth"), ("stability", "Stability"), ("adventure", "Adventure"), ("family", "Family"), ("creativity", "Creativity")]
    static let elements = [("auto", "Use birth date's day element"), ("wood", "Wood — self-reported"), ("fire", "Fire — self-reported"), ("earth", "Earth — self-reported"), ("metal", "Metal — self-reported"), ("water", "Water — self-reported")]
    static let types = ["unknown", "ENFJ", "ENFP", "ENTJ", "ENTP", "ESFJ", "ESFP", "ESTJ", "ESTP", "INFJ", "INFP", "INTJ", "INTP", "ISFJ", "ISFP", "ISTJ", "ISTP"]
    static func title(_ key: String) -> String { intentions.first { $0.0 == key }?.1 ?? key }
}
struct ConnectProfileEditor: View {
    @ObservedObject var connect: ConnectStore
    @EnvironmentObject private var account: AccountStore
    @Environment(\.dismiss) private var dismiss
    @State private var profile = ConnectProfile()
    @State private var birthday = DateComponents(calendar: .current, year: 1995, month: 1, day: 1).date ?? .now
    @State private var consent = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Your starting point") {
                    TextField("First name or nickname", text: $profile.name).onChange(of: profile.name) { _, value in profile.name = String(value.prefix(40)) }
                    DatePicker("Birthday", selection: $birthday, in: ...Date.now, displayedComponents: .date)
                    Picker("Personality type", selection: $profile.mbti) { ForEach(ConnectOptions.types, id: \.self) { Text($0 == "unknown" ? "Unknown / prefer not to say" : $0).tag($0) } }
                    choice("Five-element lens", $profile.five_element, ConnectOptions.elements)
                }
                Section("What actually matters") {
                    choice("Looking for", $profile.intention, ConnectOptions.intentions)
                    choice("Communication", $profile.communication, ConnectOptions.communication)
                    choice("Social pace", $profile.social, ConnectOptions.social)
                    choice("Life priority", $profile.value, ConnectOptions.values)
                }
                Section {
                    Toggle("I am 18+ and agree to save this Connect profile and share derived details and preferences through invitations I create.", isOn: $consent)
                    Text("Your full birthday stays in your private profile. Reports share your nickname, age, derived zodiac/element, personality and preferences with the person who accepts. No automatic AI memory, public discovery or contact import. Delete your Connect data any time. Existing reports retain the profile shared at invitation time.").font(.caption)
                }
                if let error = connect.error { Section { Text(error).foregroundStyle(.red) } }
                Section {
                    Button("Save my Connect profile") {
                        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
                        profile.birth_date = f.string(from: birthday)
                        Task { if await connect.save(profile, account: account) { dismiss() } }
                    }.disabled(!consent || profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || connect.busy)
                }
            }.navigationTitle("My Connect profile").toolbar { Button("Cancel") { dismiss() } }
                .onAppear { if let saved = connect.envelope?.profile { profile = saved; let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; birthday = f.date(from: saved.birth_date) ?? birthday } }
        }
    }
    private func choice(_ title: String, _ value: Binding<String>, _ options: [(String,String)]) -> some View {
        Picker(title, selection: value) { ForEach(options, id: \.0) { Text($0.1).tag($0.0) } }
    }
}
struct ConnectReportScreen: View {
    let report: ConnectReport
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    PageHeading(eyebrow: "YOUR SHARED REPORT", title: report.names.joined(separator: " + "))
                    OmniCard(color: OmniTheme.sage) {
                        Text("\(report.score) / 100").font(OmniTheme.title(48))
                        Text(report.recommendation).font(OmniTheme.title(26))
                        Text("Conversation fit, not a success probability.").font(.caption)
                    }
                    block("Where you connect", report.strengths)
                    block("Make room for differences", report.friction)
                    Text("Your seven lenses").font(OmniTheme.title(28))
                    ForEach(report.dimensions) { dimension in
                        OmniCard {
                            HStack { Text(dimension.title).font(.headline); Spacer(); Text(dimension.score.map { "\($0)/100" } ?? "Optional").font(.subheadline) }
                            Text(dimension.explanation).font(.subheadline).foregroundStyle(OmniTheme.muted)
                            Text("Ask each other: \(dimension.prompt)").font(.subheadline).padding(12).background(OmniTheme.sage, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    block("A low-pressure first plan", [report.date_idea])
                    Text(report.disclaimer).font(.caption).foregroundStyle(OmniTheme.muted)
                    ShareLink(item: report.shareText) { Label("Share report summary", systemImage: "square.and.arrow.up") }
                    Text("Sharing sends both names and parts of your report to the destination you choose. Check with the other person first.").font(.caption).foregroundStyle(OmniTheme.muted)
                }.padding(24)
            }.background(OmniTheme.paper).navigationTitle("Connection report").navigationBarTitleDisplayMode(.inline).toolbar { Button("Done") { dismiss() } }
        }
    }
    private func block(_ title: String, _ lines: [String]) -> some View { VStack(alignment: .leading, spacing: 12) { Text(title).font(OmniTheme.title(27)); ForEach(Array(lines.enumerated()), id: \.offset) { _, line in Text(line).font(.subheadline).foregroundStyle(OmniTheme.muted) } } }
}
