import Foundation
import StoreKit
import StoreKitTest
import Testing
@testable import Omni

// Fixture source: Configuration/Omni.storekit. Keep OmniTests/Fixtures/Omni.storekit
// an exact copy when changing local product IDs or test prices.
// These tests use Apple's local StoreKit environment, not a live Apple Account.
// Apple requires serial execution because every SKTestSession shares one environment:
// https://developer.apple.com/documentation/storekittest/sktestsession
@Suite("Apple StoreKit subscription lifecycle", .serialized)
@MainActor
struct CommerceTests {
    @Test("Local products load and a verified in-app purchase unlocks Plus and finishes")
    func productsAndPurchase() async throws {
        let session = try makeSession()
        defer { cleanUp(session) }
        let store = SubscriptionStore()
        let transport = CommerceAccountTransport(accountID: UUID())
        let guest = AccountStore(transport: transport, vault: CommerceAccountVault(), baseURL: nil)
        store.accountStore = guest
        #expect(guest.hasConfiguration && !guest.isSignedIn)
        await store.loadProducts()

        #expect(Set(store.products.map(\.id)) == SubscriptionStore.productIDs)
        #expect(!store.isLoading)
        #expect(!store.hasPremium)
        #expect(store.errorMessage == nil)
        let monthly = try #require(store.products.first { $0.id == SubscriptionStore.monthlyID })
        let yearly = try #require(store.products.first { $0.id == SubscriptionStore.yearlyID })
        #expect(monthly.type == .autoRenewable)
        #expect(yearly.type == .autoRenewable)
        #expect(monthly.price == Decimal(string: "7.99"))
        #expect(yearly.price == Decimal(string: "39.99"))
        // Localized display strings are supplied by StoreKit, including currency.
        #expect(!monthly.displayPrice.isEmpty)
        #expect(!yearly.displayPrice.isEmpty)

        await store.purchase(monthly)
        try await eventually { store.hasPremium }
        #expect(!store.isLoading)
        #expect(store.errorMessage == nil)
        let verified = try #require(await verifiedEntitlement(for: monthly.id))
        #expect(verified.appAccountToken == nil)
        #expect(await transport.signedEvents.isEmpty, "A guest purchase must not contact the account service.")
        #expect(store.deliveryIssue == nil)
        #expect(verified.revocationDate == nil)
        #expect(try #require(verified.expirationDate) > Date())

        var unfinishedOmniTransactions = [UInt64]()
        for await result in Transaction.unfinished {
            if case .verified(let transaction) = result,
               SubscriptionStore.productIDs.contains(transaction.productID) {
                unfinishedOmniTransactions.append(transaction.id)
            }
        }
        #expect(unfinishedOmniTransactions.isEmpty)
    }

