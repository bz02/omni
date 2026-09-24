import StoreKit
import SwiftUI

struct StorePurchasePresenter: ViewModifier {
    @ObservedObject var subscription: SubscriptionStore
    @ObservedObject var account: AccountStore
    let setupComplete: Bool
    @State private var destination: Destination?
    @State private var isPresenting = false
    @State private var presentedPurchaseID: String?

    private enum Destination: Identifiable {
        case purchase(PendingStorePurchase)
        case delivery
        var id: String {
            switch self {
            case .purchase(let pending): "purchase:" + pending.id
            case .delivery: "delivery"
            }
        }
    }

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                if !setupComplete && subscription.pendingStorePurchase != nil {
                    Text("Your App Store selection will be ready after setup. Nothing has been purchased here yet.")
                        .font(.footnote).padding(14).frame(maxWidth: .infinity).background(OmniTheme.sage)
                } else if setupComplete && subscription.pendingStorePurchase != nil {
                    Button("Review your App Store selection") { presentNextPurchase() }
                        .font(.subheadline).padding(14).frame(maxWidth: .infinity).background(OmniTheme.sage)
                        .accessibilityIdentifier("commerce.reviewIntent")
                } else if setupComplete && subscription.deliveryIssue != nil {
                    Button("Review your App Store purchase") { presentDelivery() }
                        .font(.subheadline).padding(14).frame(maxWidth: .infinity).background(OmniTheme.sage)
                        .accessibilityIdentifier("commerce.reviewDelivery")
                }
            }
            .onChange(of: subscription.pendingStorePurchase?.id, initial: true) { _, nextID in
                if isPresenting, let presentedPurchaseID, presentedPurchaseID != nextID {
                    destination = nil
                }
            }
            .onChange(of: subscription.deliveryIssue?.id) { _, issueID in
                if issueID == nil, case .delivery? = destination { destination = nil }
            }
            .sheet(item: $destination, onDismiss: {
                // A completed first purchase may already have advanced the queue.
                // Dismiss only the ID this sheet actually displayed, never the new head.
                if let presentedPurchaseID { subscription.cancelStorePurchase(id: presentedPurchaseID) }
                presentedPurchaseID = nil
                isPresenting = false
            }) { destination in
                switch destination {
                case .purchase(let pending):
                    StorePurchaseSheet(subscription: subscription, account: account, pending: pending)
                case .delivery:
                    StoreDeliverySheet(subscription: subscription, account: account)
                }
            }
    }

    private func presentNextPurchase() {
        guard setupComplete, !isPresenting, let pending = subscription.pendingStorePurchase else { return }
        presentedPurchaseID = pending.id
        isPresenting = true
        destination = .purchase(pending)
    }

    private func presentDelivery() {
        guard setupComplete, !isPresenting, subscription.deliveryIssue != nil else { return }
        isPresenting = true
        destination = .delivery
    }
}

private struct StorePurchaseSheet: View {
    @ObservedObject var subscription: SubscriptionStore
    @ObservedObject var account: AccountStore
    let pending: PendingStorePurchase
    @State private var showAccount = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PageHeading(eyebrow: "YOUR APP STORE SELECTION", title: "A little more\nroom, yours.")
                    Text(pending.product.displayName).font(.title2)
                    Text("\(pending.product.displayPrice) / \(period(pending.product.subscription?.subscriptionPeriod))")
                        .font(.headline)
                    if let offer = pending.offer { Text(offerSummary(offer)).font(.subheadline) }
                    Text("Review the price, renewal terms, and any offer in Apple's confirmation sheet before approving payment.")
                        .font(.footnote).foregroundStyle(OmniTheme.muted)
                    Text("No Omni account is needed to purchase or restore on-device Plus. Optional sign-in connects online conversations and account memory sync.").font(.subheadline)
                    OmniButton(title: subscription.isLoading ? "Connecting to the App Store…" : "Continue to App Store", icon: "arrow.right") {
                        Task { await subscription.continueStorePurchase(id: pending.id) }
                    }.disabled(subscription.isLoading || !ReleaseLinks.purchasesReady)
                        .accessibilityIdentifier("commerce.continueIntent")
                    if !ReleaseLinks.purchasesReady { Text("Subscriptions aren't available in this build yet.").font(.footnote) }
                    if let message = subscription.errorMessage { Text(message).font(.footnote).foregroundStyle(OmniTheme.muted) }
                    HStack {
                        if let privacy = ReleaseLinks.privacy { Link("Privacy", destination: privacy) }
                        Link("Terms", destination: ReleaseLinks.terms)
                    }.font(.footnote)
                    Button("Cancel this purchase") { subscription.cancelStorePurchase(id: pending.id) }
                        .disabled(subscription.isLoading).accessibilityIdentifier("commerce.cancelIntent")
                }.padding(24)
            }.background(OmniTheme.paper).navigationTitle("Complete your purchase").navigationBarTitleDisplayMode(.inline)
                .interactiveDismissDisabled(subscription.isLoading)
                .sheet(isPresented: $showAccount) {
                    AccountScreen().environmentObject(account).environmentObject(subscription)
                }
        }
    }

    private func period(_ value: Product.SubscriptionPeriod?) -> String {
        guard let value else { return "subscription period" }
        let unit: String
        switch value.unit {
        case .day: unit = "day"
        case .week: unit = "week"
        case .month: unit = "month"
        case .year: unit = "year"
        @unknown default: unit = "period"
        }
        return value.value == 1 ? unit : "\(value.value) \(unit)s"
    }

    private func offerSummary(_ offer: Product.SubscriptionOffer) -> String {
        if offer.paymentMode == .payAsYouGo {
            return "Offer: \(offer.displayPrice) per \(period(offer.period)), for \(offer.periodCount) periods."
        }
        if offer.paymentMode == .freeTrial {
            return "Offer: \(offer.periodCount) × \(period(offer.period)) free, then the regular subscription price."
        }
        if offer.paymentMode == .payUpFront {
            return "Offer: \(offer.displayPrice) for \(offer.periodCount) × \(period(offer.period)), then the regular subscription price."
        }
        return "An offer is included. Review its terms in Apple's confirmation sheet."
    }
}

private struct StoreDeliverySheet: View {
    @ObservedObject var subscription: SubscriptionStore
    @ObservedObject var account: AccountStore
    @State private var showAccount = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PageHeading(eyebrow: "YOUR APP STORE PURCHASE", title: "Let's finish\nsetting things up.")
                    if let issue = subscription.deliveryIssue {
                        Text(issue.message).lineSpacing(4)
                        if account.hasConfiguration {
                            Button(account.isSignedIn ? "Review or switch account" : "Sign in with Apple") { showAccount = true }
                        }
                        if issue.canRetry {
                            OmniButton(title: subscription.isRetryingDelivery ? "Checking your purchase…" : "Retry delivery", icon: "arrow.clockwise") {
                                Task { await subscription.syncAccountEntitlements() }
                            }.disabled(subscription.isRetryingDelivery)
                                .accessibilityIdentifier("commerce.retryDelivery")
                        }
                        if let support = ReleaseLinks.support { Link("Contact support", destination: support) }
                    }
                }.padding(24)
            }.background(OmniTheme.paper).navigationTitle("Purchase support").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { subscription.dismissDeliveryIssue(); dismiss() } }
                .sheet(isPresented: $showAccount) { AccountScreen().environmentObject(account).environmentObject(subscription) }
        }
    }
}
