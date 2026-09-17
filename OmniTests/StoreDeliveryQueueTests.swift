import Foundation
import Testing
@testable import Omni

@Suite("StoreKit delivery acknowledgement boundaries")
@MainActor
struct StoreDeliveryQueueTests {
    @Test("A suspended server confirmation cannot finish the StoreKit transaction")
    func waitsForConfirmation() async {
        let queue = StoreDeliveryQueue()
        let started = DeliveryTestGate()
        let acknowledged = DeliveryTestGate()
        var finishes = 0
        let delivery = Task {
            await queue.deliver(transactionID: 1, representation: "signed-event", identityRevision: 1,
                isCurrent: { true }, confirm: { started.open(); await acknowledged.wait() }, finish: { finishes += 1 })
        }
        await started.wait()
        #expect(finishes == 0)
        acknowledged.open()
        #expect(await delivery.value)
        #expect(finishes == 1)
    }

    @Test("A failed confirmation remains retryable without finishing early")
    func failedConfirmationCanRetry() async {
        let queue = StoreDeliveryQueue()
        var finishes = 0
        let first = await queue.deliver(transactionID: 1, representation: "signed-event", identityRevision: 1,
            isCurrent: { true }, confirm: { throw URLError(.timedOut) }, finish: { finishes += 1 })
        #expect(!first)
        #expect(finishes == 0)
        let retry = await queue.deliver(transactionID: 1, representation: "signed-event", identityRevision: 1,
            isCurrent: { true }, confirm: {}, finish: { finishes += 1 })
        #expect(retry)
        #expect(finishes == 1)
    }

    @Test("Signing out and back into the same identity invalidates an older delivery")
    func identityRevisionInvalidatesInFlightConfirmation() async {
        let queue = StoreDeliveryQueue()
        let started = DeliveryTestGate()
        let acknowledged = DeliveryTestGate()
        let originalAccount = UUID()
        var currentAccount: UUID? = originalAccount
        var revision = 1
        var finishes = 0
        let delivery = Task {
            await queue.deliver(transactionID: 1, representation: "signed-event", identityRevision: 1,
                isCurrent: { currentAccount == originalAccount && revision == 1 },
                confirm: { started.open(); await acknowledged.wait() }, finish: { finishes += 1 })
        }
        await started.wait()
        currentAccount = nil
        revision += 1
        currentAccount = originalAccount
        revision += 1
        acknowledged.open()
        #expect(!(await delivery.value))
        #expect(finishes == 0)
        #expect(await queue.deliver(transactionID: 1, representation: "signed-event", identityRevision: revision,
            isCurrent: { true }, confirm: {}, finish: { finishes += 1 }))
        #expect(finishes == 1)
    }

    @Test("Concurrent listeners share acknowledgement and finish for the same signed event")
    func duplicateEventsShareDelivery() async {
        let queue = StoreDeliveryQueue()
        let started = DeliveryTestGate()
        let acknowledged = DeliveryTestGate()
        let duplicateEntered = DeliveryTestGate()
        var confirmations = 0
        var finishes = 0
        let first = Task {
            await queue.deliver(transactionID: 1, representation: "signed-event", identityRevision: 1,
                isCurrent: { true }, confirm: { confirmations += 1; started.open(); await acknowledged.wait() },
                finish: { finishes += 1 })
        }
        await started.wait()
        let duplicate = Task {
            await queue.deliver(transactionID: 1, representation: "signed-event", identityRevision: 1,
                isCurrent: { duplicateEntered.open(); return true }, confirm: { confirmations += 1 },
                finish: { finishes += 1 })
        }
        await duplicateEntered.wait()
        #expect(confirmations == 1)
        acknowledged.open()
        #expect(await first.value)
        #expect(await duplicate.value)
        #expect(confirmations == 1)
        #expect(finishes == 1)
    }

    @Test("A refund event for the same transaction is processed after the original event")
    func changedSignedEventIsNotDeduplicated() async {
        let queue = StoreDeliveryQueue()
        let started = DeliveryTestGate()
        let acknowledged = DeliveryTestGate()
        let refundEntered = DeliveryTestGate()
        var events: [String] = []
        var finishes = 0
        let purchase = Task {
            await queue.deliver(transactionID: 1, representation: "signed-purchase", identityRevision: 1,
                isCurrent: { true }, confirm: { events.append("purchase"); started.open(); await acknowledged.wait() },
                finish: { finishes += 1 })
        }
        await started.wait()
        let refund = Task {
            await queue.deliver(transactionID: 1, representation: "signed-refund", identityRevision: 1,
                isCurrent: { refundEntered.open(); return true }, confirm: { events.append("refund") },
                finish: { finishes += 1 })
        }
        await refundEntered.wait()
        #expect(events == ["purchase"])
        acknowledged.open()
        #expect(await purchase.value)
        #expect(await refund.value)
        #expect(events == ["purchase", "refund"])
        #expect(finishes == 2)
    }

    @Test("A stale identity cannot start server confirmation or finish")
    func staleIdentityDoesNoWork() async {
        let queue = StoreDeliveryQueue()
        var confirmations = 0
        var finishes = 0
        #expect(!(await queue.deliver(transactionID: 1, representation: "signed-event", identityRevision: 1,
            isCurrent: { false }, confirm: { confirmations += 1 }, finish: { finishes += 1 })))
        #expect(confirmations == 0)
        #expect(finishes == 0)
    }
}

/// Open-once test gate; no timing assumptions or sleeps are needed for actor races.
@MainActor
final class DeliveryTestGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func open() {
        isOpen = true
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }
}
