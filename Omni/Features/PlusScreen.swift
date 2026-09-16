import SwiftUI
import StoreKit

enum ReleaseLinks {
    static func url(_ key: String) -> URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              let url = URL(string: value), url.scheme == "https", url.host != nil,
              !value.contains("example."), !value.contains("$(") else { return nil }
        return url
    }
    static var privacy: URL? { url("OMNI_PRIVACY_URL") }
    static var support: URL? { url("OMNI_SUPPORT_URL") }
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static var purchasesReady: Bool {
        #if DEBUG
        return true
        #else
        return privacy != nil && support != nil
        #endif
    }
}

struct PlusScreen: View {
    @EnvironmentObject private var subscription: SubscriptionStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var selectedID = SubscriptionStore.yearlyID
    @State private var privacy = false
    private var selectedProduct: Product? { subscription.products.first { $0.id == selectedID } ?? subscription.products.first }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack { Eyebrow(text: "OMNI PLUS"); Spacer(); Image(systemName: "sparkles").foregroundStyle(OmniTheme.gold) }
                    Text(subscription.hasPremium ? "A little more\nspace, yours." : "Know yourself.\nMore deeply.").font(OmniTheme.title(43))
                    Text("For the patterns you're noticing and the conversations you're learning to have.").font(.system(size: 16)).foregroundStyle(OmniTheme.muted).lineSpacing(4)
                    VStack(alignment: .leading, spacing: 21) {
                        feature("heart", "More room to untangle", "Unlimited guided connection reflections, whenever you want to pause.")
                        feature("chart.bar.xaxis", "A gentler view of your week", "See your recorded feelings, evening reflections, and intentions together.")
                        feature("brain.head.profile", "Remember what matters", "Choose the details Omni remembers for future conversations. Review, edit or delete them any time.")
                        feature("bubble.left.and.bubble.right", "Talk things through", "Sign in with Apple for online AI conversations. We'll ask for your permission before sharing conversation content with OpenAI.")
                        feature("lock", "Your choices, your space", "Your journal stays on this iPhone. Syncing account memories and saved conversations is optional and asks for separate permission.")
                    }.padding(.vertical, 8)
                    if subscription.hasPremium {
                        OmniCard(color: OmniTheme.sage) { Label("Your Plus subscription is active", systemImage: "checkmark.seal.fill"); Text("Thank you for making space for yourself.").font(.subheadline) }
                        Button("Manage subscription") { openURL(URL(string: "https://apps.apple.com/account/subscriptions")!) }
                    } else if !ReleaseLinks.purchasesReady {
                        unavailable("Plus isn't available in this build yet. Your free reflection tools are ready to use.")
                    } else if subscription.products.isEmpty {
                        if subscription.isLoading { ProgressView("Finding available plans…").frame(maxWidth: .infinity).padding() }
                        else { unavailable("Plans are unavailable right now. You can keep using Omni for free."); Button("Try again") { Task { await subscription.loadProducts() } } }
                    } else {
                        ForEach(subscription.products) { product in
                            Button { selectedID = product.id } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(product.id == SubscriptionStore.yearlyID ? "Yearly" : "Monthly").font(.headline)
                                        Text("\(product.displayPrice) / \(period(product))").font(.subheadline).foregroundStyle(OmniTheme.muted)
                                    }
                                    Spacer(); Image(systemName: selectedProduct?.id == product.id ? "checkmark.circle.fill" : "circle").font(.title2)
                                }.padding(20).background(selectedProduct?.id == product.id ? OmniTheme.sage : .white, in: RoundedRectangle(cornerRadius: 18))
                                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(OmniTheme.ink.opacity(selectedProduct?.id == product.id ? 1 : 0.15), lineWidth: 1))
                            }.buttonStyle(.plain).accessibilityAddTraits(selectedProduct?.id == product.id ? .isSelected : [])
                        }
                        if let product = selectedProduct {
                            OmniButton(title: subscription.isLoading ? "Connecting to the App Store…" : "Subscribe · \(product.displayPrice) / \(period(product))", icon: "sparkles") {
                                Task { await subscription.purchase(product) }
                            }.disabled(subscription.isLoading).accessibilityIdentifier("plus.subscribe")
                            Text("\(product.displayPrice) billed every \(period(product)). Payment is charged to your Apple Account at confirmation. Renews automatically unless canceled at least 24 hours before the current period ends. Manage or cancel in your App Store account settings.")
                                .font(.system(size: 11)).foregroundStyle(OmniTheme.muted).lineSpacing(3)
                        }
                    }
                    if let message = subscription.errorMessage {
                        Text(message).font(.system(size: 13)).foregroundStyle(OmniTheme.muted).padding(16).frame(maxWidth: .infinity, alignment: .leading).background(OmniTheme.peach.opacity(0.5), in: RoundedRectangle(cornerRadius: 14)).accessibilityIdentifier("plus.status")
                    }
                    HStack(spacing: 20) {
                        Button("Restore purchases") { Task { await subscription.restore() } }.disabled(subscription.isLoading)
                        Spacer(); Button("Privacy") { privacy = true }; Link("Terms", destination: ReleaseLinks.terms)
                    }.font(.system(size: 11))
                    Button("Keep using free") { dismiss() }.font(.system(size: 14)).frame(maxWidth: .infinity).padding(.vertical, 8)
                }.padding(26)
            }.background(OmniTheme.paper).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
                .sheet(isPresented: $privacy) { PrivacyScreen() }
                .task { if ReleaseLinks.purchasesReady { await subscription.loadProducts() } }
        }
    }
    private func period(_ product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else { return "period" }
        let unit: String
        switch period.unit { case .day: unit = "day"; case .week: unit = "week"; case .month: unit = "month"; case .year: unit = "year"; @unknown default: unit = "period" }
        return period.value == 1 ? unit : "\(period.value) \(unit)s"
    }
    private func feature(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 16) { Image(systemName: symbol).font(.system(size: 22, weight: .light)).frame(width: 30); VStack(alignment: .leading, spacing: 6) { Text(title).font(.system(size: 16, weight: .medium)); Text(text).font(.system(size: 13)).foregroundStyle(OmniTheme.muted).lineSpacing(3) } }
    }
    private func unavailable(_ text: String) -> some View { OmniCard(color: OmniTheme.sage) { Text(text).font(.system(size: 14)).lineSpacing(4) } }
}