    @Test("External purchase and refund update access through the transaction listener")
    func purchaseThenRefund() async throws {
        let session = try makeSession()
        defer { cleanUp(session) }
        let store = SubscriptionStore()
        await store.refreshEntitlements()
        #expect(!store.hasPremium)

        // SKTestSession creates an actual local StoreKit transaction. No entitlement
        // flag is assigned, and no manual refresh is used to pass the listener checks.
        try await session.buyProduct(identifier: SubscriptionStore.yearlyID)
        try await eventually { store.hasPremium }
        let purchase = try #require(session.allTransactions().first {
            $0.productIdentifier == SubscriptionStore.yearlyID
        })
        try session.refundTransaction(identifier: purchase.identifier)
        try await eventually { !store.hasPremium }
        #expect(await verifiedEntitlement(for: SubscriptionStore.yearlyID) == nil)

        await store.restore()
        #expect(!store.hasPremium)
        #expect(store.errorMessage != nil)
    }

    @Test("An expired subscription does not regain access on refresh or restore")
    func expirationRemovesAccess() async throws {
        let session = try makeSession()
        defer { cleanUp(session) }
        let store = SubscriptionStore()
        await store.loadProducts()
        let product = try #require(store.products.first { $0.id == SubscriptionStore.monthlyID })
        await store.purchase(product)
        try await eventually { store.hasPremium }

        try session.expireSubscription(productIdentifier: product.id)
        // Foreground refresh is an explicit part of the app's expiration contract.
        try await eventually {
            await store.refreshEntitlements()
            return !store.hasPremium
        }
        #expect(await verifiedEntitlement(for: product.id) == nil)
        await store.restore()
        #expect(!store.hasPremium)
    }

    @Test("A new store restores an existing verified subscription without buying again")
    func restoreExistingPurchase() async throws {
        let session = try makeSession()
        defer { cleanUp(session) }
        let transaction = try await session.buyProduct(identifier: SubscriptionStore.yearlyID)
        await transaction.finish()
        let transactionsBeforeRestore = session.allTransactions().count

        let reopened = SubscriptionStore()
        let guestTransport = CommerceAccountTransport(accountID: UUID())
        // Keep a strong reference: SubscriptionStore intentionally holds its account weakly.
        let guest = AccountStore(transport: guestTransport, vault: CommerceAccountVault(), baseURL: nil)
        reopened.accountStore = guest
        await reopened.restore()
        try await eventually { reopened.hasPremium }
        #expect(!reopened.isLoading)
        #expect(reopened.errorMessage == nil)
        #expect(session.allTransactions().count == transactionsBeforeRestore)
        #expect(await verifiedEntitlement(for: SubscriptionStore.yearlyID) != nil)
    }

    @Test("A bound purchase stays unfinished while confirmation hangs or fails, then retries without rebuying")
    func serverFailureAndRetry() async throws {
        let session = try makeSession()
        defer { cleanUp(session) }
        let accountID = UUID()
        let transport = CommerceAccountTransport(accountID: accountID)
        let started = DeliveryTestGate(), acknowledgement = DeliveryTestGate()
        await transport.configure(failure: true, started: started, acknowledgement: acknowledgement)
        let account = makeAccount(accountID, transport: transport)
        let store = SubscriptionStore(listenForStoreEvents: false)
        store.accountStore = account
        let result = try await buyBoundProduct(accountID: accountID)
        let transaction = try #require(try? result.payloadValue)
        let delivery = Task { await store.deliver(result) }
        await started.wait()
        #expect(await isUnfinished(transaction.id))
        #expect(!account.hasOnlinePremium)
        acknowledgement.open()
        #expect(!(await delivery.value))
        #expect(store.deliveryIssue?.kind == .server)
        #expect(await isUnfinished(transaction.id))
        await transport.configure(failure: false)
        await store.syncAccountEntitlements()
        #expect(!(await isUnfinished(transaction.id)))
        #expect(account.hasOnlinePremium)
        #expect(store.deliveryIssue == nil)
        #expect(session.allTransactions().count == 1)
        #expect(await transport.signedEvents.first == result.jwsRepresentation)
        #expect(await transport.signedEvents.count >= 2, "Retry must submit StoreKit's signed event again; repeated enumerations can return a new JWS representation.")
    }

    @Test("Guest purchases can link after optional sign-in; another account's token never grants online access", arguments: [false, true])
    func guestAndOtherAccountPurchases(wrongAccount: Bool) async throws {
        let session = try makeSession()
        defer { cleanUp(session) }
        let accountID = UUID()
        let transport = CommerceAccountTransport(accountID: accountID)
        let account = makeAccount(accountID, transport: transport)
        let store = SubscriptionStore(listenForStoreEvents: false)
        store.accountStore = account
        let result = try await buyBoundProduct(accountID: wrongAccount ? UUID() : nil)
        let transaction = try #require(try? result.payloadValue)
        #expect(await store.deliver(result))
        #expect(store.hasPremium, "The Apple Account owns local Plus regardless of Omni identity.")
        #expect(account.hasOnlinePremium == !wrongAccount)
        #expect(await transport.signedEvents.isEmpty == wrongAccount)
        #expect(!(await isUnfinished(transaction.id)))
        if wrongAccount { #expect(store.deliveryIssue?.kind == .differentAccount) }
        else { #expect(store.deliveryIssue == nil) }
    }

    @Test("Sign-out preserves local Plus while online confirmation remains scoped to its original account")
    func signOutDuringDelivery() async throws {
        let session = try makeSession()
        defer { cleanUp(session) }
        let accountID = UUID()
        let transport = CommerceAccountTransport(accountID: accountID)
        let started = DeliveryTestGate(), acknowledgement = DeliveryTestGate()
        await transport.configure(started: started, acknowledgement: acknowledgement)
        let account = makeAccount(accountID, transport: transport)
        let store = SubscriptionStore(listenForStoreEvents: false)
        store.accountStore = account
        let result = try await buyBoundProduct(accountID: accountID)
        let transaction = try #require(try? result.payloadValue)
        let delivery = Task { await store.deliver(result) }
        await started.wait()
        #expect(store.hasPremium)
        #expect(await account.signOut())
        #expect(store.hasPremium, "Signing out must not remove Apple-verified on-device Plus.")
        acknowledgement.open()
        #expect(!(await delivery.value))
        #expect(!account.hasOnlinePremium)
        #expect(await isUnfinished(transaction.id))

        let anotherID = UUID()
        let anotherTransport = CommerceAccountTransport(accountID: anotherID)
        let anotherAccount = makeAccount(anotherID, transport: anotherTransport)
        store.accountStore = anotherAccount
        #expect(await store.deliver(result))
        #expect(store.hasPremium)
        #expect(!anotherAccount.hasOnlinePremium)
        #expect(await anotherTransport.signedEvents.isEmpty)
        await transport.configure()
        let originalAccount = makeAccount(accountID, transport: transport)
        store.accountStore = originalAccount
        #expect(await store.deliver(result))
        #expect(originalAccount.hasOnlinePremium)
        #expect(!(await isUnfinished(transaction.id)))
    }

    @Test("A cold-start Store intent buys as guest, then optional sign-in links the finished purchase without rebuying")
    func deferredPurchaseIntent() async throws {
        let session = try makeSession()
        defer { cleanUp(session) }
        let accountID = UUID()
        let transport = CommerceAccountTransport(accountID: accountID)
        let account = AccountStore(transport: transport, vault: CommerceAccountVault(), baseURL: nil)
        let store = SubscriptionStore(listenForStoreEvents: false)
        store.accountStore = account
        let products = try await Product.products(for: SubscriptionStore.productIDs)
        let monthly = try #require(products.first { $0.id == SubscriptionStore.monthlyID })
        let yearly = try #require(products.first { $0.id == SubscriptionStore.yearlyID })
        store.receiveStorePurchase(product: monthly)
        store.receiveStorePurchase(product: monthly)
        store.receiveStorePurchase(product: yearly)
        #expect(store.products.isEmpty)
        #expect(store.pendingStorePurchases.count == 2)
        #expect(session.allTransactions().isEmpty, "An intent alone must never start payment.")
        let firstID = try #require(store.pendingStorePurchase?.id)
        await store.continueStorePurchase(id: firstID)
        let transaction = try #require(await verifiedEntitlement(for: monthly.id))
        #expect(transaction.appAccountToken == nil)
        #expect(store.hasPremium)
        #expect(!(await isUnfinished(transaction.id)))
        #expect(await transport.signedEvents.isEmpty)
        #expect(store.deliveryIssue == nil)
        #expect(store.pendingStorePurchase?.product.id == yearly.id)
        store.cancelStorePurchase(id: firstID)
        #expect(store.pendingStorePurchase?.product.id == yearly.id)
        store.cancelStorePurchase(id: try #require(store.pendingStorePurchase?.id))
        #expect(store.pendingStorePurchases.isEmpty)

        await account.prepareSignIn()
        try await account.exchangeAppleCredential(identityToken: "synthetic-identity", authorizationCode: "synthetic-code", challengeID: "commerce-challenge")
        await store.syncAccountEntitlements()
        #expect(account.accountID == accountID)
        #expect(account.hasOnlinePremium)
        #expect(store.hasPremium)
        #expect(session.allTransactions().count == 1, "Optional login must link the existing purchase, not charge again.")
        #expect(await account.signOut())
        #expect(store.hasPremium)
        #expect(!account.hasOnlinePremium)
        await store.restore()
        #expect(store.hasPremium)
        #expect(store.deliveryIssue == nil)
        #expect(session.allTransactions().count == 1)
    }

    private func buyBoundProduct(accountID: UUID?) async throws -> VerificationResult<Transaction> {
        let product = try #require(try await Product.products(for: [SubscriptionStore.monthlyID]).first)
        let options: Set<Product.PurchaseOption> = accountID.map { [.appAccountToken($0)] } ?? []
        switch try await product.purchase(options: options) {
        case .success(let result): return result
        default: throw AccountError.invalidResponse
        }
    }

    private func isUnfinished(_ id: UInt64) async -> Bool {
        for await result in Transaction.unfinished {
            if case .verified(let transaction) = result, transaction.id == id { return true }
        }
        return false
    }

    private func makeAccount(_ accountID: UUID, transport: CommerceAccountTransport) -> AccountStore {
        let session = AccountSession(accountID: accountID, accessToken: "commerce-access", refreshToken: "commerce-refresh",
                                     expiresAt: Date().addingTimeInterval(3600).timeIntervalSince1970)
        return AccountStore(transport: transport, vault: CommerceAccountVault(session: session), baseURL: nil)
    }

    private func makeSession() throws -> SKTestSession {
        let bundle = Bundle(for: CommerceFixtureBundleMarker.self)
        let resource = bundle.url(forResource: "Omni", withExtension: "storekit", subdirectory: "Fixtures")
            ?? bundle.url(forResource: "Omni", withExtension: "storekit")
        let configuration = try #require(resource, "OmniTests/Fixtures/Omni.storekit must be copied into the OmniTests bundle's resources.")
        // Explicit URL loads the test bundle's fixture; it never falls back to live products.
        let session = try SKTestSession(contentsOf: configuration)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        session.timeRate = .realTime
        session.storefront = "USA"
        session.locale = Locale(identifier: "en_US")
        session.askToBuyEnabled = false
        session.interruptedPurchasesEnabled = false
        session.shouldEnterBillingRetryOnRenewal = false
        session.billingGracePeriodIsEnabled = false
        return session
    }

    private func cleanUp(_ session: SKTestSession) {
        session.clearTransactions()
        session.resetToDefaultState()
    }

    private func verifiedEntitlement(for productID: String) async -> Transaction? {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == productID {
                return transaction
            }
        }
        return nil
    }

    private func eventually(_ condition: @MainActor () async -> Bool) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(10))
        repeat {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(100))
        } while clock.now < deadline
        try #require(await condition(), "StoreKit did not deliver the expected entitlement state within 10 seconds.")
    }
}

