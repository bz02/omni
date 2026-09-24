import Combine
import Foundation
import StoreKit

struct PendingStorePurchase: Identifiable {
    let product: Product
    let offer: Product.SubscriptionOffer?
    var id: String { product.id + ":" + (offer?.id ?? "standard") }
}

struct StoreDeliveryIssue: Identifiable {
    enum Kind: String { case signIn, unbound, differentAccount, server, unverified, unsupported }
    let kind: Kind
    let message: String
    let transactionID: UInt64?
    var id: String { kind.rawValue }
    var canRetry: Bool { kind != .unbound && kind != .unsupported }
}

/// Apple-verified access to on-device Plus features. Never persist an unlock flag.
@MainActor
final class SubscriptionStore: ObservableObject {
    static let monthlyID = "omni.ai.Omni.plus.monthly"
    static let yearlyID = "omni.ai.Omni.plus.yearly"
    static let productIDs: Set<String> = [monthlyID, yearlyID]

    @Published private(set) var products: [Product] = []
    @Published private(set) var hasPremium = false
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var pendingStorePurchases: [PendingStorePurchase] = []
    @Published private(set) var deliveryIssue: StoreDeliveryIssue?
    @Published private(set) var isRetryingDelivery = false
    var pendingStorePurchase: PendingStorePurchase? { pendingStorePurchases.first }
    weak var accountStore: AccountStore? {
        didSet {
            guard oldValue !== accountStore else { return }
            accountObservation = nil
            accountDidChange()
            accountObservation = accountStore?.$accountID.removeDuplicates().dropFirst().sink { [weak self] _ in
                self?.accountDidChange()
            }
        }
    }
    private var accountObservation: AnyCancellable?
    private var identityRevision = 0
    private let deliveryQueue = StoreDeliveryQueue()
    private struct PurchaseIdentity {
        let revision: Int
        let account: AccountStore?
        let accountID: UUID?
    }

    private var updatesTask: Task<Void, Never>?
    private var intentsTask: Task<Void, Never>?
    private var initialEntitlementsTask: Task<Void, Never>?
    private var expirationTask: Task<Void, Never>?
    private var refreshGeneration = 0

