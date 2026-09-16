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
        await reopened.restore()
        try await eventually { reopened.hasPremium }
        #expect(!reopened.isLoading)
        #expect(reopened.errorMessage == nil)
        #expect(session.allTransactions().count == transactionsBeforeRestore)
        #expect(await verifiedEntitlement(for: SubscriptionStore.yearlyID) != nil)
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
