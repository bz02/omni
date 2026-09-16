import Combine
import Foundation
import StoreKit

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
    weak var accountStore: AccountStore?
    private var requiresAccount: Bool { AccountConfiguration.baseURL != nil || accountStore?.hasConfiguration == true }

    private var updatesTask: Task<Void, Never>?
    private var initialEntitlementsTask: Task<Void, Never>?
    private var expirationTask: Task<Void, Never>?
    private var refreshGeneration = 0

    init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard let self else { return }
                await self.handleTransactionUpdate(result)
            }
        }
        initialEntitlementsTask = Task { [weak self] in
            await self?.refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
        initialEntitlementsTask?.cancel()
        expirationTask?.cancel()
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
        guard !isLoading else { return }
        let purchasingAccount = accountStore?.accountID
        guard !requiresAccount || purchasingAccount != nil else {
            errorMessage = "Sign in with Apple in You → Account before subscribing, so your purchase belongs to the right Omni account."
            return
        }
        guard Self.productIDs.contains(product.id),
              product.type == .autoRenewable,
              products.contains(where: { $0.id == product.id }) else {
            errorMessage = "This subscription is unavailable. Reload the plans and try again."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let options: Set<Product.PurchaseOption> = purchasingAccount.map { [.appAccountToken($0)] } ?? []
            switch try await product.purchase(options: options) {
            case .success(let result):
                guard case .verified(let transaction) = result,
                      Self.productIDs.contains(transaction.productID) else {
                    errorMessage = "The App Store couldn't verify this purchase. Plus has not been unlocked. Please try Restore Purchases."
                    return
                }
                await refreshEntitlements()
                await transaction.finish()
                if accountStore?.accountID == purchasingAccount { await syncAccountEntitlements() }
                if !hasPremium {
                    errorMessage = "No active Plus subscription was found after this purchase. Please try Restore Purchases."
                }
            case .pending:
                errorMessage = "Your purchase is awaiting approval. Plus will unlock when the App Store confirms it."
            case .userCancelled:
                break
            @unknown default:
                errorMessage = "The purchase hasn't completed. Please try again."
            }
        } catch {
            errorMessage = "Your purchase couldn't be completed. Please try again in the App Store."
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
            if !hasPremium {
                errorMessage = "No active Plus subscription was found for this Apple Account."
            }
        } catch {
            errorMessage = "We couldn't restore purchases. Check your connection and Apple Account, then try again."
        }
    }

    func dismissError() {
        errorMessage = nil
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
            if requiresAccount {
                guard let accountID = accountStore?.accountID, transaction.appAccountToken == accountID else { continue }
            }

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
        switch result {
        case .verified(let transaction):
            guard Self.productIDs.contains(transaction.productID) else { return }
            await refreshEntitlements()
            await transaction.finish()
            await syncAccountEntitlements()
        case .unverified(let transaction, _):
            guard Self.productIDs.contains(transaction.productID) else { return }
            errorMessage = "We couldn't verify a subscription update. Please try Restore Purchases."
            await refreshEntitlements()
        }
    }

    /// Only cryptographically verified, account-bound transactions are sent.
    /// The server makes the independent decision about online entitlement.
    func syncAccountEntitlements() async {
        guard let accountStore, accountStore.hasConfiguration, let accountID = accountStore.accountID else { return }
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Self.productIDs.contains(transaction.productID), transaction.productType == .autoRenewable,
                  transaction.appAccountToken == accountID, transaction.revocationDate == nil,
                  !transaction.isUpgraded, accountStore.accountID == accountID else { continue }
            do { try await accountStore.syncSubscription(signedTransaction: result.jwsRepresentation) }
            catch {
                if accountStore.accountID == accountID {
                    errorMessage = "Your App Store purchase is verified on this device, but online Plus couldn't be confirmed. Check your account connection and try again."
                }
            }
        }
        await accountStore.refreshAccount()
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