    init(listenForStoreEvents: Bool = true) {
        guard listenForStoreEvents else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard let self else { return }
                await self.handleTransactionUpdate(result)
            }
        }
        intentsTask = Task { [weak self] in
            for await intent in PurchaseIntent.intents {
                guard !Task.isCancelled else { return }
                self?.receiveStorePurchase(product: intent.product, offer: intent.offer)
            }
        }
        initialEntitlementsTask = Task { [weak self] in
            await self?.refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
        intentsTask?.cancel()
        initialEntitlementsTask?.cancel()
        expirationTask?.cancel()
    }

    private func accountDidChange() {
        identityRevision += 1
        // StoreKit ownership survives an optional Omni sign-out or account switch.
        deliveryIssue = nil
        errorMessage = nil
    }

    private func purchaseIdentity() -> PurchaseIdentity {
        PurchaseIdentity(revision: identityRevision, account: accountStore, accountID: accountStore?.accountID)
    }

    private func isCurrent(_ identity: PurchaseIdentity) -> Bool {
        identityRevision == identity.revision && accountStore === identity.account
            && accountStore?.accountID == identity.accountID
    }

    /// Called only with StoreKit's Product, never a product or account supplied by a URL.
    func receiveStorePurchase(product: Product, offer: Product.SubscriptionOffer? = nil) {
        guard Self.productIDs.contains(product.id), product.type == .autoRenewable else {
            setDeliveryIssue(.unsupported, "This App Store product isn't available in Omni. No purchase was started.")
            return
        }
        guard offer == nil || (offer?.type == .winBack && offer?.id != nil) else {
            setDeliveryIssue(.unsupported, "This offer isn't supported in this version. No purchase was started.")
            return
        }
        let pending = PendingStorePurchase(product: product, offer: offer)
        guard !pendingStorePurchases.contains(where: { $0.id == pending.id }) else { return }
        pendingStorePurchases.append(pending)
    }

    func cancelStorePurchase(id: String) {
        guard !isLoading else { return }
        pendingStorePurchases.removeAll { $0.id == id }
    }

    /// Login never starts a charge. Only the customer's explicit Continue action calls this.
    func continueStorePurchase(id: String) async {
        guard !isLoading, let pending = pendingStorePurchase, pending.id == id else { return }
        let consumed = await performPurchase(pending.product, offer: pending.offer)
        if consumed { pendingStorePurchases.removeAll { $0.id == id } }
    }

    /// Display each returned Product's displayPrice; never substitute a test price.
    func loadProducts() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            products = try await Product.products(for: Self.productIDs)
                .filter { $0.type == .autoRenewable }
                .sorted { left, right in
                    if left.id == Self.monthlyID { return true }
                    if right.id == Self.monthlyID { return false }
                    return left.id < right.id
                }
            if products.isEmpty {
                errorMessage = "Subscriptions are unavailable right now. You can keep using Omni for free and try again later."
            }
        } catch {
            products = []
            errorMessage = "We couldn't load subscriptions from the App Store. Check your connection and try again."
        }
        await refreshEntitlements()
    }

    func purchase(_ product: Product) async {
        guard products.contains(where: { $0.id == product.id }) else {
            errorMessage = "This subscription is unavailable. Reload the plans and try again."
            return
        }
        _ = await performPurchase(product)
    }

    /// True means StoreKit consumed the intent (completed, awaiting approval, or user cancelled).
    private func performPurchase(_ product: Product, offer: Product.SubscriptionOffer? = nil) async -> Bool {
        guard ReleaseLinks.purchasesReady else {
            errorMessage = "Subscriptions aren't available in this build yet. No purchase was started."
            return false
        }
        guard !isLoading else { return false }
        let identity = purchaseIdentity()
        guard Self.productIDs.contains(product.id),
              product.type == .autoRenewable, offer == nil || (offer?.type == .winBack && offer?.id != nil) else {
            errorMessage = "This subscription is unavailable. Reload the plans and try again."
            return false
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            var options: Set<Product.PurchaseOption> = identity.accountID.map { [.appAccountToken($0)] } ?? []
            if let offer { options.insert(.winBackOffer(offer)) }
            switch try await product.purchase(options: options) {
            case .success(let result):
                let delivered = await deliver(result)
                if delivered && !hasPremium {
                    errorMessage = "No active Plus subscription was found after this purchase. Please try Restore Purchases."
                }
                return true
            case .pending:
                errorMessage = "Your purchase is awaiting approval. Plus will unlock when the App Store confirms it."
                return true
            case .userCancelled:
                return true
            @unknown default:
                errorMessage = "The purchase hasn't completed. Please try again."
                return false
            }
        } catch {
            errorMessage = "Your purchase couldn't be completed. Please try again in the App Store."
            return false
        }
    }

    /// Call only after the user taps Restore; sync may show Apple's sign-in UI.
    func restore() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            await syncAccountEntitlements()
            if !hasPremium && deliveryIssue == nil {
                errorMessage = "No active Plus subscription was found for this Apple Account."
            }
        } catch {
            errorMessage = "We couldn't restore purchases. Check your connection and Apple Account, then try again."
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    func dismissDeliveryIssue() { deliveryIssue = nil }

    private func setDeliveryIssue(_ kind: StoreDeliveryIssue.Kind, _ message: String, transactionID: UInt64? = nil) {
        deliveryIssue = StoreDeliveryIssue(kind: kind, message: message, transactionID: transactionID)
        errorMessage = message
    }

    /// Also call when the app becomes active so background expiry is reflected.
    func refreshEntitlements() async {
        refreshGeneration += 1
        let generation = refreshGeneration
        var validUntil: [Date] = []

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Self.productIDs.contains(transaction.productID),
                  transaction.productType == .autoRenewable,
                  transaction.revocationDate == nil,
                  !transaction.isUpgraded,
                  let expiry = transaction.expirationDate else { continue }

            if expiry > Date() {
                validUntil.append(expiry)
            } else if let graceExpiry = await verifiedGraceExpiration(for: transaction) {
                validUntil.append(graceExpiry)
            }
        }

        // A slower, older refresh must not overwrite a more recent transaction update.
        guard generation == refreshGeneration else { return }
        let nextExpiration = validUntil.filter { $0 > Date() }.min()
        hasPremium = nextExpiration != nil
        scheduleExpirationRefresh(at: nextExpiration)
    }

    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        _ = await deliver(result)
    }

    /// Local delivery depends only on StoreKit, never on Omni registration.
    /// Online access is separately verified and bound by the server after optional sign-in.
    @discardableResult
    func deliver(_ result: VerificationResult<Transaction>) async -> Bool {
        guard case .verified(let transaction) = result else {
            setDeliveryIssue(.unverified, "The App Store couldn't verify this purchase. Plus hasn't been unlocked. Try Restore Purchases; don't buy it again.")
            await refreshEntitlements()
            return false
        }
        guard Self.productIDs.contains(transaction.productID), transaction.productType == .autoRenewable else { return false }
        let identity = purchaseIdentity()
        await refreshEntitlements()
        guard isCurrent(identity) else { return false }
        guard let accountID = identity.accountID else {
            await transaction.finish()
            return true
        }
        if let owner = transaction.appAccountToken, owner != accountID {
            setDeliveryIssue(.differentAccount, "On-device Plus is available with your Apple Account. Online Plus is linked to a different Omni account. Sign in to that account to use online features; don't buy again.", transactionID: transaction.id)
            await transaction.finish()
            return true
        }
        let delivered = await deliveryQueue.deliver(transactionID: transaction.id, representation: result.jwsRepresentation,
            identityRevision: identity.revision, isCurrent: { [weak self] in self?.isCurrent(identity) == true },
            confirm: { [weak self] in
                guard let self else { throw CancellationError() }
                if identity.accountID != nil {
                    guard let account = identity.account else { throw AccountError.signInRequired }
                    do { try await account.syncSubscription(signedTransaction: result.jwsRepresentation) }
                    catch AccountError.http(403) {
                        if self.isCurrent(identity) {
                            self.setDeliveryIssue(.differentAccount, "On-device Plus is active. This subscription is already linked to another Omni account for online features. Sign in to that account; don't buy again.", transactionID: transaction.id)
                        }
                        throw AccountError.http(403)
                    } catch {
                        if self.isCurrent(identity) {
                            self.setDeliveryIssue(.server, "On-device Plus is available. Online access couldn't be confirmed. Retry delivery when your account can connect. You won't be charged again.", transactionID: transaction.id)
                        }
                        throw error
                    }
                }
                await self.refreshEntitlements()
            }, finish: { await transaction.finish() })
        if delivered && isCurrent(identity) && deliveryIssue?.transactionID == transaction.id {
            if errorMessage == deliveryIssue?.message { errorMessage = nil }
            deliveryIssue = nil
        }
        return delivered
    }

    /// Current entitlements also link a completed guest purchase after optional sign-in.
    /// Temporary online failures can be retried without purchasing again.
    func syncAccountEntitlements() async {
        guard !isRetryingDelivery else { return }
        isRetryingDelivery = true
        defer { isRetryingDelivery = false }
        if accountStore?.isSignedIn == true, deliveryIssue?.kind == .signIn, deliveryIssue?.transactionID == nil {
            // Restore's pre-login prompt has been satisfied. Transaction-specific
            // ownership or confirmation failures below must still be shown.
            if errorMessage == deliveryIssue?.message { errorMessage = nil }
            deliveryIssue = nil
        }
        var seen = Set<String>()
        for await result in Transaction.unfinished {
            guard case .verified(let transaction) = result, Self.productIDs.contains(transaction.productID) else { continue }
            seen.insert(result.jwsRepresentation)
            await deliver(result)
        }
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, Self.productIDs.contains(transaction.productID),
                  seen.insert(result.jwsRepresentation).inserted else { continue }
            await deliver(result)
        }
        await accountStore?.refreshAccount()
    }

    /// currentEntitlements includes billing grace periods, whose original expiry
    /// can be in the past. Only Apple's verified renewal info extends that date.
    private func verifiedGraceExpiration(for transaction: Transaction) async -> Date? {
        do {
            let product: Product?
            if let loaded = products.first(where: { $0.id == transaction.productID }) {
                product = loaded
            } else {
                product = try await Product.products(for: [transaction.productID]).first
            }
            guard let subscription = product?.subscription else { return nil }
            for status in try await subscription.status {
                guard status.state == .inGracePeriod,
                      case .verified(let statusTransaction) = status.transaction,
                      statusTransaction.id == transaction.id,
                      statusTransaction.revocationDate == nil,
                      !statusTransaction.isUpgraded,
                      case .verified(let renewal) = status.renewalInfo,
                      let graceExpiry = renewal.gracePeriodExpirationDate,
                      graceExpiry > Date() else { continue }
                return graceExpiry
            }
        } catch {
            // An unavailable or unverified grace extension cannot grant access.
        }
        return nil
    }

    private func scheduleExpirationRefresh(at expiration: Date?) {
        expirationTask?.cancel()
        expirationTask = nil
        guard let expiration else { return }
        let delay = min(max(expiration.timeIntervalSinceNow, 1), 86_400)
        expirationTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self?.refreshEntitlements()
        }
    }
}