private final class CommerceFixtureBundleMarker: NSObject {}

@MainActor
private final class CommerceAccountVault: AccountSessionPersisting {
    var session: AccountSession?
    init(session: AccountSession? = nil) { self.session = session }
    func load() throws -> AccountSession? { session }
    func save(_ session: AccountSession) throws { self.session = session }
    func remove() throws { session = nil }
}

/// Synthetic account responses only. Production still verifies Apple's JWS on the backend.
private actor CommerceAccountTransport: AccountTransport {
    let accountID: UUID
    private(set) var signedEvents: [String] = []
    private var failure = false
    private var started: DeliveryTestGate?
    private var acknowledgement: DeliveryTestGate?
    private var active = false
    init(accountID: UUID) { self.accountID = accountID }
    func configure(failure: Bool = false, started: DeliveryTestGate? = nil, acknowledgement: DeliveryTestGate? = nil) {
        self.failure = failure; self.started = started; self.acknowledgement = acknowledgement
    }
    func request(path: String, method: String, body: Data?, accessToken: String?) async throws -> Data {
        switch path {
        case "/v1/auth/challenge":
            return try JSONSerialization.data(withJSONObject: ["challenge_id": "commerce-challenge", "nonce": "synthetic-commerce-nonce-32-characters", "expires_at": Date().addingTimeInterval(300).timeIntervalSince1970])
        case "/v1/auth/apple":
            return try JSONEncoder().encode(AccountSession(accountID: accountID, accessToken: "commerce-access", refreshToken: "commerce-refresh", expiresAt: Date().addingTimeInterval(3600).timeIntervalSince1970))
        case "/v1/account/subscription":
            guard let body, let json = try JSONSerialization.jsonObject(with: body) as? [String: String],
                  let signed = json["signed_transaction"] else { throw AccountError.invalidResponse }
            signedEvents.append(signed)
            await started?.open()
            await acknowledgement?.wait()
            if failure { throw AccountError.http(503) }
            active = true
            return try status()
        case "/v1/account/session": return try status()
        case "/v1/auth/logout": return Data()
        default: throw AccountError.http(404)
        }
    }
    private func status() throws -> Data {
        try JSONSerialization.data(withJSONObject: ["account_id": accountID.uuidString, "premium_active": active,
            "premium_until": Date().addingTimeInterval(active ? 3600 : -1).timeIntervalSince1970])
    }
}
