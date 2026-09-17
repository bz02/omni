import SwiftUI

struct ConnectionsScreen: View {
    @EnvironmentObject private var store: ClarityStore
    @EnvironmentObject private var subscription: SubscriptionStore
    @State private var selected: ConnectionKind?
    @State private var paywall = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    PageHeading(eyebrow: "CONNECTION STARTS WITH YOU", title: "Less guessing.\nMore connection.", subtitle: "A little support for the moments that feel like a lot. You can do this on your own.")
                    OmniCard(color: OmniTheme.peach.opacity(0.7)) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 12) {
                                Eyebrow(text: "WAITING FOR A REPLY?")
                                Text("Your peace doesn't\nhave to wait.").font(OmniTheme.title(29))
                            }
                            Spacer(); Image(systemName: "cloud.sun").font(.system(size: 45, weight: .ultraLight)).padding(.top, 15)
                        }
                        Text("Make room between what happened and what your mind is telling you.").font(.system(size: 14)).foregroundStyle(OmniTheme.muted).lineSpacing(3)
                        OmniButton(title: "Untangle a thought") { begin(.uncertainty) }.accessibilityIdentifier("connect.uncertainty")
                    }
                    Eyebrow(text: "FOR WHERE YOU ARE RIGHT NOW")
                    ForEach([ConnectionKind.beforeDate, .afterDate, .conversation]) { kind in
                        Button { begin(kind) } label: {
                            HStack(spacing: 17) {
                                Image(systemName: kind.icon).font(.system(size: 25, weight: .light)).frame(width: 52, height: 62).background(OmniTheme.sage, in: RoundedRectangle(cornerRadius: 15))
                                VStack(alignment: .leading, spacing: 7) { Text(kind.rawValue).font(OmniTheme.title(24)); Text(kind.subtitle).font(.system(size: 13)).foregroundStyle(OmniTheme.muted).multilineTextAlignment(.leading) }
                                Spacer(minLength: 0); Image(systemName: "arrow.up.right").font(.system(size: 13))
                            }.padding(.vertical, 9)
                        }.buttonStyle(.plain)
                        Rectangle().fill(OmniTheme.line).frame(height: 0.7)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "leaf")
                        Text(subscription.hasPremium ? "Omni Plus · Make space as often as you need" : store.canAddConnection(premium: false) ? "One guided reflection is yours today" : "Today's reflection is saved. Come back tomorrow.")
                    }.font(.caption).foregroundStyle(OmniTheme.muted)
                    Text("Guided reflection, not a prediction about someone else's feelings. Your answers stay on this device.").font(.system(size: 11)).foregroundStyle(OmniTheme.muted).lineSpacing(3)
                }.padding(24).padding(.bottom, 20)
            }.background(OmniTheme.paper).toolbar(.hidden, for: .navigationBar)
                .sheet(item: $selected) { ConnectionFlow(kind: $0) }
                .sheet(isPresented: $paywall) { PlusScreen() }
        }
    }
    private func begin(_ kind: ConnectionKind) {
        if store.canAddConnection(premium: subscription.hasPremium) { selected = kind } else { paywall = true }
    }
}

struct ConnectionFlow: View {
    let kind: ConnectionKind
    @EnvironmentObject private var store: ClarityStore
    @EnvironmentObject private var subscription: SubscriptionStore
    @Environment(\.dismiss) private var dismiss
    @State private var fact = ""
    @State private var feeling = ""
    @State private var need = ""
    @State private var result: ConnectionEntry?
    @State private var paywall = false
    private var complete: Bool { [fact, feeling, need].allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 27) {
                    if let result {
                        HStack { Image(systemName: "checkmark.circle.fill"); Eyebrow(text: "SAVED TO YOUR JOURNAL") }
                        PageHeading(eyebrow: "A LITTLE CLARITY", title: "You can take\nthis slowly.")
                        OmniCard(color: OmniTheme.sage) {
                            Text(result.takeaway).font(.system(size: 17)).lineSpacing(7).textSelection(.enabled)
                        }
                        Text("This is an authored reflection framework shaped by your words. It doesn't assess, diagnose, or know the other person's intentions.").font(.caption).foregroundStyle(OmniTheme.muted).lineSpacing(4)
                        OmniButton(title: "Take this with me", icon: "checkmark") { dismiss() }.accessibilityIdentifier("connection.done")
                    } else {
                        PageHeading(eyebrow: "PRIVATE · ABOUT THREE MINUTES", title: kind.rawValue, subtitle: kind.subtitle)
                        EntryField(title: kind.firstPrompt, placeholder: "In my own words…", text: $fact)
                        EntryField(title: kind.secondPrompt, placeholder: "It's okay if it's a mix…", text: $feeling)
                        EntryField(title: kind.thirdPrompt, placeholder: "One small, specific thing…", text: $need)
                        OmniButton(title: "Find a little clarity", icon: "sparkles") {
                            guard store.canAddConnection(premium: subscription.hasPremium) else { paywall = true; return }
                            result = store.addConnection(kind: kind, fact: fact, feeling: feeling, need: need, premium: subscription.hasPremium)
                        }.disabled(!complete).opacity(complete ? 1 : 0.5).accessibilityIdentifier("connection.save")
                        Text("You never have to share screenshots or someone else's private messages. Describe only what you're comfortable keeping here.").font(.caption).foregroundStyle(OmniTheme.muted).lineSpacing(4)
                    }
                }.padding(24)
            }.scrollDismissesKeyboard(.interactively).background(OmniTheme.paper).navigationTitle(kind.rawValue).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(result == nil ? "Close" : "Done") { dismiss() } } }
                .sheet(isPresented: $paywall) { PlusScreen() }
        }.interactiveDismissDisabled(result == nil && (!fact.isEmpty || !feeling.isEmpty || !need.isEmpty))
    }
}
